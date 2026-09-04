import 'dart:convert';

import 'package:flame/components.dart';

import 'fighter.dart';
import 'shadow_game.dart';
import 'villain.dart';
import 'weapons.dart';

/// A reliable, ordered message pipe to the other player (a WebRTC data
/// channel in production, an in-memory pair in tests). The game never sees
/// Firebase or WebRTC directly.
abstract class NetLink {
  bool get isHost;
  void send(String message);
  set onMessage(void Function(String message)? handler);
  void close();
}

/// The other player's fighter on the host: driven by the sticks they send,
/// exactly the way the local hero is driven by the on-screen sticks.
class RemoteFighter extends VillainFighter {
  RemoteFighter({
    required super.name,
    required super.charKey,
    required super.lib,
    super.build,
  }) : super(weapon: Weapon.enemyBlade, maxHealth: 100, aggression: 1) {
    remote = true;
    onComboCycle = (c, smash) {
      if (smash) smashCd = ShadowGame.smashRecharge;
    };
  }

  final Vector2 ls = Vector2.zero(), rs = Vector2.zero();
  final List<MoveKind> taps = [];
  double smashCd = 0;

  /// Called by the host every frame of the fight.
  void drive(double dt) {
    smashCd = (smashCd - dt).clamp(0.0, double.infinity);
    applySticks(ls, rs, smashArmed: smashCd <= 0);
    for (final k in taps) {
      startMove(k);
    }
    taps.clear();
  }
}

/// One network duel. The host runs the whole simulation and streams
/// snapshots; the guest streams its sticks and draws what it is told.
///
/// Wire format (JSON, one object per message, `k` is the kind):
///   i  guest → host   sticks  {l:[x,y], r:[x,y]}
///   t  guest → host   tap     {m: moveKind index}
///   s  host → guest   snapshot {a:[…hero], b:[…villain]}
///   x  host → guest   strike  {…fx}
///   e  host → guest   end     {l: leftWon}
///   r  host → guest   rematch
class NetDuel {
  NetDuel(this.link) {
    link.onMessage = _receive;
  }

  final NetLink link;
  ShadowGame? _game;
  bool get isHost => link.isHost;

  static const snapshotHz = 20.0;
  static const sticksHz = 30.0;
  double _snapT = 0, _stickT = 0;
  Vector2 _lastL = Vector2.zero(), _lastR = Vector2.zero();

  /// Fired when the other side stops talking (link closed).
  void Function()? onDropped;

  void attach(ShadowGame game) => _game = game;

  void detach() {
    _game = null;
    link.onMessage = null;
    link.close();
  }

  // ---- Guest → host ---------------------------------------------------------

  /// Guest: forward the sticks (throttled; always when they change).
  void sendSticks(Vector2 l, Vector2 r) {
    final changed = (l - _lastL).length > .02 || (r - _lastR).length > .02;
    if (!changed && _stickT < 1 / sticksHz) return;
    _stickT = 0;
    _lastL = l.clone();
    _lastR = r.clone();
    link.send(jsonEncode({'k': 'i', 'l': [_r(l.x), _r(l.y)], 'r': [_r(r.x), _r(r.y)]}));
  }

  void sendTap(MoveKind k) => link.send(jsonEncode({'k': 't', 'm': k.index}));

  // ---- Host → guest ---------------------------------------------------------

  void tick(double dt) {
    _stickT += dt;
    if (!isHost) return;
    _snapT += dt;
    if (_snapT < 1 / snapshotHz) return;
    _snapT = 0;
    final g = _game;
    if (g == null || g.villain == null) return;
    link.send(jsonEncode({'k': 's', 'a': _pack(g.hero), 'b': _pack(g.villain!)}));
  }

  List<Object> _pack(Fighter f) {
    final (anim, frame) = f.animFrame();
    final (lean, sq) = f.poseLeanSquash;
    return [
      _r(f.wx), _r(f.h), f.facing, anim, frame, _r(f.hp), _r(lean), _r(sq),
      _r(f.flashT), _r(f.blockFlashT), f.state.index, f.landT > 0 ? 1 : 0,
    ];
  }

