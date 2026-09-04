import 'package:shared_preferences/shared_preferences.dart';

import 'weapons.dart';

/// Saved campaign progress: how far the player has come, how well each stage
/// was cleared (0-3 stars), their best combo, and the purse: coins earned in
/// duels, the blades bought with them and the forge marks on each.
class Progress {
  static const _key = 'highestCleared';
  static const _starKey = 'stars_';
  static const _comboKey = 'bestCombo';
  static const _coinKey = 'coins';
  static const _ownedKey = 'ownedSwords';
  static const _levelKey = 'swordLevel_';
  static const _earnedKey = 'coinsEarned';

  int highestCleared = 0;
  int bestCombo = 0;
  final Map<int, int> stars = {};

  int coins = 0;

  /// Lifetime coins earned (the purse only ever goes down by spending).
  int coinsEarned = 0;
  final Set<String> _owned = {};
  final Map<String, int> _levels = {};

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    highestCleared = p.getInt(_key) ?? 0;
    bestCombo = p.getInt(_comboKey) ?? 0;
    coins = p.getInt(_coinKey) ?? 0;
    coinsEarned = p.getInt(_earnedKey) ?? 0;
    _owned
      ..clear()
      ..addAll(p.getStringList(_ownedKey) ?? const []);
    _levels.clear();
    stars.clear();
    for (final k in p.getKeys()) {
      if (k.startsWith(_starKey)) {
        final stage = int.tryParse(k.substring(_starKey.length));
        if (stage != null) stars[stage] = p.getInt(k) ?? 0;
      } else if (k.startsWith(_levelKey)) {
        _levels[k.substring(_levelKey.length)] = p.getInt(k) ?? 0;
      }
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

  /// Whether [stage] has ever been cleared (a repeat pays far less).
  bool isCleared(int stage) => stage <= highestCleared;

  // ---- Coins ---------------------------------------------------------------

  /// The purse after a duel. A first clear pays well and scales with the
  /// stage and the stars; a repeat pays a token; a loss a coin for the road.
  static int reward({required int stage, required bool win, required bool firstClear, int stars = 0}) {
    if (!win) return 2;
    if (firstClear) return 40 + 12 * stage + 10 * (stars - 1).clamp(0, 2);
    return 3 + stage ~/ 4;
  }

  /// A Dark trial pays a modest flat purse: it is a paid arena, not a grind.
  static int darkTrialReward(int trial, {int stars = 0}) => 8 + 4 * trial + 2 * (stars - 1).clamp(0, 2);

  Future<void> addCoins(int n) async {
    if (n <= 0) return;
    coins += n;
    coinsEarned += n;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_coinKey, coins);
    await p.setInt(_earnedKey, coinsEarned);
  }

  bool canAfford(int cost) => coins >= cost;

  Future<bool> _spend(int cost) async {
    if (cost < 0 || coins < cost) return false;
    coins -= cost;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_coinKey, coins);
    return true;
  }

  // ---- Swords ---------------------------------------------------------------

  /// The starter is always yours; everything else must be bought.
  bool owns(Sword s) => s.isStarter || _owned.contains(s.id);

  /// On the rack (visible and buyable) once its stage is cleared.
  bool onSale(Sword s) => s.unlockLevel <= highestCleared;

  int levelOf(Sword s) => _levels[s.id] ?? 0;

  /// The blade as it fights today: bought marks forged in.
  Sword forged(Sword s) => s.at(levelOf(s));

  /// Every owned blade with its marks, in rack order.
  List<Sword> get ownedSwords => [for (final s in Swords.all) if (owns(s)) forged(s)];

  bool canBuy(Sword s) => !owns(s) && onSale(s) && canAfford(s.price);

  Future<bool> buy(Sword s) async {
    if (!canBuy(s)) return false;
    if (!await _spend(s.price)) return false;
    _owned.add(s.id);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_ownedKey, _owned.toList());
    return true;
  }

  bool canUpgrade(Sword s) => owns(s) && !forged(s).maxed && canAfford(forged(s).upgradeCost);

  Future<bool> upgrade(Sword s) async {
    if (!canUpgrade(s)) return false;
    if (!await _spend(forged(s).upgradeCost)) return false;
    final lvl = levelOf(s) + 1;
    _levels[s.id] = lvl;
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_levelKey${s.id}', lvl);
    return true;
  }
}
