import 'package:shared_preferences/shared_preferences.dart';

/// Saved campaign progress: how far the player has come, how well each stage
/// was cleared (0-3 stars), and their best combo.
class Progress {
  static const _key = 'highestCleared';
  static const _starKey = 'stars_';
  static const _comboKey = 'bestCombo';

  int highestCleared = 0;
  int bestCombo = 0;
  final Map<int, int> stars = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    highestCleared = p.getInt(_key) ?? 0;
    bestCombo = p.getInt(_comboKey) ?? 0;
    stars.clear();
    for (final k in p.getKeys()) {
      if (!k.startsWith(_starKey)) continue;
      final stage = int.tryParse(k.substring(_starKey.length));
      if (stage != null) stars[stage] = p.getInt(k) ?? 0;
    }
  }

  int starsFor(int stage) => stars[stage] ?? 0;

  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  /// Records a cleared stage. Returns true when this beat the old star count.
  Future<bool> clearStage(int stage, int earned) async {
    final p = await SharedPreferences.getInstance();
    if (stage > highestCleared) {
      highestCleared = stage;
      await p.setInt(_key, stage);
    }
    final better = earned > starsFor(stage);
    if (better) {
      stars[stage] = earned;
      await p.setInt('$_starKey$stage', earned);
    }
    return better;
  }

  /// Records a combo; returns true if it is a new personal best.
  Future<bool> recordCombo(int combo) async {
    if (combo <= bestCombo) return false;
    bestCombo = combo;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_comboKey, combo);
    return true;
  }

  bool isUnlocked(int stage) => stage <= highestCleared + 1;
}
