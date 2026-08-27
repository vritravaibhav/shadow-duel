/// Sword Arts: every blade (and bare hands) answers two drawn glyphs.
/// **V** is the blade's offensive art, **W** its defensive or utility art.
enum ArtGesture { v, w }

enum ArtKind {
  flurry, breathe, // fists
  flashStep, secondWind, // wakizashi
  crescentCut, iaiStance, // katana
  earthsplitter, ironWill, // nodachi
  fireWave, blazingAura, // flame blade
  glacialLance, iceArmor, // frost edge
  shadowStrike, veil, // shadow blade
  thunderclap, stormCharge, // thunder fang
  toxicFang, antidote, // venom kris
  holyLance, sanctuary, // excalibur
  dragonBreath, draconicRage, // dragon cleaver
}

class SwordArt {
  const SwordArt(this.kind, this.gesture, this.name, this.description, this.cooldown);
  final ArtKind kind;
  final ArtGesture gesture;
  final String name;
  final String description;
  final double cooldown;

  String get glyph => gesture == ArtGesture.v ? 'V' : 'W';
}

class Arts {
  static const _table = <String, (SwordArt, SwordArt)>{
    'fists': (
      SwordArt(ArtKind.flurry, ArtGesture.v, 'Flurry', 'Three lightning-fast punches', 7),
      SwordArt(ArtKind.breathe, ArtGesture.w, 'Breathe', 'Steady yourself: heal 8', 10),
    ),
    'wakizashi': (
      SwordArt(ArtKind.flashStep, ArtGesture.v, 'Flash Step', 'Dash through the enemy with three cuts', 8),
      SwordArt(ArtKind.secondWind, ArtGesture.w, 'Second Wind', 'Recover 15% health', 12),
    ),
    'katana': (
      SwordArt(ArtKind.crescentCut, ArtGesture.v, 'Crescent Cut', 'Hurl a slash wave that bleeds', 9),
      SwordArt(ArtKind.iaiStance, ArtGesture.w, 'Iaijutsu Stance', 'Untouchable for 1.5s; your next hit is a headshot', 14),
    ),
    'nodachi': (
      SwordArt(ArtKind.earthsplitter, ArtGesture.v, 'Earthsplitter', 'Slam the ground: a shockwave launches and stuns', 11),
      SwordArt(ArtKind.ironWill, ArtGesture.w, 'Iron Will', 'Take 70% less damage for 5s', 15),
    ),
    'flame': (
      SwordArt(ArtKind.fireWave, ArtGesture.v, 'Fire Wave', 'A wave of flame that sets the enemy ablaze', 9),
      SwordArt(ArtKind.blazingAura, ArtGesture.w, 'Blazing Aura', 'Heal 10; anyone who strikes you burns for 6s', 14),
    ),
    'frost': (
      SwordArt(ArtKind.glacialLance, ArtGesture.v, 'Glacial Lance', 'An ice lance that freezes on impact', 9),
      SwordArt(ArtKind.iceArmor, ArtGesture.w, 'Ice Armor', 'A frost shield absorbs the next 30 damage', 13),
    ),
    'shadow': (
      SwordArt(ArtKind.shadowStrike, ArtGesture.v, 'Shadow Strike', 'Vanish and reappear behind the enemy with a headshot', 10),
      SwordArt(ArtKind.veil, ArtGesture.w, 'Veil', 'Fade from sight: untouchable and ignored for 3s', 15),
    ),
    'thunder': (
      SwordArt(ArtKind.thunderclap, ArtGesture.v, 'Thunderclap', 'Call lightning down on the enemy: damage and stun', 10),
      SwordArt(ArtKind.stormCharge, ArtGesture.w, 'Storm Charge', 'Swing 40% faster for 6s', 13),
    ),
    'venom': (
      SwordArt(ArtKind.toxicFang, ArtGesture.v, 'Toxic Fang', 'A venomous stab: heavy poison for 7s', 8),
      SwordArt(ArtKind.antidote, ArtGesture.w, 'Antidote', 'Cure bleed, burn, poison and frost; heal 20', 12),
    ),
    'excalibur': (
      SwordArt(ArtKind.holyLance, ArtGesture.v, 'Holy Lance', 'A lance of light that launches the enemy', 11),
      SwordArt(ArtKind.sanctuary, ArtGesture.w, 'Sanctuary', 'Invincible for 3s and heal 25', 18),
    ),
    'dragon': (
      SwordArt(ArtKind.dragonBreath, ArtGesture.v, "Dragon's Breath", 'A cone of fire: massive damage and burning', 12),
      SwordArt(ArtKind.draconicRage, ArtGesture.w, 'Draconic Rage', 'Deal 60% more damage and drink 25% of it for 6s', 16),
    ),
  };

  static (SwordArt, SwordArt) of(String weaponId) => _table[weaponId] ?? _table['fists']!;

  static SwordArt art(String weaponId, ArtGesture g) {
    final (v, w) = of(weaponId);
    return g == ArtGesture.v ? v : w;
  }
}
