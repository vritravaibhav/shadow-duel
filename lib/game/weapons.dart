import 'dart:ui';

import 'sprites.dart';

enum MoveKind { punch, kick, slash, heavy, high }

/// Where a blow lands. A high guard covers head and body, a low guard body
/// and feet; heavy blows ignore guards.
enum Zone { head, body, feet }

/// What a fighter is covering: a high guard shields head and body, a mid
/// guard the body, a low guard body and feet. A parry (see
/// [Fighter.parrying]) narrows the cover to the exact zone but takes nothing.
enum GuardZone { none, high, mid, low }

/// A sword's special ability. Passives apply while equipped; the rest
/// trigger on hit (or on heavy hit).
enum Special {
  quickDraw,
  bleed,
  cleave,
  ignite,
  freeze,
  lifesteal,
  shock,
  poison,
  radiance,
  dragonfire,
}

extension SpecialInfo on Special {
  String get title => switch (this) {
        Special.quickDraw => 'Quick Draw',
        Special.bleed => 'Bleed',
        Special.cleave => 'Cleave',
        Special.ignite => 'Ignite',
        Special.freeze => 'Freeze',
        Special.lifesteal => 'Lifesteal',
        Special.shock => 'Shock',
        Special.poison => 'Poison',
        Special.radiance => 'Radiance',
        Special.dragonfire => 'Dragonfire',
      };

  String get description => switch (this) {
        Special.quickDraw => 'Swings 25% faster',
        Special.bleed => 'Hits bleed for 3s',
        Special.cleave => 'Heavy hits launch the enemy across the arena',
        Special.ignite => 'Heavy hits set the enemy ablaze',
        Special.freeze => 'Heavy hits chill the enemy: slow moves and swings',
        Special.lifesteal => 'Heals 25% of damage dealt',
        Special.shock => 'Hits stun longer and headshot twice as often',
        Special.poison => 'Hits poison for 7s',
        Special.radiance => 'Take 40% less damage while equipped',
        Special.dragonfire => 'Heavy hits erupt: burn, blast and launch',
      };
}

/// Runtime weapon stats. Villains use plain stat sets; the hero's weapon is
/// whichever [Sword] card is equipped, or [fists] when none is.
class Weapon {
  const Weapon({
    required this.id,
    required this.name,
    required this.strength,
    required this.power,
    required this.speed,
    required this.range,
    required this.trail,
    this.special,
  });

  final String id;
  final String name;

  /// Strength multiplies all damage; power additionally multiplies the heavy.
  final double strength, power, speed, range;
  final Color trail;
  final Special? special;

  /// The same blade after [level] forge upgrades: sharper, heavier, quicker
  /// and a touch longer every mark.
  Weapon forged(int level) {
    if (level <= 0) return this;
    return Weapon(
      id: id,
      name: name,
      strength: strength * (1 + .07 * level),
      power: power * (1 + .05 * level),
      speed: speed * (1 + .025 * level),
      range: range + 2.0 * level,
      trail: trail,
      special: special,
    );
  }

  static const fists = Weapon(
    id: 'fists',
    name: 'FISTS',
    strength: 0.7,
    power: 0.8,
    speed: 1.15,
    range: 0,
    trail: Color(0x55FFFFFF),
  );

  /// Generic villain blade.
  static const enemyBlade = Weapon(
    id: 'enemy',
    name: 'BLADE',
    strength: 1.0,
    power: 1.1,
    speed: 1.0,
    range: 24,
    trail: Color(0x88FFFFFF),
  );
}

/// A collectible sword card: a [Weapon] plus card economy stats.
class Sword {
  const Sword({
    required this.weapon,
    required this.active,
    required this.recharge,
    required this.unlockLevel,
    required this.icon,
    required this.price,
    this.level = 0,
  });

  final Weapon weapon;

  /// Seconds the drawn blade can be used before it must rest.
  final double active;

  /// Seconds the spent blade rests before it can be drawn again.
  final double recharge;

