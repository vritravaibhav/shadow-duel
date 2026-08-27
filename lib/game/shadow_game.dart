import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'arts.dart';
import 'background.dart';
import 'cards.dart';
import 'effects.dart';
import 'fighter.dart';
import 'gesture_fx.dart';
import 'gestures.dart';
import 'hud.dart';
import 'projectile.dart';
import 'progress.dart';
import 'sprites.dart';
import 'vfx.dart';
import 'villain.dart';
import 'weapons.dart';

const kW = 960.0;
const kH = 540.0;
const kFloorTop = 96.0;
const kArenaHalf = 430.0;
const kZMax = 150.0;

enum Phase { menu, intro, fighting, roundOver, gameOver }

class ArenaWorld extends World with HasGameReference<ShadowGame> {
  @override
  void updateTree(double dt) {
    super.updateTree(dt * game.timeDilation);
  }
}

class StageChar {
  const StageChar(this.name, this.charKey, {this.special});
  final String name;
  final String charKey;

  /// Some villains inflict status effects of their own (see Antidote).
  final Special? special;
}

class StageCfg {
  const StageCfg(this.stage, this.name, this.charKey, this.hp, this.dmg, this.agg, this.speed,
      {this.special});
  final int stage;
  final String name;
  final String charKey;
  final double hp, dmg, agg, speed;
  final Special? special;
}

class ShadowGame extends FlameGame {
  ShadowGame()
      : super(
          camera: CameraComponent.withFixedResolution(width: kW, height: kH),
          world: ArenaWorld(),
        );

  static const overlayTitle = 'title';
  static const overlayMap = 'map';
  static const overlayArmory = 'armory';
  static const overlayResult = 'result';

  /// Villain roster; the infinite map cycles through it with rising tiers.
  static const roster = [
    StageChar('KENJI', 'martial-hero-2'),
    StageChar('RONIN', 'martial-hero-3'),
    StageChar('BRANN', 'hero-knight-2'),
    StageChar('SERAPH', 'huntress-2', special: Special.bleed),
    StageChar('GARRICK', 'medieval-warrior-pack-2'),
    StageChar('THORNE', 'medieval-warrior-pack-3'),
    StageChar('WARBRINGER', 'fantasy-warrior'),
    StageChar('LYRA', 'huntress', special: Special.poison),
    StageChar('ALDRIC', 'hero-knight'),
    StageChar('IGNIS', 'evil-wizard', special: Special.ignite),
    StageChar('KING OSWALD', 'medieval-king-pack'),
    StageChar('KING VARIN', 'medieval-king-pack-2', special: Special.bleed),
    StageChar('ZEPHYR', 'wizard-pack', special: Special.freeze),
    StageChar('MALAKAR', 'evil-wizard-2', special: Special.poison),
  ];

  late final SpriteLibrary sprites;
  final Progress progress = Progress();
  late final Fighter hero;
  VillainFighter? villain;
  late final JoystickComponent joystick;
  late final Announcer announcer;
  late final Hud hud;
  late final GestureTrail trail;
  late final CardBar cardBar;
  late CardDeck deck = CardDeck(const []);
  final List<(double, void Function())> _later = [];
  final Map<Fighter, double> _lastImmune = {};
  double _zoomT = 0;

  Phase phase = Phase.menu;
  double phaseT = 0;
  double t = 0;
  double stageT = 0;
  double timeDilation = 1;
  double _hitStop = 0, _shakeT = 0, _shakeMag = 0;
  int stage = 1;
  int combo = 0;
  double comboT = 0;
  bool lastWin = false;
  Sword? lastUnlocked;
  final _rng = math.Random();
  bool _fightAnnounced = false;

  @override
  Color backgroundColor() => const Color(0xFF06060A);

