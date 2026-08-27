import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'background.dart';
import 'cards.dart';
import 'effects.dart';
import 'fighter.dart';
import 'hud.dart';
import 'progress.dart';
import 'sprites.dart';
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
  const StageChar(this.name, this.charKey);
  final String name;
  final String charKey;
}

class StageCfg {
  const StageCfg(this.stage, this.name, this.charKey, this.hp, this.dmg, this.agg, this.speed);
  final int stage;
  final String name;
  final String charKey;
  final double hp, dmg, agg, speed;
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
    StageChar('SERAPH', 'huntress-2'),
    StageChar('GARRICK', 'medieval-warrior-pack-2'),
    StageChar('THORNE', 'medieval-warrior-pack-3'),
    StageChar('WARBRINGER', 'fantasy-warrior'),
    StageChar('LYRA', 'huntress'),
    StageChar('ALDRIC', 'hero-knight'),
    StageChar('IGNIS', 'evil-wizard'),
    StageChar('KING OSWALD', 'medieval-king-pack'),
    StageChar('KING VARIN', 'medieval-king-pack-2'),
    StageChar('ZEPHYR', 'wizard-pack'),
    StageChar('MALAKAR', 'evil-wizard-2'),
  ];

  late final SpriteLibrary sprites;
  final Progress progress = Progress();
  late final Fighter hero;
  VillainFighter? villain;
  late final JoystickComponent joystick;
  late final Announcer announcer;
  late final Hud hud;
  late CardDeck deck = CardDeck(const []);

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
    camera.viewport.addAll([joystick, GestureZone(), hud, CardBar(), announcer]);
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
      weapon: Weapon.enemyBlade,
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
