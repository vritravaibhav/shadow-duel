import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../game/netplay.dart';
import 'dark_services.dart';

class ChatMessage {
  ChatMessage(this.text, {required this.mine, this.system = false}) : at = DateTime.now();
  final String text;
  final bool mine, system;
  final DateTime at;
}

/// Who sits in the room, from the signaling document.
class Seat {
  const Seat(this.uid, this.name, this.char);
  final String uid, name, char;
}

enum RtcState { idle, waiting, connecting, connected, closed, failed }

/// One peer-to-peer line to the other player: a WebRTC connection brokered
/// through a Firestore room document. Carries the game stream ([NetLink]),
/// a text chat channel and a voice track that can be muted.
class RtcSession implements NetLink {
  RtcSession._(this.isHost, this.code, this.me);

  /// The session in progress, if any (the in-duel bar and result card need
  /// it after the lobby screen is gone).
  static RtcSession? current;

  @override
  final bool isHost;
  final String code;
  final Seat me;
  Seat? peer;

  final state = ValueNotifier<RtcState>(RtcState.idle);
  final chat = ValueNotifier<List<ChatMessage>>(const []);
  final muted = ValueNotifier<bool>(false);
  final voiceOn = ValueNotifier<bool>(false);
  final peerMuted = ValueNotifier<bool>(false);

  /// Fired once both seats are known and the game channel is open.
  void Function(RtcSession)? onReady;

  RTCPeerConnection? _pc;
  RTCDataChannel? _game, _chat;
  MediaStream? _mic;
  final _remoteAudio = RTCVideoRenderer();
  bool _audioInit = false;
  void Function(String)? _handler;
  StreamSubscription? _roomSub, _candSub;
  bool _readyFired = false;

  DocumentReference<Map<String, dynamic>> get _room => Dark.db.collection('rooms').doc(code);

