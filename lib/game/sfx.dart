import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Sound effects and music (assets/audio/, mapped by role in sfx.json).
/// Silent under `flutter test` and whenever the audio plugin is unavailable.
class Sfx {
  static bool enabled = true;
  static bool _ready = false;
  static Map<String, String> _files = {};
  static String? _music;
  static final _rng = math.Random();

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      enabled = false;
      return;
    }
    try {
      _files = (jsonDecode(await rootBundle.loadString('assets/audio/sfx.json'))
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
      await FlameAudio.audioCache.loadAll(_files.values.toList());
      FlameAudio.bgm.initialize();
    } catch (e) {
      debugPrint('audio disabled: $e');
      enabled = false;
    }
  }

  static void play(String role, {double volume = 1}) {
    if (!enabled) return;
    final file = _files[role];
    if (file == null) return;
    try {
      FlameAudio.play(file, volume: volume).then<void>(
        (_) {},
        onError: (Object e) => debugPrint('sfx "$role": $e'),
      );
    } catch (e) {
      // A single failed play never breaks the game.
      debugPrint('sfx "$role": $e');
    }
  }

  static void one(List<String> roles, {double volume = 1}) =>
      play(roles[_rng.nextInt(roles.length)], volume: volume);

  static void swing({bool heavy = false}) =>
      heavy ? play('swing_heavy', volume: .9) : one(const ['swing1', 'swing2', 'swing3'], volume: .7);

  static void music(String track, {double volume = .4}) {
    if (!enabled || _music == track) return;
    _music = track;
    try {
      FlameAudio.bgm.play('music/$track.m4a', volume: volume);
    } catch (_) {}
  }

  static void stopMusic() {
    if (!enabled) return;
    _music = null;
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }
}