  void relayStrike(Fighter from, Fighter target, MoveSpec m, double dmg, bool blocked, bool killed,
      bool crit, bool parried) {
    if (!isHost) return;
    final g = _game;
    if (g == null) return;
    link.send(jsonEncode({
      'k': 'x',
      'f': from == g.hero ? 0 : 1,
      'd': _r(dmg),
      'b': blocked ? 1 : 0,
      'z': killed ? 1 : 0,
      'c': crit ? 1 : 0,
      'p': parried ? 1 : 0,
      'h': m.heavy ? 1 : 0,
      'm': m.kind.index,
      'kx': _r(m.kx),
      'ku': _r(m.kup),
      'sh': _r(m.shake),
    }));
  }

  void sendEnd({required bool leftWon}) => link.send(jsonEncode({'k': 'e', 'l': leftWon ? 1 : 0}));

  /// Host: the same duel again.
  void sendRestart() => link.send(jsonEncode({'k': 'r'}));

  // ---- Receive ----------------------------------------------------------------

  void _receive(String raw) {
    final g = _game;
    if (g == null) return;
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (m['k']) {
      case 'i':
        final VillainFighter? v = g.villain;
        if (!isHost || v is! RemoteFighter) return;
        final l = m['l'] as List, r = m['r'] as List;
        v.ls.setValues((l[0] as num).toDouble(), (l[1] as num).toDouble());
        v.rs.setValues((r[0] as num).toDouble(), (r[1] as num).toDouble());
      case 't':
        final VillainFighter? v = g.villain;
        if (!isHost || v is! RemoteFighter) return;
        final i = (m['m'] as num).toInt();
        if (i >= 0 && i < MoveKind.values.length && v.taps.length < 3) v.taps.add(MoveKind.values[i]);
      case 's':
        if (isHost) return;
        _unpack(g.hero, m['a'] as List);
        final v = g.villain;
        if (v != null) _unpack(v, m['b'] as List);
      case 'x':
        if (isHost) return;
        final v = g.villain;
        if (v == null) return;
        final from = (m['f'] as num).toInt() == 0 ? g.hero : v;
        final target = from == g.hero ? v : g.hero;
        final kind = MoveKind.values[((m['m'] as num).toInt()).clamp(0, MoveKind.values.length - 1)];
        final spec = MoveSpec(kind, kind.name, 0,
            winStart: 0,
            winEnd: 0,
            dmg: (m['d'] as num).toDouble(),
            range: 0,
            kx: (m['kx'] as num).toDouble(),
            kup: (m['ku'] as num).toDouble(),
            shake: (m['sh'] as num).toDouble(),
            heavy: m['h'] == 1);
        g.onStrike(from, target, spec, (m['d'] as num).toDouble(), m['b'] == 1, m['z'] == 1, m['c'] == 1,
            parried: m['p'] == 1);
      case 'e':
        if (isHost) return;
        g.netVerdict(leftWon: m['l'] == 1);
      case 'r':
        if (isHost) return;
        g.restartNetDuel();
    }
  }

  void _unpack(Fighter f, List s) {
    f.wx = (s[0] as num).toDouble();
    f.h = (s[1] as num).toDouble();
    f.facing = (s[2] as num).toInt();
    f.puppetAnim = s[3] as String;
    f.puppetFrame = (s[4] as num).toInt();
    f.hp = (s[5] as num).toDouble();
    f.puppetLean = (s[6] as num).toDouble();
    f.puppetSquash = (s[7] as num).toDouble();
    f.flashT = (s[8] as num).toDouble();
    f.blockFlashT = (s[9] as num).toDouble();
    f.state = FState.values[((s[10] as num).toInt()).clamp(0, FState.values.length - 1)];
    if (s.length > 11 && s[11] == 1 && f.landT <= 0) f.landT = .18;
  }

  static double _r(double v) => (v * 100).roundToDouble() / 100;
}

/// Two links joined back to back, for tests and for a local hot-seat.
class LoopbackLink implements NetLink {
  LoopbackLink._(this.isHost);

  static (LoopbackLink host, LoopbackLink guest) pair() {
    final a = LoopbackLink._(true), b = LoopbackLink._(false);
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  @override
  final bool isHost;
  LoopbackLink? _peer;
  void Function(String)? _handler;
  final List<String> _queue = [];

  @override
  set onMessage(void Function(String)? handler) => _handler = handler;

  @override
  void send(String message) => _peer?._queue.add(message);

  /// Deliver everything queued so far (tests pump this by hand).
  void flush() {
    final pending = List<String>.from(_queue);
    _queue.clear();
    for (final m in pending) {
      _handler?.call(m);
    }
  }

  @override
  void close() {
    _peer = null;
    _queue.clear();
  }
}