  static const _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'sdpSemantics': 'unified-plan',
  };

  static String newCode() {
    const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = math.Random.secure();
    return String.fromCharCodes(List.generate(4, (_) => abc.codeUnitAt(r.nextInt(abc.length))));
  }

  // ---- Lifecycle ------------------------------------------------------------------

  /// Open a room and wait for a guest.
  static Future<RtcSession> host(Seat me) async {
    final s = RtcSession._(true, newCode(), me);
    current = s;
    await s._start();
    return s;
  }

  /// Take the guest seat in [code].
  static Future<RtcSession> join(String code, Seat me) async {
    final s = RtcSession._(false, code.toUpperCase().trim(), me);
    current = s;
    await s._start();
    return s;
  }

  Future<void> _start() async {
    state.value = isHost ? RtcState.waiting : RtcState.connecting;
    final pc = await createPeerConnection(_config);
    _pc = pc;
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          if (state.value != RtcState.connected) state.value = RtcState.connected;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          state.value = RtcState.failed;
          _system('connection lost');
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          if (state.value != RtcState.closed) {
            state.value = RtcState.failed;
            _system('the other fighter left');
          }
        default:
          break;
      }
    };
    pc.onTrack = (e) async {
      if (e.track.kind == 'audio' && e.streams.isNotEmpty) {
        if (!_audioInit) {
          await _remoteAudio.initialize();
          _audioInit = true;
        }
        _remoteAudio.srcObject = e.streams.first;
      }
    };
    await _openMic(pc);

    if (isHost) {
      _game = await pc.createDataChannel('game', RTCDataChannelInit()..ordered = true);
      _chat = await pc.createDataChannel('chat', RTCDataChannelInit()..ordered = true);
      _wireChannels();
      pc.onIceCandidate = (c) => _room.collection('callerCandidates').add(c.toMap() as Map<String, dynamic>);
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await _room.set({
        'hostUid': me.uid,
        'hostName': me.name,
        'hostChar': me.char,
        'guestUid': null,
        'guestName': null,
        'guestChar': null,
        'offer': {'type': offer.type, 'sdp': offer.sdp},
        'answer': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _roomSub = _room.snapshots().listen((d) async {
        final m = d.data();
        if (m == null) return;
        if (peer == null && m['guestUid'] != null) {
          peer = Seat(m['guestUid'] as String, m['guestName'] as String? ?? 'GUEST', m['guestChar'] as String? ?? 'huntress');
          _system('${peer!.name} took the seat');
          state.value = RtcState.connecting;
        }
        final ans = m['answer'] as Map<String, dynamic>?;
        if (ans != null && (await pc.getRemoteDescription()) == null) {
          await pc.setRemoteDescription(RTCSessionDescription(ans['sdp'] as String, ans['type'] as String));
        }
        _maybeReady();
      });
      _candSub = _room.collection('calleeCandidates').snapshots().listen((q) {
        for (final ch in q.docChanges) {
          if (ch.type == DocumentChangeType.added) pc.addCandidate(_candidate(ch.doc.data()!));
        }
      });
    } else {
      pc.onDataChannel = (ch) {
        if (ch.label == 'game') _game = ch;
        if (ch.label == 'chat') _chat = ch;
        _wireChannels();
      };
      final snap = await _room.get();
      final m = snap.data();
      if (m == null || m['offer'] == null) {
        state.value = RtcState.failed;
        _system('no room with code $code');
        return;
      }
      if (m['guestUid'] != null && m['guestUid'] != me.uid) {
        state.value = RtcState.failed;
        _system('that room is full');
        return;
      }
      peer = Seat(m['hostUid'] as String, m['hostName'] as String? ?? 'HOST', m['hostChar'] as String? ?? 'huntress');
      pc.onIceCandidate = (c) => _room.collection('calleeCandidates').add(c.toMap() as Map<String, dynamic>);
      final offer = m['offer'] as Map<String, dynamic>;
      await pc.setRemoteDescription(RTCSessionDescription(offer['sdp'] as String, offer['type'] as String));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await _room.update({
        'guestUid': me.uid,
        'guestName': me.name,
        'guestChar': me.char,
        'answer': {'type': answer.type, 'sdp': answer.sdp},
      });
      _candSub = _room.collection('callerCandidates').snapshots().listen((q) {
        for (final ch in q.docChanges) {
          if (ch.type == DocumentChangeType.added) pc.addCandidate(_candidate(ch.doc.data()!));
        }
      });
    }
  }

  RTCIceCandidate _candidate(Map<String, dynamic> m) =>
      RTCIceCandidate(m['candidate'] as String?, m['sdpMid'] as String?, (m['sdpMLineIndex'] as num?)?.toInt());

  Future<void> _openMic(RTCPeerConnection pc) async {
    try {
      final mic = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      _mic = mic;
      for (final t in mic.getAudioTracks()) {
        await pc.addTrack(t, mic);
      }
      voiceOn.value = true;
    } catch (e) {
      debugPrint('microphone unavailable: $e');
      voiceOn.value = false;
      _system('voice off (no microphone permission)');
    }
  }

  void _wireChannels() {
    final g = _game;
    if (g != null) {
      g.onMessage = (m) => _handler?.call(m.text);
      g.onDataChannelState = (s) {
        if (s == RTCDataChannelState.RTCDataChannelOpen) {
          state.value = RtcState.connected;
          _maybeReady();
        }
      };
    }
    final c = _chat;
    if (c != null) {
      c.onMessage = (m) {
        try {
          final j = jsonDecode(m.text) as Map<String, dynamic>;
          switch (j['k']) {
            case 'msg':
              _push(ChatMessage(j['t'] as String, mine: false));
            case 'mute':
              peerMuted.value = j['v'] == true;
          }
        } catch (_) {}
      };
    }
  }

  void _maybeReady() {
    if (_readyFired || peer == null) return;
    if (_game?.state != RTCDataChannelState.RTCDataChannelOpen) return;
    _readyFired = true;
    onReady?.call(this);
  }

  // ---- Chat and voice ---------------------------------------------------------------

  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _chat?.send(RTCDataChannelMessage(jsonEncode({'k': 'msg', 't': t})));
    _push(ChatMessage(t, mine: true));
  }

  void toggleMute() {
    muted.value = !muted.value;
    for (final t in _mic?.getAudioTracks() ?? const <MediaStreamTrack>[]) {
      t.enabled = !muted.value;
    }
    _chat?.send(RTCDataChannelMessage(jsonEncode({'k': 'mute', 'v': muted.value})));
  }

  void _push(ChatMessage m) {
    final list = List<ChatMessage>.from(chat.value)..add(m);
    if (list.length > 80) list.removeAt(0);
    chat.value = list;
  }

  void _system(String text) => _push(ChatMessage(text, mine: false, system: true));

  // ---- NetLink ------------------------------------------------------------------------

  @override
  void send(String message) {
    final g = _game;
    if (g != null && g.state == RTCDataChannelState.RTCDataChannelOpen) {
      g.send(RTCDataChannelMessage(message));
    }
  }

  @override
  set onMessage(void Function(String message)? handler) => _handler = handler;

  @override
  void close() {
    if (state.value == RtcState.closed) return;
    state.value = RtcState.closed;
    _roomSub?.cancel();
    _candSub?.cancel();
    _game?.close();
    _chat?.close();
    _mic?.getTracks().forEach((t) => t.stop());
    _mic?.dispose();
    if (_audioInit) _remoteAudio.dispose();
    _pc?.close();
    if (isHost) {
      _room.delete().catchError((_) {});
    }
    if (current == this) current = null;
  }
}