  /// Stage that must be cleared before the blade is put up for sale
  /// (0 = on the rack from the start).
  final int unlockLevel;
  final String icon;

  /// Coins to buy the blade. 0 = the starter, yours for free.
  final int price;

  /// Forge marks applied (0 = as sold).
  final int level;

  static const maxLevel = 5;

  String get id => weapon.id;
  String get name => weapon.name;
  bool get isStarter => price == 0;
  bool get maxed => level >= maxLevel;

  /// Coins for the next mark; steeper on the rarer blades.
  int get upgradeCost => maxed ? 0 : ((price == 0 ? 60 : price) * .45 * (level + 1)).round();

  /// This blade with [level] marks forged in: better numbers, longer use.
  Sword at(int level) {
    final l = level.clamp(0, maxLevel);
    return Sword(
      weapon: weapon.forged(l),
      active: active + 1.0 * l,
      recharge: recharge * (1 - .03 * l),
      unlockLevel: unlockLevel,
      icon: icon,
      price: price,
      level: l,
    );
  }
}

class Swords {
  static const all = [
    Sword(
      weapon: Weapon(id: 'wakizashi', name: 'WAKIZASHI', strength: 0.9, power: 1.0, speed: 1.25, range: 22, trail: Color(0xFFCFFFE0), special: Special.quickDraw),
      active: 14, recharge: 30, unlockLevel: 0, icon: 'wakizashi', price: 0,
    ),
    Sword(
      weapon: Weapon(id: 'katana', name: 'KATANA', strength: 1.15, power: 1.2, speed: 1.0, range: 34, trail: Color(0xFF7DEBFF), special: Special.bleed),
      active: 12, recharge: 36, unlockLevel: 0, icon: 'katana', price: 90,
    ),
    Sword(
      weapon: Weapon(id: 'nodachi', name: 'NODACHI', strength: 1.5, power: 1.7, speed: 0.8, range: 46, trail: Color(0xFFFFD08A), special: Special.cleave),
      active: 9, recharge: 45, unlockLevel: 2, icon: 'nodachi', price: 160,
    ),
    Sword(
      weapon: Weapon(id: 'flame', name: 'FLAME BLADE', strength: 1.3, power: 1.5, speed: 0.95, range: 36, trail: Color(0xFFFF8A3D), special: Special.ignite),
      active: 10, recharge: 42, unlockLevel: 4, icon: 'flame', price: 260,
    ),
    Sword(
      weapon: Weapon(id: 'frost', name: 'FROST EDGE', strength: 1.2, power: 1.4, speed: 1.0, range: 36, trail: Color(0xFF9FDBFF), special: Special.freeze),
      active: 10, recharge: 42, unlockLevel: 6, icon: 'frost', price: 340,
    ),
    Sword(
      weapon: Weapon(id: 'shadow', name: 'SHADOW BLADE', strength: 1.25, power: 1.3, speed: 1.1, range: 34, trail: Color(0xFFC77DFF), special: Special.lifesteal),
      active: 9, recharge: 40, unlockLevel: 8, icon: 'shadow', price: 440,
    ),
    Sword(
      weapon: Weapon(id: 'thunder', name: 'THUNDER FANG', strength: 1.4, power: 1.5, speed: 1.05, range: 38, trail: Color(0xFFFFF176), special: Special.shock),
      active: 9, recharge: 45, unlockLevel: 10, icon: 'thunder', price: 560,
    ),
    Sword(
      weapon: Weapon(id: 'venom', name: 'VENOM KRIS', strength: 1.1, power: 1.2, speed: 1.2, range: 26, trail: Color(0xFF9CFF6B), special: Special.poison),
      active: 12, recharge: 36, unlockLevel: 12, icon: 'venom', price: 640,
    ),
    Sword(
      weapon: Weapon(id: 'excalibur', name: 'EXCALIBUR', strength: 1.6, power: 1.8, speed: 0.95, range: 40, trail: Color(0xFFFFF4C2), special: Special.radiance),
      active: 8, recharge: 55, unlockLevel: 14, icon: 'excalibur', price: 900,
    ),
    Sword(
      weapon: Weapon(id: 'dragon', name: 'DRAGON CLEAVER', strength: 1.8, power: 2.2, speed: 0.75, range: 48, trail: Color(0xFFFF5C3D), special: Special.dragonfire),
      active: 7, recharge: 60, unlockLevel: 16, icon: 'dragon', price: 1200,
    ),
  ];

