import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/painting.dart';

import 'arts.dart';
import 'background.dart';
import 'cards.dart';
import 'combos.dart';
import 'effects.dart';
import 'fighter.dart';
import 'gesture_fx.dart';
import 'gestures.dart';
import 'hud.dart';
import 'projectile.dart';
import 'progress.dart';
import 'sfx.dart';
import 'sprites.dart';
import 'tutorial.dart';
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
  static const overlayPause = 'pause';
  static const overlayDojo = 'dojo';

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
  late final AttackStick attackStick;

  /// What each stick holds this frame (relative to the enemy) and the combo
  /// the pair spells, for the HUD.
  Dir? leftDir, rightDir;
  Combo? heldCombo;

  /// Stand-ins for the sticks, so tests can hold combos the way a thumb does.
  @visibleForTesting
  Vector2? leftStickOverride, rightStickOverride;
  Vector2 get _leftStick => leftStickOverride ?? joystick.relativeDelta;
  Vector2 get _rightStick => rightStickOverride ?? attackStick.relativeDelta;

  /// Sparring in the dojo: the tutorial being practised, if any.
  Practice? practice;
  double _dummyT = 0;
  double _heroPrevX = 0;

  /// The skull smash is unblockable, so it rests between uses.
  static const smashRecharge = 6.0;
  double smashCd = 0;

  /// A card tapped mid-swing is drawn when the swing finishes.
  int? _pendingCard;
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

  /// Battle frozen by the pause button (world frozen, HUD still drawn).
  bool battlePaused = false;

  /// Chase-the-stars scoring, recomputed each stage.
  int stageMaxCombo = 0;
  int lastStars = 0;
  bool lastNewStars = false, lastNewCombo = false;
  double lastHpFrac = 0;
  final _rng = math.Random();
  bool _fightAnnounced = false;

  @override
  Color backgroundColor() => const Color(0xFF06060A);

  @override
  Future<void> onLoad() async {
    sprites = await SpriteLibrary.load(images);
    await progress.load();
    await Sfx.init();
    Sfx.music('menu');
    world.add(Backdrop());

    hero = Fighter(
      charName: 'KAITO',
      charKey: 'martial-hero',
      lib: sprites,
      build: sprites.builds['martial-hero'] ?? 1.0,
    );
    hero.resetFor(-180, 78, 1);
    hero.onSwing = (k) => Sfx.swing(heavy: k == MoveKind.heavy);
    hero.onComboCycle = _onHeroCycle;
    world.add(hero);

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 21, paint: Paint()..color = const Color(0x8899E8FF)),
      background: CircleComponent(radius: 56, paint: Paint()..color = const Color(0x24FFFFFF)),
      margin: const EdgeInsets.only(left: 34, bottom: 28),
    )..priority = 15;
    attackStick = AttackStick(
      onTap: () => heroAttack(MoveKind.punch),
      knob: CircleComponent(radius: 21, paint: Paint()..color = const Color(0x99FF8B7B)),
      background: CircleComponent(radius: 56, paint: Paint()..color = const Color(0x24FFFFFF)),
      margin: const EdgeInsets.only(right: 34, bottom: 28),
    )..priority = 15;
    announcer = Announcer();
    hud = Hud();
    trail = GestureTrail();
    cardBar = CardBar();
    camera.viewport.addAll([
      joystick,
      attackStick,
      GestureZone(),
      hud,
      cardBar,
      GuardMarkers(),
      PauseButton(),
      trail,
      announcer,
    ]);
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
    deck.onSpent = (spent, next) {
      Sfx.play('spent');
      announcer.show('${spent.name} SPENT',
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
    v.onSwing = (k) => Sfx.swing(heavy: k == MoveKind.heavy);
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
    practice = null;
    leftDir = rightDir = null;
    heldCombo = null;
    smashCd = 0;
    _pendingCard = null;
    battlePaused = false;
    stageMaxCombo = 0;
    overlays.remove(overlayPause);
    announcer.show('STAGE $n', sub: cfg.name, life: 1.0);
    Sfx.play('stage');
    Sfx.music('battle');
  }

  void nextStage() => startStage(stage + 1);
  void retryStage() => startStage(stage);

  void showMap() {
    overlays.clear();
    battlePaused = false;
    phase = Phase.menu;
    overlays.add(overlayMap);
    Sfx.music('menu');
  }

  /// Freeze the fight and raise the pause menu.
  void pauseFight() {
    if (phase != Phase.fighting || battlePaused) return;
    battlePaused = true;
    timeDilation = 0; // freeze immediately, not on the next frame
    Sfx.play('click', volume: .6);
    overlays.add(overlayPause);
  }

  void resumeFight() {
    if (!battlePaused) return;
    battlePaused = false;
    overlays.remove(overlayPause);
    Sfx.play('click', volume: .6);
  }

  /// Leave the battle and go back to the map. The stage is not cleared.
  /// Sparring returns to the dojo instead.
  void quitToMap() {
    battlePaused = false;
    villain?.removeFromParent();
    villain = null;
    hero.resetFor(-180, 78, 1);
    if (practice != null) {
      practice = null;
      showDojo();
      return;
    }
    showMap();
  }

  /// The combo library and tutorial.
  void showDojo() {
    overlays.clear();
    battlePaused = false;
    phase = Phase.menu;
    overlays.add(overlayDojo);
    Sfx.music('menu');
  }

  bool get practising => practice != null;

  // ---- Dojo sparring ------------------------------------------------------

  /// Spar against a dummy that never dies, starting at tutorial [lesson].
  void startPractice(int lesson) {
    overlays.clear();
    villain?.removeFromParent();
    final v = VillainFighter(
      name: 'DUMMY',
      charKey: 'martial-hero-2',
      lib: sprites,
      build: sprites.builds['martial-hero-2'] ?? 1.0,
      weapon: Weapon.enemyBlade,
      maxHealth: 9999,
      aggression: 1,
      dmgScale: .08,
    )..dummy = true;
    v.onSwing = (k) => Sfx.swing(heavy: k == MoveKind.heavy);
    villain = v;
    world.add(v);
    v.resetFor(120, 78, -1);
    hero.resetFor(-120, 78, 1);
    hero.hp = hero.maxHp;
    hero.opponent = v;
    v.opponent = hero;
    _rebuildDeck();
    combo = 0;
    comboT = 0;
    stageT = 0;
    hud.resetGhosts();
    lastUnlocked = null;
    practice = Practice(index: lesson.clamp(0, Lesson.all.length - 1));
    _dummyT = 1.2;
    _heroPrevX = hero.wx;
    phase = Phase.intro;
    phaseT = 0;
    _fightAnnounced = true;
    smashCd = 0;
    _pendingCard = null;
    battlePaused = false;
    stageMaxCombo = 0;
    leftDir = rightDir = null;
    heldCombo = null;
    overlays.remove(overlayPause);
    announcer.show('DOJO', sub: 'lesson ${lesson + 1}  ·  ${practice!.lesson.title}', life: 1.0);
    Sfx.play('stage');
    Sfx.music('battle');
  }

  void _beginLesson() {
    final p = practice!;
    final v = villain!;
    hero.hp = hero.maxHp;
    v.guardZone = GuardZone.none;
    _dummyT = 1.2;
    announcer.show('LESSON ${p.index + 1}', sub: p.lesson.title, life: 1.0);
  }

  void _updatePractice(double dt) {
    final p = practice!;
    final v = villain;
    if (v == null || p.finished) return;
    if (p.lessonDone) {
      p.doneT += dt;
      if (p.doneT > 1.5) {
        p.nextLesson();
        if (p.finished) {
          announcer.show('DOJO COMPLETE', sub: 'every combo is yours', life: 2.0, color: const Color(0xFFFFD75A));
          Sfx.play('win');
          later(2.4, () {
            if (practice != null) quitToMap();
          });
        } else {
          _beginLesson();
        }
      }
      return;
    }
    final lesson = p.lesson;
    if (lesson.goal == LessonGoal.walk) {
      if (hero.state == FState.walk) p.walked += (hero.wx - _heroPrevX).abs();
      if (p.walked >= 70) {
        p.walked -= 70;
        _practiceScore();
      }
    }
    _heroPrevX = hero.wx;

    // The dummy keeps its health and plays its part.
    v.hp = v.maxHp;
    switch (lesson.dummy) {
      case DummyMode.still:
        v.guardZone = GuardZone.none;
      case DummyMode.guards:
        _dummyT -= dt;
        if (_dummyT <= 0) {
          _dummyT = 2.4;
          v.guardZone = v.guardZone == GuardZone.high ? GuardZone.low : GuardZone.high;
        }
      case DummyMode.attacks:
        v.guardZone = GuardZone.none;
        _dummyT -= dt;
        final near = (hero.wx - v.wx).abs() < v.moves[MoveKind.punch]!.range + 40 &&
            (hero.zPos - v.zPos).abs() < 30;
        if (_dummyT <= 0 && near && !v.attacking && !v.windingUp && v.state != FState.hit) {
          _dummyT = 1.9;
          const kinds = [MoveKind.high, MoveKind.punch, MoveKind.kick];
          v.windUp(kinds[_rng.nextInt(kinds.length)], .6);
        }
    }
  }

  void _practiceScore() {
    final p = practice!;
    if (p.lessonDone) return;
    if (p.score()) {
      announcer.show('${p.lesson.title}  ✓', life: .9, color: const Color(0xFF9CFF6B));
      Sfx.play('heal', volume: .7);
    } else {
      Sfx.play('click', volume: .5);
    }
  }

  void _practiceStrike(Fighter from, MoveSpec m, bool blocked, bool parried) {
    final p = practice!;
    if (p.lessonDone) return;
    if (from == hero) {
      switch (p.lesson.goal) {
        case LessonGoal.hit:
        case LessonGoal.openHit:
          if (!blocked) _practiceScore();
        case LessonGoal.strokes:
          if (!blocked && p.strokes.add(strokeFamily(m))) _practiceScore();
        case LessonGoal.smash:
          if (m.heavy && !blocked) _practiceScore();
        default:
          break;
      }
    } else {
      switch (p.lesson.goal) {
        case LessonGoal.block:
          if (blocked && !parried) _practiceScore();
        case LessonGoal.parry:
          if (parried) _practiceScore();
        default:
          break;
      }
    }
  }

  /// A new cycle of the hero's held combo: the smash spends its charge, and
  /// the dojo counts steps.
  void _onHeroCycle(Combo c, bool smash) {
    if (smash) smashCd = smashRecharge;
    final p = practice;
    if (p == null || p.lessonDone) return;
    if (p.lesson.goal == LessonGoal.stepBack && c.kind == ComboKind.stepBack) _practiceScore();
    if (p.lesson.goal == LessonGoal.advance && c.kind == ComboKind.advance) _practiceScore();
  }

  /// Three stars: win, keep at least half your health, and land an 8-hit combo.
  int _starsEarned() {
    var n = 1;
    if (hero.hp / hero.maxHp >= .5) n++;
    if (stageMaxCombo >= 8) n++;
    return n;
  }

  void _score() {
    lastHpFrac = (hero.hp / hero.maxHp).clamp(0.0, 1.0);
    lastStars = _starsEarned();
    progress.clearStage(stage, lastStars).then((better) => lastNewStars = better);
    progress.recordCombo(stageMaxCombo).then((best) => lastNewCombo = best);
  }

  void showArmory() {
    overlays.clear();
    overlays.add(overlayArmory);
  }

  void showTitle() {
    overlays.clear();
    phase = Phase.menu;
    overlays.add(overlayTitle);
    Sfx.music('menu');
  }

  // ---- Cards ------------------------------------------------------------------

  /// Tap a card: index -1 is bare hands.
  void equipCard(int index) {
    if (phase != Phase.fighting || !hero.alive) return;
    // Swapping mid-swing would finish the blow with another blade's effects.
    if (hero.attacking) {
      _pendingCard = index;
      Sfx.play('click', volume: .5);
      return;
    }
    _applyCard(index);
  }

  void _applyCard(int index) {
    if (index < 0) {
      deck.unequip();
    } else if (!deck.equip(index)) {
      return;
    }
    Sfx.play('card', volume: .8);
    _syncWeapon();
  }

  // ---- Loop -----------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    t += dt;
    _hitStop = math.max(0, _hitStop - dt);
    if (battlePaused) {
      timeDilation = 0;
      return;
    }
    // Time thickens when either fighter is one hit from going down.
    final desperate = phase == Phase.fighting &&
        hero.alive &&
        (villain?.alive ?? false) &&
        (hero.hp / hero.maxHp < .2 || (villain!.hp / villain!.maxHp) < .12);
    timeDilation = _hitStop > 0 ? 0.12 : (desperate ? 0.86 : 1.0);

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
    smashCd = math.max(0, smashCd - dt);
    if (_pendingCard != null && !hero.attacking) {
      final i = _pendingCard!;
      _pendingCard = null;
      _applyCard(i);
    }

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
          _pollSticks();
        } else {
          hero.ix = 0;
          hero.iz = 0;
          hero.guardZone = GuardZone.none;
        }
        if (practice != null) _updatePractice(dt);
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
        hero.holdCombo(null);
        if (phaseT > .7 && hero.alive && hero.state != FState.victory) {
          hero.state = FState.victory;
          hero.stateT = 0;
        }
        if (phaseT >= 2.6) {
          lastWin = true;
          lastUnlocked = swordUnlockedByStage(stage);
          _score();
          phase = Phase.menu;
          overlays.add(overlayResult);
          Sfx.play('win');
          Sfx.music('menu');
        }
      case Phase.gameOver:
        hero.ix = 0;
        hero.iz = 0;
        if (phaseT >= 2.2) {
          lastWin = false;
          lastUnlocked = null;
          lastStars = 0;
          lastNewStars = false;
          lastHpFrac = 0;
          lastNewCombo = false;
          phase = Phase.menu;
          overlays.add(overlayResult);
          Sfx.play('lose');
          Sfx.music('menu');
        }
    }
  }

  double _deadzone(double v) => v.abs() < 0.18 ? 0 : v;

  /// Two held sticks spell a combo (see combos.dart); the left stick alone
  /// walks. Sectors are read relative to the enemy, so "toward" is always
  /// the same combo whichever side the hero stands on.
  void _pollSticks() {
    final face = hero.facing;
    final ls = _leftStick, rs = _rightStick;
    leftDir = Dir.decode(ls, face, prev: leftDir);
    rightDir = Dir.decode(rs, face, prev: rightDir);
    hero.smashArmed = smashCd <= 0;
    final l = leftDir, r = rightDir;
    if (l != null && r != null) {
      heldCombo = Combo.of(l, r);
      hero.holdCombo(heldCombo);
      hero.ix = 0;
      hero.iz = 0;
    } else {
      heldCombo = null;
      hero.holdCombo(null);
      hero.ix = _deadzone(ls.x);
      hero.iz = _deadzone(ls.y);
    }
    // Guards only come from held combos; the fighter owns them while in one.
    if (hero.state != FState.combo) hero.guardZone = GuardZone.none;
  }

  Rect _bounds(List<Offset> pts) {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (final p in pts) {
      l = math.min(l, p.dx);
      r = math.max(r, p.dx);
      t = math.min(t, p.dy);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

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
        castArt(ArtGesture.v, glyph: _bounds(r.points));
      case GestureKind.glyphW:
        castArt(ArtGesture.w, glyph: _bounds(r.points));
    }
  }

  // ---- Sword arts ------------------------------------------------------------

  void castArt(ArtGesture g, {Rect? glyph}) {
    if (phase != Phase.fighting || !hero.alive) return;
    final art = Arts.art(hero.weapon.id, g);
    final kind = g == ArtGesture.v ? GestureKind.glyphV : GestureKind.glyphW;
    if (hero.stunned || hero.state == FState.hit) {
      if (glyph != null) trail.flash(kind, glyph, label: 'STAGGERED', ok: false);
      return;
    }
    final cd = deck.artCooldown(g);
    if (cd > 0) {
      if (glyph != null) trail.flash(kind, glyph, label: '${art.name}  ·  ${cd.ceil()}s', ok: false);
      Sfx.play('immune', volume: .4);
      return;
    }
    deck.startArt(g, art.cooldown);
    if (glyph != null) trail.flash(kind, glyph, label: '${art.glyph}  ·  ${art.name}', ok: true);
    _hitStop = math.max(_hitStop, .07);
    _zoomT = .25;
    Sfx.play('cast', volume: .8);
    Sfx.play(_artSound(art.kind), volume: .9);
    _executeArt(art);
  }

  String _artSound(ArtKind k) => switch (k) {
        ArtKind.thunderclap || ArtKind.stormCharge => 'thunder',
        ArtKind.fireWave || ArtKind.blazingAura || ArtKind.dragonBreath || ArtKind.draconicRage => 'fire',
        ArtKind.glacialLance || ArtKind.iceArmor => 'ice',
        ArtKind.holyLance || ArtKind.sanctuary => 'holy',
        ArtKind.shadowStrike || ArtKind.veil => 'dark',
        ArtKind.breathe || ArtKind.secondWind || ArtKind.antidote => 'heal',
        ArtKind.ironWill => 'shield',
        ArtKind.flashStep || ArtKind.flurry => 'dash',
        _ => 'cast',
      };

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
    Sfx.play('immune', volume: .6);
  }

  // ---- Combat resolution -----------------------------------------------------

  void onStrike(Fighter from, Fighter target, MoveSpec m, double dmg,
      bool blocked, bool killed, bool crit, {bool parried = false}) {
    final cp = Vector2(
      (from.position.x + target.position.x) / 2,
      target.position.y - 74,
    );
    if (practice != null) _practiceStrike(from, m, blocked, parried);
    final sp = from.weapon.special;
    final erupt = !blocked && m.heavy && sp == Special.dragonfire;
    world.add(SparkBurst(
        at: cp, heavy: m.heavy || crit || parried, blocked: blocked, ko: killed || erupt));
    if (parried) {
      world.add(DamagePopup(cp + Vector2(0, -24), 'PARRY!', big: true));
      world.add(VfxAnim('hit3', at: cp, scale_: 3, flipX: from.facing < 0));
      _hitStop = math.max(_hitStop, .08);
      _shakeT = .25;
      _shakeMag = 5;
      Sfx.play('shield', volume: .9);
      Sfx.play('block', volume: .6);
      return;
    }
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

    if (from == hero && !blocked) {
      combo++;
      comboT = 1.5;
      if (combo > stageMaxCombo) stageMaxCombo = combo;
    }
    if (killed) {
      Sfx.play('ko');
    } else if (blocked) {
      Sfx.play('block', volume: .8);
    } else if (crit) {
      Sfx.play('crit');
    } else if (m.heavy) {
      Sfx.play('hit_heavy');
    } else {
      Sfx.one(const ['hit1', 'hit2'], volume: .9);
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
    if (practice != null) {
      // Nobody goes down in the dojo.
      f.hp = f.maxHp;
      f.state = FState.idle;
      f.stateT = 0;
      return;
    }
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
