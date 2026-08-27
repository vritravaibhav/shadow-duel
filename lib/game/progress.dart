import 'package:shared_preferences/shared_preferences.dart';

/// Saved campaign progress: the highest stage cleared.
class Progress {
  static const _key = 'highestCleared';

  int highestCleared = 0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    highestCleared = p.getInt(_key) ?? 0;
  }

  Future<void> clearStage(int stage) async {
    if (stage <= highestCleared) return;
    highestCleared = stage;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_key, stage);
  }

  bool isUnlocked(int stage) => stage <= highestCleared + 1;
}