  static Sword byId(String id) => all.firstWhere((s) => s.id == id);

  /// Swords on sale once [highestCleared] stages are beaten.
  static List<Sword> unlockedAt(int highestCleared) =>
      all.where((s) => s.unlockLevel <= highestCleared).toList();
}

class MoveSpec {
  MoveSpec(
    this.kind,
    this.animName,
    this.duration, {
    required this.winStart,
    required this.winEnd,
    required this.dmg,
    required this.range,
    required this.kx,
    required this.kup,
    required this.shake,
    this.heavy = false,
    this.zone = Zone.body,
  });

  final MoveKind kind;
  final String animName;
  final double duration;
  final double winStart, winEnd;
  final double dmg, range, kx, kup, shake;
  final bool heavy;
  final Zone zone;

  /// A sword-art strike: unblockable, resolved outside the swing state machine.
  factory MoveSpec.art(double dmg, {double kx = 200, double kup = 0, double shake = 6}) =>
      MoveSpec(MoveKind.heavy, 'heavy', 0,
          winStart: 0, winEnd: 0, dmg: dmg, range: 0, kx: kx, kup: kup, shake: shake, heavy: true);
}

Map<MoveKind, MoveSpec> buildMoves(Weapon w, SpriteLibrary lib, String charKey) {
  double dur(String name) => lib.anim(charKey, name).duration;
  final cleave = w.special == Special.cleave ? 1.8 : 1.0;
  final dragon = w.special == Special.dragonfire ? 1.6 : 1.0;
  return {
    MoveKind.punch: MoveSpec(
      MoveKind.punch,
      'punch',
      dur('punch') / (w.speed * 1.08),
      winStart: .42,
      winEnd: .68,
      dmg: 7 * w.strength,
      range: 42 + w.range * .5,
      kx: 90,
      kup: 0,
      shake: 2,
    ),
    // Low sweep at the feet: trips through a high guard.
    MoveKind.kick: MoveSpec(
      MoveKind.kick,
      'kick',
      dur('kick'),
      winStart: .4,
      winEnd: .66,
      dmg: 10,
      range: 60,
      kx: 130,
      kup: 300,
      shake: 3,
      zone: Zone.feet,
    ),
    // High cut at the head: headshots often, beaten by a high guard.
    MoveKind.high: MoveSpec(
      MoveKind.high,
      'slash',
      dur('slash') / (w.speed * 1.05),
      winStart: .42,
      winEnd: .64,
      dmg: 11 * w.strength,
      range: 46 + w.range,
      kx: 160,
      kup: 0,
      shake: 4,
      zone: Zone.head,
    ),
    MoveKind.slash: MoveSpec(
      MoveKind.slash,
      'slash',
      dur('slash') / w.speed,
      winStart: .42,
      winEnd: .64,
      dmg: 13 * w.strength,
      range: 46 + w.range,
      kx: 170,
      kup: 0,
      shake: 4,
    ),
    MoveKind.heavy: MoveSpec(
      MoveKind.heavy,
      'heavy',
      dur('heavy') / w.speed,
      winStart: .52,
      winEnd: .7,
      dmg: 16 * w.strength * w.power,
      range: 48 + w.range * .8,
      kx: 260 * cleave * dragon,
      kup: 120 * cleave,
      shake: 8 * cleave,
      heavy: true,
      zone: Zone.head,
    ),
  };
}