  @override
  Future<void> onLoad() async {
    sprites = await SpriteLibrary.load(images);
    await progress.load();
    world.add(Backdrop());

    hero = Fighter(
      charName: 'KAITO',
      charKey: 'martial-hero',
      lib: sprites,
      build: sprites.builds['martial-hero'] ?? 1.0,
    );
    hero.resetFor(-180, 78, 1);
    hero.onSwing = (k) {
      if (phase != Phase.fighting) return;
      deck.wear(CardDeck.wearPerMove[k] ?? 0);
      _syncWeapon();
    };
    world.add(hero);

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 21, paint: Paint()..color = const Color(0x8899E8FF)),
      background: CircleComponent(radius: 56, paint: Paint()..color = const Color(0x24FFFFFF)),
      margin: const EdgeInsets.only(left: 34, bottom: 28),
    )..priority = 15;
    announcer = Announcer();
    hud = Hud();
    trail = GestureTrail();
    cardBar = CardBar();
    camera.viewport.addAll([joystick, GestureZone(), hud, cardBar, trail, announcer]);
    _rebuildDeck();
  }

  // ---- Stages -------------------------------------------------------------

  StageCfg stageCfg(int n) {
    final i = (n - 1) % roster.length;
    final tier = (n - 1) ~/ roster.length;
    const suffix = ['', ' II', ' III', ' IV', ' V', ' VI'];
    final c = roster[i];
    return StageCfg(
      n,
      '${c.name}${suffix[math.min(tier, suffix.length - 1)]}',
      c.charKey,
      85 + 7.0 * i + 45.0 * tier,
      0.85 + 0.03 * i + 0.18 * tier,
      0.8 + 0.02 * i + 0.1 * tier,
      0.95 + 0.012 * i + 0.05 * tier,
      special: c.special,
    );
  }

  /// The sword first owned by clearing [n], if any.
  Sword? swordUnlockedByStage(int n) {
    for (final s in Swords.all) {
      if (s.unlockLevel == n) return s;
    }
    return null;
  }

  void _rebuildDeck() {
    deck = CardDeck(Swords.unlockedAt(progress.highestCleared));
    deck.onShatter = (broken, next) {
      announcer.show('${broken.name} SHATTERED',
          sub: next == null ? 'fighting bare-handed' : '${next.name} drawn',
          life: 1.1,
          color: const Color(0xFFFF8B7B));
      _syncWeapon();
    };
    _syncWeapon();
  }

  void _syncWeapon() {
    if (hero.weapon != deck.weapon) hero.setWeapon(deck.weapon);
  }

  void startStage(int n) {
    if (!progress.isUnlocked(n)) return;
    overlays.clear();
    stage = n;
    villain?.removeFromParent();
    final cfg = stageCfg(n);
    final v = VillainFighter(
      name: cfg.name,
      charKey: cfg.charKey,
      lib: sprites,
      build: sprites.builds[cfg.charKey] ?? 1.0,
      weapon: cfg.special == null
          ? Weapon.enemyBlade
          : Weapon(
              id: 'enemy',
              name: 'BLADE',
              strength: 1.0,
              power: 1.1,
              speed: 1.0,
              range: 24,
              trail: const Color(0x88FFFFFF),
              special: cfg.special,
            ),
      maxHealth: cfg.hp,
      aggression: cfg.agg,
      dmgScale: cfg.dmg,
      moveSpeed: cfg.speed,
    );
    villain = v;
    world.add(v);
    v.resetFor(180, 78, -1);
    hero.resetFor(-180, 78, 1);
    hero.hp = hero.maxHp;
    hero.opponent = v;
    v.opponent = hero;
    _rebuildDeck();
    combo = 0;
    comboT = 0;
    stageT = 0;
    hud.resetGhosts();
    lastUnlocked = null;
    phase = Phase.intro;
    phaseT = 0;
    _fightAnnounced = false;
    announcer.show('STAGE $n', sub: cfg.name, life: 1.0);
  }

  void nextStage() => startStage(stage + 1);
  void retryStage() => startStage(stage);

  void showMap() {
    overlays.clear();
    phase = Phase.menu;
    overlays.add(overlayMap);
  }

  void showArmory() {
    overlays.clear();
    overlays.add(overlayArmory);
  }

  void showTitle() {
    overlays.clear();
    phase = Phase.menu;
    overlays.add(overlayTitle);
  }

  // ---- Cards ------------------------------------------------------------------

  /// Tap a card: index -1 is bare hands.
  void equipCard(int index) {
    if (phase != Phase.fighting || !hero.alive) return;
    if (index < 0) {
      deck.unequip();
    } else if (!deck.equip(index)) {
      return;
    }
    _syncWeapon();
  }

  // ---- Loop -----------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    _hitStop = math.max(0, _hitStop - dt);
    timeDilation = _hitStop > 0 ? 0.12 : 1.0;

    if (_shakeT > 0) {
      _shakeT = math.max(0, _shakeT - dt);
      camera.viewfinder.position = Vector2(
        (_rng.nextDouble() * 2 - 1),
        (_rng.nextDouble() * 2 - 1),
      )..scale(_shakeMag * (_shakeT / .25));
    } else {
      camera.viewfinder.position = Vector2.zero();
    }

    if (_zoomT > 0) {
      _zoomT = math.max(0, _zoomT - dt);
      camera.viewfinder.zoom = 1 + 0.06 * (_zoomT / .25);
    } else if (camera.viewfinder.zoom != 1) {
      camera.viewfinder.zoom = 1;
    }
    if (_later.isNotEmpty) {
      final due = _later.where((e) => e.$1 <= t).toList();
      _later.removeWhere((e) => e.$1 <= t);
      for (final (_, f) in due) {
        f();
      }
    }

    comboT = math.max(0, comboT - dt);
    if (comboT == 0) combo = 0;

    phaseT += dt;
    switch (phase) {
      case Phase.menu:
        hero.ix = 0;
        hero.iz = 0;
      case Phase.intro:
        hero.ix = 0;
        hero.iz = 0;
        if (phaseT >= 1.0 && !_fightAnnounced) {
          _fightAnnounced = true;
          announcer.show('FIGHT!', life: .7, color: const Color(0xFFFFD75A));
        }
        if (phaseT >= 1.4) {
          phase = Phase.fighting;
          phaseT = 0;
        }
      case Phase.fighting:
        stageT += dt;
        deck.update(dt);
        final v = villain;
        if (hero.alive) {
          hero.ix = _deadzone(joystick.relativeDelta.x);
          hero.iz = _deadzone(joystick.relativeDelta.y);
        } else {
          hero.ix = 0;
          hero.iz = 0;
        }
        if (v != null && v.alive && hero.alive) {
          if (!hero.attacking) hero.facing = v.wx >= hero.wx ? 1 : -1;
          if (!v.attacking) v.facing = hero.wx >= v.wx ? 1 : -1;
          final dx = v.wx - hero.wx;
          final dz = (v.zPos - hero.zPos).abs();
          if (dx.abs() < 44 && dz < 26) {
            final push = (44 - dx.abs()) / 2;
            final dir = dx >= 0 ? 1 : -1;
            hero.wx = (hero.wx - push * dir).clamp(-kArenaHalf, kArenaHalf);
            v.wx = (v.wx + push * dir).clamp(-kArenaHalf, kArenaHalf);
          }
        }
      case Phase.roundOver:
        hero.ix = 0;
        hero.iz = 0;
        if (phaseT > .7 && hero.alive && hero.state != FState.victory) {
          hero.state = FState.victory;
          hero.stateT = 0;
        }
        if (phaseT >= 2.6) {
          lastWin = true;
          lastUnlocked = swordUnlockedByStage(stage);
          progress.clearStage(stage);
          phase = Phase.menu;
          overlays.add(overlayResult);
        }
      case Phase.gameOver:
        hero.ix = 0;
        hero.iz = 0;
        if (phaseT >= 2.2) {
          lastWin = false;
          lastUnlocked = null;
          phase = Phase.menu;
          overlays.add(overlayResult);
        }
    }
  }

  double _deadzone(double v) => v.abs() < 0.18 ? 0 : v;

  void heroAttack(MoveKind k) {
    if (phase == Phase.fighting && hero.alive) hero.startMove(k);
  }

  /// Run [f] after [delay] seconds of game time.
  void later(double delay, void Function() f) => _later.add((t + delay, f));

  /// A finished finger stroke on the right half of the screen.
  void onStroke(GestureResult r) {
    switch (r.kind) {
      case GestureKind.tap:
        heroAttack(MoveKind.punch);
      case GestureKind.swipeUp:
        heroAttack(MoveKind.kick);
      case GestureKind.swipeDown:
        heroAttack(MoveKind.heavy);
      case GestureKind.swipeLeft:
      case GestureKind.swipeRight:
        heroAttack(MoveKind.slash);
      case GestureKind.glyphV:
        castArt(ArtGesture.v, glyph: r.points);
      case GestureKind.glyphW:
        castArt(ArtGesture.w, glyph: r.points);
    }
  }

  // ---- Sword arts ------------------------------------------------------------

  void castArt(ArtGesture g, {List<Offset>? glyph}) {
    if (phase != Phase.fighting || !hero.alive) return;
    final art = Arts.art(hero.weapon.id, g);
    if (hero.stunned || hero.state == FState.hit) {
      if (glyph != null) trail.flash(glyph, label: 'STAGGERED', ok: false);
      return;
    }
    final cd = deck.artCooldown(g);
    if (cd > 0) {
      if (glyph != null) trail.flash(glyph, label: '${art.name}  ·  ${cd.ceil()}s', ok: false);
      return;
    }
    deck.startArt(g, art.cooldown);
    if (glyph != null) trail.flash(glyph, label: '${art.glyph}  ·  ${art.name}', ok: true);
    _hitStop = math.max(_hitStop, .07);
    _zoomT = .25;
    _executeArt(art);
  }

  bool _inFront(double range, {double dz = 40}) {
    final v = villain;
    if (v == null || !v.alive) return false;
    final dx = (v.wx - hero.wx) * hero.facing;
    return dx > -12 && dx < range && (v.zPos - hero.zPos).abs() < dz;
  }

  void _fire(ProjectileStyle style, double dmg, {double kx = 220, double kup = 0, void Function(Fighter)? onHit}) {
    const hitVfx = {
      ProjectileStyle.crescent: 'hit3',
      ProjectileStyle.fire: 'fire_hit',
      ProjectileStyle.ice: 'ice_hit',
      ProjectileStyle.holy: 'holy_impact',
    };
    world.add(ArtProjectile(
      owner: hero,
      target: villain,
      style: style,
      color: hero.weapon.trail.withValues(alpha: 1),
      dmg: dmg,
      kx: kx,
      kup: kup,
      onHit: onHit,
      hitVfx: hitVfx[style],
    ));
    world.add(SparkBurst(at: Vector2(hero.position.x + hero.facing * 40, hero.position.y - 68),
        palette: [hero.weapon.trail.withValues(alpha: 1), const Color(0xFFFFFFFF)]));
  }

  void _healFx(Fighter f) {
    world.add(SparkBurst(at: Vector2(f.position.x, f.position.y - 70),
        heavy: true, palette: const [Color(0xFF9CFF6B), Color(0xFFE8FFDD)]));
    world.add(VfxAnim('holy_repeat', at: Vector2(f.position.x, f.position.y - 60), scale_: 4,
        tint: const Color(0xFFB8FFA8)));
  }

  void _ghosts(double fromX, double toX, double z, int count) {
    final snap = hero.snapshot();
    for (var k = 0; k < count; k++) {
      final x = fromX + (toX - fromX) * k / count;
      world.add(AfterImage(
        at: Vector2(x, kFloorTop + z),
        sprite: snap.sprite,
        offset: snap.offset,
        size_: snap.size,
        sx: snap.sx,
        sy: snap.sy,
        color: hero.weapon.trail.withValues(alpha: 1),
        pixel: snap.pixel,
        life: .28 + k * .05,
      ));
    }
  }

  void _executeArt(SwordArt art) {
    final v = villain;
    final str = hero.weapon.strength;
    final tint = hero.weapon.trail.withValues(alpha: 1);
    switch (art.kind) {
      case ArtKind.flurry:
        for (var i = 0; i < 3; i++) {
          later(i * .09, () {
            if (_inFront(96)) v!.artHit(hero, 5, kx: 60, kup: i == 2 ? 140 : 0);
          });
        }
      case ArtKind.breathe:
        hero.heal(8);
        _healFx(hero);
      case ArtKind.flashStep:
        final from = hero.wx;
        if (v != null && v.alive) {
          final to = (v.wx + hero.facing * 72).clamp(-kArenaHalf, kArenaHalf);
          _ghosts(from, to, hero.zPos, 4);
          hero.wx = to;
          hero.zPos = v.zPos;
          hero.facing = -hero.facing;
          for (var i = 0; i < 3; i++) {
            later(.04 + i * .08, () {
              if (v.alive) v.artHit(hero, 6 * str, kx: 50, kup: i == 2 ? 180 : 0);
            });
          }
        } else {
          final to = (from + hero.facing * 140).clamp(-kArenaHalf, kArenaHalf);
          _ghosts(from, to, hero.zPos, 4);
          hero.wx = to;
        }
      case ArtKind.secondWind:
        hero.heal(hero.maxHp * .15);
        _healFx(hero);
      case ArtKind.crescentCut:
        _fire(ProjectileStyle.crescent, 18 * str, onHit: (t) => t.addDot(4, 3, Fighter.bleedColor));
      case ArtKind.iaiStance:
        hero.invulnT = 1.5;
        hero.guaranteedCrit = true;
      case ArtKind.earthsplitter:
        world.add(RingWave(at: Vector2(hero.position.x, hero.position.y), color: tint));
        world.add(VfxAnim('earth_impact', at: Vector2(hero.position.x + hero.facing * 60, hero.position.y + 4),
            scale_: 4, bottom: true, additive: false, flipX: hero.facing < 0));
        _shakeT = .3;
        _shakeMag = 12;
        _hitStop = .1;
        if (v != null && v.alive && (v.wx - hero.wx).abs() < 260 && (v.zPos - hero.zPos).abs() < 50) {
          v.artHit(hero, 28 * str, kx: 380, kup: 260, stun: 1.0);
        }
      case ArtKind.ironWill:
        hero.guardT = 5;
      case ArtKind.fireWave:
        _fire(ProjectileStyle.fire, 16 * str, onHit: (t) => t.addDot(6, 4, Fighter.burnColor));
      case ArtKind.blazingAura:
        hero.auraT = 6;
        hero.heal(10);
        _healFx(hero);
      case ArtKind.glacialLance:
        _fire(ProjectileStyle.ice, 14 * str, onHit: (t) => t.slowT = 3.5);
      case ArtKind.iceArmor:
        hero.shieldHp = 30;
        world.add(VfxAnim('ice2_start', at: Vector2(hero.position.x, hero.position.y - 60), scale_: 4.5));
        world.add(SparkBurst(at: Vector2(hero.position.x, hero.position.y - 70),
            palette: const [Color(0xFF9FDBFF), Color(0xFFFFFFFF)]));
      case ArtKind.shadowStrike:
        if (v != null && v.alive) {
          final from = hero.wx;
          final to = (v.wx - v.facing * 46).clamp(-kArenaHalf, kArenaHalf);
          _ghosts(from, to, hero.zPos, 3);
          world.add(VfxAnim('dark_0', at: Vector2(from, hero.position.y - 50), scale_: 4));
          world.add(VfxAnim('dark_1', at: Vector2(to, hero.position.y - 50), scale_: 4));
          hero.wx = to;
          hero.zPos = v.zPos;
          hero.facing = v.facing;
          later(.05, () {
            if (v.alive) v.artHit(hero, 22 * str, kx: 240, crit: true);
          });
        }
      case ArtKind.veil:
        hero.veilT = 3;
        _ghosts(hero.wx, hero.wx, hero.zPos, 1);
        world.add(VfxAnim('dark_0', at: Vector2(hero.position.x, hero.position.y - 50), scale_: 4.5));
      case ArtKind.thunderclap:
        final target = (v != null && v.alive) ? v.position : Vector2(hero.position.x + hero.facing * 140, hero.position.y);
        world.add(LightningBolt(from: Vector2(target.x + 40, target.y - 360), to: Vector2(target.x, target.y - 60), color: tint));
        _shakeT = .3;
        _shakeMag = 9;
        world.add(VfxAnim('thunder_hit', at: Vector2(target.x, target.y - 50), scale_: 5));
        if (v != null && v.alive) v.artHit(hero, 20 * str, kx: 120, stun: 1.2);
      case ArtKind.stormCharge:
        hero.hasteT = 6;
      case ArtKind.toxicFang:
        if (_inFront(110)) {
          v!.artHit(hero, 12 * str, kx: 150);
          v.addDot(5, 7, Fighter.poisonColor);
        }
      case ArtKind.antidote:
        hero.cleanse();
        hero.heal(20);
        _healFx(hero);
      case ArtKind.holyLance:
        _fire(ProjectileStyle.holy, 26 * str, kup: 200);
      case ArtKind.sanctuary:
        hero.invulnT = 3;
        hero.heal(25);
        _healFx(hero);
        world.add(VfxAnim('holy2', at: Vector2(hero.position.x, hero.position.y - 70), scale_: 4));
      case ArtKind.dragonBreath:
        world.add(FireCone(at: Vector2(hero.position.x + hero.facing * 30, hero.position.y - 70), dir: hero.facing));
        final breathAt = Vector2(hero.position.x + hero.facing * 110, hero.position.y - 70);
        world.add(VfxAnim('fire_breath_1', at: breathAt, scale_: 3.5, flipX: hero.facing < 0, loop: true, life: .38));
        later(.38, () => world.add(VfxAnim('fire_breath_2', at: breathAt, scale_: 3.5, flipX: hero.facing < 0)));
        if (v != null && v.alive) {
          world.add(VfxAnim('fire_hit', at: Vector2(v.position.x, v.position.y - 60), scale_: 3.5, flipX: hero.facing < 0));
        }
        _shakeT = .25;
        _shakeMag = 7;
        if (_inFront(220, dz: 60)) {
          v!.artHit(hero, 30 * str, kx: 300, kup: 120);
          v.addDot(8, 4, Fighter.burnColor);
        }
      case ArtKind.draconicRage:
        hero.rageT = 6;
        hero.lifestealT = 6;
    }
  }

  /// A hit bounced off an untouchable fighter.
  void onImmune(Fighter f) {
    if (t - (_lastImmune[f] ?? -1) < .3) return;
    _lastImmune[f] = t;
    world.add(DamagePopup(Vector2(f.position.x, f.position.y - 96), 'IMMUNE'));
    world.add(SparkBurst(at: Vector2(f.position.x, f.position.y - 70), blocked: true));
  }

  // ---- Combat resolution -----------------------------------------------------

  void onStrike(Fighter from, Fighter target, MoveSpec m, double dmg,
      bool blocked, bool killed, bool crit) {
    final cp = Vector2(
      (from.position.x + target.position.x) / 2,
      target.position.y - 74,
    );
    final sp = from.weapon.special;
    final erupt = !blocked && m.heavy && sp == Special.dragonfire;
    world.add(SparkBurst(
        at: cp, heavy: m.heavy || crit, blocked: blocked, ko: killed || erupt));
    if (!blocked) {
      final spark = ['hit1', 'hit2', 'hit3'][_rng.nextInt(3)];
      world.add(VfxAnim(spark, at: cp, scale_: m.heavy || crit ? 3.4 : 2.6, flipX: from.facing < 0));
      if (m.kind == MoveKind.slash && m.duration > 0) {
        world.add(VfxAnim('smear_h', at: cp, scale_: 3, flipX: from.facing < 0, priority: 505));
      }
      world.add(DamagePopup(cp + Vector2(0, -20), dmg.round().toString(),
          big: m.heavy || killed || crit));
      if (crit) {
        world.add(DamagePopup(cp + Vector2(0, -52), 'HEADSHOT!', big: true));
      }
    }
    _hitStop = killed ? .22 : ((m.heavy || crit) ? .09 : .05);
    _shakeT = .25;
    _shakeMag = (blocked ? m.shake * .3 : m.shake) *
        (killed ? 1.6 : (crit ? 1.3 : 1));

    if (from == hero) {
      if (blocked) {
        deck.wear(CardDeck.wearBlocked);
        _syncWeapon();
      } else {
        combo++;
        comboT = 1.5;
      }
    }
    if (!blocked && from.lifestealT > 0 && from.weapon.special != Special.lifesteal) {
      from.heal(dmg * 0.25);
    }

    if (!blocked && sp != null && target.alive) {
      switch (sp) {
        case Special.bleed:
          target.addDot(4, 3, Fighter.bleedColor);
        case Special.poison:
          target.addDot(3, 7, Fighter.poisonColor);
        case Special.ignite:
          if (m.heavy) target.addDot(6, 4, Fighter.burnColor);
        case Special.dragonfire:
          if (m.heavy) target.addDot(8, 4, Fighter.burnColor);
        case Special.freeze:
          if (m.heavy) target.slowT = 3.5;
        case Special.lifesteal:
          from.heal(dmg * 0.25);
        case Special.quickDraw:
        case Special.cleave:
        case Special.shock:
        case Special.radiance:
          break;
      }
    }
    if (killed) onKO(target);
  }

  void onKO(Fighter f) {
    if (phase != Phase.fighting) return;
    if (f == villain) {
      phase = Phase.roundOver;
      phaseT = 0;
      announcer.show('K.O.', life: .9, color: const Color(0xFFFF5A5A));
      announcer.show('VICTORY', life: 1.0, color: const Color(0xFFFFD75A));
    } else {
      phase = Phase.gameOver;
      phaseT = 0;
      announcer.show('K.O.', life: .9, color: const Color(0xFFFF5A5A));
      announcer.show('DEFEAT', life: 1.2, color: const Color(0xFFFF8B7B));
    }
  }
}
