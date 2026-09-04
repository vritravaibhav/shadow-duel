/// The Dark roster: the women of the arena. They are both the opponents of
/// the Dark trials and the fighters a paid player can duel as.
///
/// Every entry is drawn from a sprite pack in assets/images/packs/ and
/// registered in packs.json (see tool/import_packs.py). The two female packs
/// shipped today are `huntress` and `huntress-2`; drop in more packs and add
/// them here to grow the roster.
class DarkFighter {
  const DarkFighter(this.name, this.charKey, this.title, {this.hp = 100, this.dmg = 1.0, this.agg = 1.0, this.speed = 1.05});
  final String name;
  final String charKey;
  final String title;

  /// Trial tuning when she is the opponent.
  final double hp, dmg, agg, speed;
}

class DarkRoster {
  static const all = [
    DarkFighter('RAVEN', 'huntress', 'the silent glaive', hp: 95, dmg: .95, agg: .95, speed: 1.05),
    DarkFighter('VESPER', 'huntress-2', 'the evening blade', hp: 105, dmg: 1.05, agg: 1.0, speed: 1.08),
    DarkFighter('NYX', 'huntress', 'the night hunter', hp: 120, dmg: 1.15, agg: 1.1, speed: 1.12),
    DarkFighter('SABLE', 'huntress-2', 'the black rose', hp: 140, dmg: 1.25, agg: 1.2, speed: 1.15),
  ];

  static DarkFighter byKey(String charKey, {String? name}) =>
      all.firstWhere((f) => f.charKey == charKey && (name == null || f.name == name), orElse: () => all.first);
}
