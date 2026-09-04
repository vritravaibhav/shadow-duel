import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'sprites.dart';
import 'weapons.dart';

/// A stick direction relative to the opponent: [fwd] points at them, [back]
/// away. Both sticks read the same eight sectors, so 8 × 8 = 64 combos.
enum Dir {
  up(0, 1, 'up'),
  upFwd(1, 1, 'upfwd'),
  fwd(1, 0, 'fwd'),
  downFwd(1, -1, 'downfwd'),
  down(0, -1, 'down'),
  downBack(-1, -1, 'downback'),
  back(-1, 0, 'back'),
  upBack(-1, 1, 'upback');

  const Dir(this.h, this.v, this.id);

  /// +1 toward the opponent, −1 away, 0 neither.
  final int h;

  /// +1 up, −1 down, 0 level.
  final int v;
  final String id;

  bool get toward => h > 0;
  bool get away => h < 0;

  /// Degrees counter-clockwise from "toward the opponent".
  double get angle {
    final a = math.atan2(v.toDouble(), h.toDouble()) * 180 / math.pi;
    return a < 0 ? a + 360 : a;
  }

  /// The sector a stick delta falls in, or null inside the dead zone.
  /// [facing] mirrors x so pushing at the opponent is always [fwd]. With
  /// [prev], the previous sector is kept until the stick clears its edge by a
  /// margin, so a held stick never flickers between two neighbours.
  static Dir? decode(Vector2 d, int facing, {Dir? prev, double dead = 0.38}) {
    if (d.length < dead) return null;
    final x = d.x * facing, y = -d.y;
    var a = math.atan2(y, x) * 180 / math.pi;
    if (a < 0) a += 360;
    if (prev != null) {
      final diff = ((a - prev.angle + 540) % 360) - 180;
      if (diff.abs() <= 22.5 + 9) return prev;
    }
    const bySector = [
      Dir.fwd, Dir.upFwd, Dir.up, Dir.upBack, Dir.back, Dir.downBack, Dir.down, Dir.downFwd,
    ];
    return bySector[((a + 22.5) % 360 / 45).floor()];
  }

  /// Arrow glyph on screen when the opponent stands to the right.
  String glyph({bool facingRight = true}) {
    final hh = facingRight ? h : -h;
    if (v > 0) return hh > 0 ? '◥' : (hh < 0 ? '◤' : '▲');
    if (v < 0) return hh > 0 ? '◢' : (hh < 0 ? '◣' : '▼');
    return hh > 0 ? '►' : '◄';
  }

  /// Plain words for tutorials: "UP", "TOWARD + DOWN"…
  String get label {
    final parts = <String>[
      if (v > 0) 'UP' else if (v < 0) 'DOWN',
      if (h > 0) 'TOWARD' else if (h < 0) 'AWAY',
    ];
    return parts.join(' + ');
  }

  /// Vector on the stick (screen space, y down) when the opponent is right.
  Offset get vector => Offset(h.toDouble(), -v.toDouble());
}

/// What a left/right pair does. The rule, in the player's words: both sticks
/// at the enemy attack, left away + right at them blocks, both away steps
/// back, and left at them + right away closes in behind the guard.
enum ComboKind {
  attack('ATTACK', Color(0xFFFF8B7B)),
  block('BLOCK', Color(0xFF7DEBFF)),
  stepBack('STEP BACK', Color(0xFFC9D2E8)),
  advance('GUARD ADVANCE', Color(0xFFFFD75A));

  const ComboKind(this.title, this.color);
  final String title;
  final Color color;

  static ComboKind of(Dir left, Dir right) {
    if (left.away) return right.away ? ComboKind.stepBack : ComboKind.block;
    return right.away ? ComboKind.advance : ComboKind.attack;
  }
}

/// One of the 64 two-stick combinations: what it is called, what it does,
/// and how it is animated.
class Combo {
  Combo._(this.left, this.right)
      : kind = ComboKind.of(left, right),
        id = '${left.id}_${right.id}';

  final Dir left, right;
  final ComboKind kind;
  final String id;

  /// Left ▲ + right ▲: the jumping skull smash, unblockable while charged.
  bool get isSmash => left == Dir.up && right == Dir.up;

  /// Attacks: aerial (right ▲), blade (right ◥ ► ◢) or leg (right ▼).
  bool get aerial => kind == ComboKind.attack && right == Dir.up;
  bool get leg => kind == ComboKind.attack && (right == Dir.down || right == Dir.downFwd);
  bool get blade => kind == ComboKind.attack && !aerial && !leg;

  /// The fighter moves toward (+) or away (−) from the enemy.
  bool get lunges => kind == ComboKind.attack && left.toward;

  /// Where an attack lands: the left stick's height picks the zone.
  Zone get zone => switch (left.v) { 1 => Zone.head, -1 => Zone.feet, _ => Zone.body };

  /// What a block, guard-advance or guarded retreat covers: the right stick's
  /// height picks the guard.
  GuardZone get guard {
    if (kind == ComboKind.attack) return GuardZone.none;
    if (kind == ComboKind.stepBack && right.v == 0) return GuardZone.none;
    return switch (right.v) { 1 => GuardZone.high, -1 => GuardZone.low, _ => GuardZone.mid };
  }

  /// Angled blocks (right ◥ / ◢) are parries: they cover only their exact
  /// zone but take no damage and stagger the attacker.
  bool get parry => kind == ComboKind.block && right.h > 0 && right.v != 0;

  /// Damage taken through the guard.
  double get guardFactor => parry ? 0 : (kind == ComboKind.stepBack ? .5 : .25);

  static const _stance = {
    Dir.up: 'HIGH', Dir.upFwd: 'RISING', Dir.fwd: 'LUNGE', Dir.downFwd: 'DIVING', Dir.down: 'LOW',
  };
  static const _method = {
    Dir.up: 'SMASH', Dir.upFwd: 'OVERHEAD', Dir.fwd: 'SLASH', Dir.downFwd: 'SWEEP', Dir.down: 'KICK',
  };
  static const _blockStance = {Dir.upBack: 'SWAY ', Dir.back: '', Dir.downBack: 'CROUCH '};
  static const _blockArm = {
    Dir.up: 'HIGH BLOCK', Dir.upFwd: 'HIGH PARRY', Dir.fwd: 'MID BLOCK',
    Dir.downFwd: 'LOW PARRY', Dir.down: 'LOW BLOCK',
  };
  static const _step = {Dir.upBack: 'HOP BACK', Dir.back: 'STEP BACK', Dir.downBack: 'SLIDE BACK'};
  static const _stepGuard = {Dir.upBack: 'HIGH ', Dir.back: '', Dir.downBack: 'LOW '};
  static const _advMove = {
    Dir.up: 'STANCE', Dir.upFwd: 'HOP IN', Dir.fwd: 'ADVANCE', Dir.downFwd: 'SLIDE IN', Dir.down: 'CROUCH',
  };
  static const _advGuard = {Dir.upBack: 'HIGH GUARD', Dir.back: 'GUARD', Dir.downBack: 'LOW GUARD'};

  String get name {
    switch (kind) {
      case ComboKind.attack:
        if (isSmash) return 'SKULL SMASH';
        if (left == Dir.up && right == Dir.fwd) return 'HEAD CUT';
        if (left == Dir.down && right == Dir.up) return 'STOMP';
        return '${_stance[left]} ${_method[right]}';
      case ComboKind.block:
        return '${_blockStance[left]}${_blockArm[right]}';
      case ComboKind.stepBack:
        return '${_stepGuard[right]}${_step[left]}';
      case ComboKind.advance:
        return '${_advGuard[right]} ${_advMove[left]}';
    }
  }

  static const _stanceDesc = {
    Dir.up: 'Stand tall and aim high',
    Dir.upFwd: 'Spring in and rise',
    Dir.fwd: 'Lunge in',
    Dir.downFwd: 'Dive in low',
    Dir.down: 'Drop low',
  };
  static const _methodDesc = {
    Dir.up: 'leap and smash down',
    Dir.upFwd: 'bring the blade over the top',
    Dir.fwd: 'cut straight through',
    Dir.downFwd: 'sweep the blade low',
    Dir.down: 'drive a kick in',
  };
  static const _leanDesc = {
    Dir.upBack: 'Sway back, standing tall,',
    Dir.back: 'Lean away',
    Dir.downBack: 'Crouch away',
  };
  static const _stepDesc = {
    Dir.upBack: 'Hop back',
    Dir.back: 'Step back',
    Dir.downBack: 'Slide back low',
  };
  static const _advDesc = {
    Dir.up: 'Hold your ground standing tall',
    Dir.upFwd: 'Hop in',
    Dir.fwd: 'Press forward',
    Dir.downFwd: 'Slide in low',
    Dir.down: 'Hold your ground in a crouch',
  };

  String get zoneName => switch (zone) { Zone.head => 'head', Zone.body => 'body', Zone.feet => 'legs' };

  String get guardName => switch (guard) {
        GuardZone.high => parry ? 'head' : 'head and body',
        GuardZone.mid => 'body',
        GuardZone.low => parry ? 'legs' : 'legs and body',
        GuardZone.none => 'nothing',
      };

  String get desc {
    switch (kind) {
      case ComboKind.attack:
        final smash = isSmash ? ' Unblockable while the smash is charged.' : '';
        return '${_stanceDesc[left]}, ${_methodDesc[right]}. Lands on the $zoneName.$smash';
      case ComboKind.block:
        final p = parry
            ? ' A parry: it covers only the $guardName but takes no damage and staggers the attacker.'
            : ' Turns blows to the $guardName for a quarter of the damage.';
        return '${_leanDesc[left]} and raise the guard ${right.v > 0 ? 'high' : (right.v < 0 ? 'low' : 'level')}.$p';
      case ComboKind.stepBack:
        final g = guard == GuardZone.none
            ? ''
            : ' The blade is held ${right.v > 0 ? 'high' : 'low'}: blows to the $guardName do half damage.';
        return '${_stepDesc[left]} away from the enemy.$g';
      case ComboKind.advance:
        return '${_advDesc[left]} with the blade held ${right.v > 0 ? 'high' : (right.v < 0 ? 'low' : 'ready')}: '
            'covers the $guardName while closing in.';
    }
  }

  /// The full 8 × 8 table, left stick major.
  static final List<Combo> all = [
    for (final l in Dir.values)
      for (final r in Dir.values) Combo._(l, r),
  ];

  static final Map<String, Combo> _byId = {for (final c in all) c.id: c};

  static Combo of(Dir left, Dir right) => all[left.index * 8 + right.index];
  static Combo? byId(String id) => _byId[id];
  static Iterable<Combo> ofKind(ComboKind k) => all.where((c) => c.kind == k);

  @override
  String toString() => 'Combo($id $name)';
}

/// The attack numbers of a combo for a given blade. Duration and hit window
/// come from the clip's loop stage, so spamming re-hits once per cycle.
MoveSpec moveFor(Combo c, Weapon w, double loopDur, double winStart, double winEnd, {bool smash = false}) {
  final zone = c.zone;
  final zoneMult = switch (zone) { Zone.head => .9, Zone.feet => .85, Zone.body => 1.0 };
  final lunge = c.lunges ? 1.15 : 1.0;
  final lungeRange = c.lunges ? 10.0 : 0.0;
  final cleave = w.special == Special.cleave ? 1.8 : 1.0;
  final dragon = w.special == Special.dragonfire ? 1.6 : 1.0;
  if (smash) {
    return MoveSpec(MoveKind.heavy, 'heavy', loopDur,
        winStart: winStart, winEnd: winEnd,
        dmg: 16 * w.strength * w.power, range: 48 + w.range * .8 + lungeRange,
        kx: 260 * cleave * dragon, kup: 120 * cleave, shake: 8 * cleave, heavy: true, zone: Zone.head);
  }
  if (c.aerial) {
    return MoveSpec(MoveKind.heavy, 'heavy', loopDur,
        winStart: winStart, winEnd: winEnd,
        dmg: 15 * w.strength * zoneMult * lunge, range: 46 + w.range * .8 + lungeRange,
        kx: 210, kup: 140, shake: 7, zone: zone);
  }
  if (c.right == Dir.upFwd) {
    return MoveSpec(MoveKind.heavy, 'heavy', loopDur,
        winStart: winStart, winEnd: winEnd,
        dmg: 14 * w.strength * zoneMult * lunge, range: 44 + w.range + lungeRange,
        kx: 190, kup: 40, shake: 5, zone: zone);
  }
  if (c.right == Dir.fwd) {
    return MoveSpec(MoveKind.slash, 'slash', loopDur,
        winStart: winStart, winEnd: winEnd,
        dmg: 13 * w.strength * zoneMult * lunge, range: 46 + w.range + lungeRange,
        kx: 170, kup: 0, shake: 4, zone: zone);
  }
  // Legs: a sweep or a kick; at the feet it trips.
  final trip = zone == Zone.feet;
  return MoveSpec(MoveKind.kick, 'kick', loopDur,
      winStart: winStart, winEnd: winEnd,
      dmg: (c.right == Dir.downFwd ? 10.0 : 11.0) * zoneMult * lunge, range: 58 + lungeRange,
      kx: trip ? 130 : 160, kup: trip ? 300 : 0, shake: 3, zone: zone);
}

// ---- Clips ------------------------------------------------------------------

/// One stretch of an animation strip plus the body motion played over it.
/// Every combo's clip is a list of these for its enter, loop and exit stages.
class ClipPhase {
  const ClipPhase(
    this.anim, {
    this.speed = 1,
    this.reverse = false,
    this.from = 0,
    this.to = 1,
    this.cycles = 1,
    this.hop = 0,
    this.dx = 0,
    this.lean = 0,
    this.squash = 1,
    this.hold = 0,
    this.strike = false,
  });

  /// Pack animation name (idle, walk, punch, kick, slash, heavy, hit, jump,
  /// fall, attack3, dash) or a dedicated `combo:<id>:<stage>` strip.
  final String anim;
  final double speed;
  final bool reverse;

  /// Normalised sub-range of the strip; [cycles] repeats looping strips.
  final double from, to;
  final int cycles;

  /// Arc height in game units (the body rises sin(πu)·hop).
  final double hop;

  /// Ground travel over the phase, + toward the opponent.
  final double dx;

  /// Forward lean (skew) and y-squash anchored at the feet (crouch < 1).
  final double lean, squash;

  /// Fixed duration in seconds (0 = strip length / speed).
  final double hold;

  /// The hit window of an attack sits inside this phase.
  final bool strike;

  ClipPhase copyWith({
    String? anim,
    double? speed,
    bool? reverse,
    double? from,
    double? to,
    int? cycles,
    double? hop,
    double? dx,
    double? lean,
    double? squash,
    double? hold,
    bool? strike,
  }) =>
      ClipPhase(
        anim ?? this.anim,
        speed: speed ?? this.speed,
        reverse: reverse ?? this.reverse,
        from: from ?? this.from,
        to: to ?? this.to,
        cycles: cycles ?? this.cycles,
        hop: hop ?? this.hop,
        dx: dx ?? this.dx,
        lean: lean ?? this.lean,
        squash: squash ?? this.squash,
        hold: hold ?? this.hold,
        strike: strike ?? this.strike,
      );

  /// Adds a stance's motion on top of a strike.
  ClipPhase plus({double hop = 0, double dx = 0, double lean = 0, double squash = 1, double speed = 1}) =>
      copyWith(
        hop: this.hop + hop,
        dx: this.dx + dx,
        lean: this.lean + lean,
        squash: this.squash * squash,
        speed: this.speed * speed,
      );

  double duration(SpriteLibrary lib, String ch) {
    if (hold > 0) return hold;
    return lib.animOr(ch, anim).duration * (to - from).abs() * cycles / speed;
  }
}

enum ComboStage { enter, loop, exit }

/// A combo's animation: wind-up, the repeating stroke, and recovery. Two
/// combos never share the same three lists, so switching from any combo to
/// any other plays that pair's own exit-then-enter.
class ComboClip {
  const ComboClip(this.enter, this.loop, this.exit, {this.dedicated = false});
  final List<ClipPhase> enter, loop, exit;

  /// Built from a hand-made strip in assets/images/combos.json rather than
  /// composed from the pack's core animations.
  final bool dedicated;

  List<ClipPhase> stage(ComboStage s) => switch (s) {
        ComboStage.enter => enter,
        ComboStage.loop => loop,
        ComboStage.exit => exit,
      };

  double duration(ComboStage s, SpriteLibrary lib, String ch) =>
      stage(s).fold(0.0, (t, p) => t + p.duration(lib, ch));

  /// The attack window as fractions of the loop stage.
  (double, double) window(SpriteLibrary lib, String ch) {
    final total = duration(ComboStage.loop, lib, ch);
    var before = 0.0;
    for (final p in loop) {
      final d = p.duration(lib, ch);
      if (p.strike) return ((before + d * .42) / total, (before + d * .68) / total);
      before += d;
    }
    return (.42, .68);
  }

  /// The clip for [c] on [ch]: a dedicated strip when one is imported, else
  /// the recipe composed from the pack's own strips.
  static ComboClip forChar(Combo c, SpriteLibrary lib, String ch) {
    if (lib.has(ch, 'combo:${c.id}:loop')) {
      final base = recipe(c);
      ClipPhase ded(String stage, ClipPhase like) => ClipPhase('combo:${c.id}:$stage',
          dx: like.dx, hop: like.hop, hold: 0, strike: like.strike);
      ClipPhase sum(List<ClipPhase> ps, String stage) => ded(stage, ClipPhase('', dx: ps.fold(0.0, (t, p) => t + p.dx),
          hop: ps.fold(0.0, (t, p) => math.max(t, p.hop)), strike: ps.any((p) => p.strike)));
      return ComboClip(
        lib.has(ch, 'combo:${c.id}:enter') ? [sum(base.enter, 'enter')] : base.enter,
        [sum(base.loop, 'loop')],
        lib.has(ch, 'combo:${c.id}:exit') ? [sum(base.exit, 'exit')] : base.exit,
        dedicated: true,
      );
    }
    return recipe(c);
  }

  /// Composes a clip from the pack strips: the left stick shapes the body
  /// (height, travel, crouch, lean), the right stick picks the stroke.
  static ComboClip recipe(Combo c) {
    const quickIn = ClipPhase('idle', from: 0, to: .25, speed: 4);
    const quickOut = ClipPhase('idle', from: .25, to: .5, speed: 4);
    switch (c.kind) {
      case ComboKind.attack:
        return _attack(c);
      case ComboKind.block:
        return _block(c, quickIn, quickOut);
      case ComboKind.stepBack:
        return _stepBack(c, quickIn, quickOut);
      case ComboKind.advance:
        return _advance(c, quickIn, quickOut);
    }
  }

  static ComboClip _attack(Combo c) {
    // Stance (left stick): travel, height and posture, plus its own approach.
    final (hop, dx, lean, squash, speed, List<ClipPhase> enter) = switch (c.left) {
      Dir.up => (6.0, 0.0, .05, 1.05, 1.0, const [ClipPhase('idle', from: 0, to: .25, speed: 4, squash: 1.05)]),
      Dir.upFwd => (22.0, 40.0, .2, 1.0, 1.0, const [ClipPhase('jump', hop: 14, dx: 18, speed: 1.3, lean: .15)]),
      Dir.fwd => (0.0, 55.0, .3, 1.0, 1.05, const [ClipPhase('walk', from: 0, to: .5, speed: 1.6, dx: 26, lean: .2)]),
      Dir.downFwd => (0.0, 48.0, .4, .86, 1.0, const [ClipPhase('walk', from: 0, to: .5, speed: 1.8, dx: 22, squash: .88, lean: .3)]),
      _ => (0.0, 0.0, .1, .88, 1.0, const [ClipPhase('idle', from: 0, to: .25, speed: 4, squash: .9)]),
    };
    // Stroke (right stick).
    final (List<ClipPhase> loop, List<ClipPhase> exit) = switch (c.right) {
      Dir.up => (
          const [ClipPhase('jump', hop: 30, dx: 10, speed: 1.2), ClipPhase('heavy', hop: 52, dx: 8, lean: .2, strike: true)],
          const [ClipPhase('fall', hop: 10, speed: 1.2), ClipPhase('idle', from: 0, to: .2, speed: 3)],
        ),
      Dir.upFwd => (
          const [ClipPhase('heavy', speed: .95, lean: .15, hop: 10, strike: true)],
          const [ClipPhase('idle', from: 0, to: .2, speed: 3)],
        ),
      Dir.fwd => (
          const [ClipPhase('slash', strike: true)],
          const [ClipPhase('idle', from: 0, to: .2, speed: 3)],
        ),
      Dir.downFwd => (
          const [ClipPhase('kick', reverse: true, speed: 1.1, squash: .9, lean: .25, strike: true)],
          const [ClipPhase('idle', from: 0, to: .2, speed: 3, squash: .95)],
        ),
      _ => (
          const [ClipPhase('kick', squash: .96, strike: true)],
          const [ClipPhase('idle', from: 0, to: .2, speed: 3)],
        ),
    };
    return ComboClip(
      enter,
      [for (final p in loop) p.strike ? p.plus(hop: hop, dx: dx, lean: lean, squash: squash, speed: speed) : p],
      exit,
    );
  }

  static ComboClip _block(Combo c, ClipPhase quickIn, ClipPhase quickOut) {
    // The wind-up frames of the pack's attacks double as guard poses, and the
    // pose has to match the zone it covers or the guard cannot be read: the
    // overhead wind-up (kick/slash/heavy) guards high, the low blade across
    // the body (punch) guards low.
    final (String anim, double at) = switch (c.right) {
      Dir.up => ('heavy', .2),
      Dir.upFwd => ('slash', .15),
      Dir.fwd => ('kick', .3),
      Dir.downFwd => ('punch', .2),
      _ => ('punch', .1),
    };
    final (lean, squash) = switch (c.left) {
      Dir.upBack => (-.25, 1.03),
      Dir.downBack => (-.05, .84),
      _ => (-.1, 1.0),
    };
    return ComboClip(
      [ClipPhase(anim, from: 0, to: at, speed: 2.5, lean: lean, squash: squash)],
      [ClipPhase(anim, from: at, to: at, hold: .5, lean: lean, squash: squash)],
      [ClipPhase(anim, from: at, to: 0, speed: 3, lean: lean * .5, squash: 1 + (squash - 1) * .5)],
    );
  }

  static ComboClip _stepBack(Combo c, ClipPhase quickIn, ClipPhase quickOut) {
    final guardLean = c.right.v > 0 ? -.1 : 0.0;
    final guardSquash = c.right.v < 0 ? .95 : 1.0;
    final List<ClipPhase> loop = switch (c.left) {
      Dir.upBack => [
          ClipPhase('jump', hop: 26, dx: -36, speed: 1.3, lean: -.15 + guardLean, squash: guardSquash),
          ClipPhase('fall', hop: 14, dx: -34, speed: 1.3, lean: -.1 + guardLean, squash: guardSquash),
        ],
      Dir.downBack => [
          ClipPhase('walk', reverse: true, dx: -56, speed: 1.2, squash: .84 * guardSquash, lean: -.25 + guardLean),
        ],
      _ => [ClipPhase('walk', reverse: true, dx: -46, speed: 1.1, lean: -.12 + guardLean, squash: guardSquash)],
    };
    return ComboClip(
      [quickIn.copyWith(lean: -.15 + guardLean, squash: guardSquash)],
      loop,
      [quickOut.copyWith(lean: -.05)],
    );
  }

  static ComboClip _advance(Combo c, ClipPhase quickIn, ClipPhase quickOut) {
    final guardLean = c.right.v > 0 ? .05 : 0.0;
    final guardSquash = c.right.v < 0 ? .95 : 1.0;
    final List<ClipPhase> loop = switch (c.left) {
      Dir.up => [ClipPhase('idle', squash: 1.05 * guardSquash, lean: .05 + guardLean)],
      Dir.upFwd => [
          ClipPhase('jump', hop: 24, dx: 30, lean: .1 + guardLean, squash: guardSquash),
          ClipPhase('fall', hop: 10, dx: 26, lean: .1 + guardLean, squash: guardSquash),
        ],
      Dir.fwd => [ClipPhase('walk', dx: 44, lean: .12 + guardLean, squash: guardSquash)],
      Dir.downFwd => [ClipPhase('walk', dx: 50, speed: 1.2, squash: .84 * guardSquash, lean: .28 + guardLean)],
      _ => [ClipPhase('idle', squash: .86 * guardSquash, lean: .08 + guardLean)],
    };
    return ComboClip(
      [quickIn.copyWith(lean: .1 + guardLean, squash: guardSquash)],
      loop,
      [quickOut],
    );
  }
}

/// What the renderer needs for one frame of a combo.
class ComboSample {
  const ComboSample(this.anim, this.frame, this.hop, this.lean, this.squash, {this.name = 'idle'});
  final BakedAnim anim;
  final int frame;
  final double hop, lean, squash;

  /// The pack strip [anim] was read from.
  final String name;
}

/// Something the player did this tick that the fighter must react to.
enum ComboEvent { none, cycle, finished }

/// Plays a [ComboClip]: enter once, loop while held (every cycle is a new
/// swing), exit when released or replaced. Used by the fighter in battle and
/// by the dojo preview, so both show exactly the same motion.
class ComboPlayer {
  ComboPlayer(this.lib, this.charKey);

  final SpriteLibrary lib;
  final String charKey;

  Combo? combo;
  ComboClip? clip;
  ComboStage stage = ComboStage.enter;
  double t = 0;
  int cycles = 0;
  bool released = false;
  Combo? next;

  /// Current body motion, updated by [advance].
  double dxRate = 0, hop = 0, lean = 0, squash = 1;
  double _lean0 = 0, _squash0 = 1;
  int _phaseIndex = -1;

  bool get active => combo != null;
  bool get exiting => stage == ComboStage.exit;

  /// Seconds the current stage lasts.
  double get stageDuration => clip!.duration(stage, lib, charKey);

  /// Progress through the current stage, 0..1.
  double get stageU => stageDuration <= 0 ? 1 : (t / stageDuration).clamp(0.0, 1.0);

  void start(Combo c) {
    combo = c;
    clip = ComboClip.forChar(c, lib, charKey);
    stage = ComboStage.enter;
    t = 0;
    cycles = 0;
    released = false;
    next = null;
    _lean0 = lean;
    _squash0 = squash;
    _phaseIndex = -1;
    if (stageDuration <= 0) _enterLoop();
  }

  void stop() {
    combo = null;
    clip = null;
    dxRate = 0;
    hop = 0;
    lean = 0;
    squash = 1;
    next = null;
  }

  /// The stick was released (attacks finish their swing first) or moved to
  /// another combo (queued behind this one's exit).
  void release({Combo? to, bool now = false}) {
    if (combo == null) return;
    next = to;
    released = true;
    if (now && stage != ComboStage.exit) _exit();
  }

  void _enterLoop() {
    stage = ComboStage.loop;
    t = 0;
    _phaseIndex = -1;
  }

  void _exit() {
    stage = ComboStage.exit;
    t = 0;
    _phaseIndex = -1;
    _lean0 = lean;
    _squash0 = squash;
  }

  /// Advances the clock and reports a new swing cycle or the end of the clip.
  ComboEvent advance(double dt) {
    if (combo == null) return ComboEvent.none;
    var event = ComboEvent.none;
    t += dt;
    var dur = stageDuration;
    // Stage boundaries (a stage may be empty or shorter than dt).
    for (var guard = 0; guard < 4 && t >= dur; guard++) {
      switch (stage) {
        case ComboStage.enter:
          t -= dur;
          _enterLoop();
          event = ComboEvent.cycle;
        case ComboStage.loop:
          cycles++;
          if (released) {
            _exit();
          } else {
            t -= dur;
            _phaseIndex = -1;
            event = ComboEvent.cycle;
          }
        case ComboStage.exit:
          final n = next;
          if (n != null) {
            start(n);
            _sampleMotion();
            return stage == ComboStage.loop ? ComboEvent.cycle : ComboEvent.none;
          }
          stop();
          return ComboEvent.finished;
      }
      dur = stageDuration;
    }
    _sampleMotion();
    return event;
  }

  /// Locates the phase under the clock and derives the body motion.
  (ClipPhase, double, double) _locate() {
    final phases = clip!.stage(stage);
    var before = 0.0;
    for (var i = 0; i < phases.length; i++) {
      final p = phases[i];
      final d = p.duration(lib, charKey);
      if (t < before + d || i == phases.length - 1) {
        if (i != _phaseIndex) {
          _phaseIndex = i;
          _lean0 = lean;
          _squash0 = squash;
        }
        final u = d <= 0 ? 1.0 : ((t - before) / d).clamp(0.0, 1.0);
        return (p, u, d);
      }
      before += d;
    }
    return (const ClipPhase('idle'), 1, 1);
  }

  void _sampleMotion() {
    final (p, u, d) = _locate();
    // Travel follows a bell so the body eases in and out; it integrates to dx.
    dxRate = d <= 0 ? 0 : p.dx * 6 * u * (1 - u) / d;
    hop = p.hop * math.sin(math.pi * u);
    final blend = (u / .3).clamp(0.0, 1.0);
    lean = _lean0 + (p.lean - _lean0) * blend;
    squash = _squash0 + (p.squash - _squash0) * blend;
  }

  /// The frame to draw right now.
  ComboSample sample() {
    final (p, u, _) = _locate();
    final ba = lib.animOr(charKey, p.anim);
    final int frame;
    if (p.hold > 0 && p.from == p.to) {
      frame = ba.frameAt(p.from);
    } else if (ba.loop) {
      frame = ba.frameAt(u * p.cycles, reverse: p.reverse);
    } else {
      final v = p.reverse ? p.to + (p.from - p.to) * u : p.from + (p.to - p.from) * u;
      frame = ba.frameAt(v);
    }
    return ComboSample(ba, frame, hop, lean, squash, name: p.anim);
  }

  /// Whether the clock sits inside the attack window of the loop stage.
  bool inWindow(double winStart, double winEnd, {double before = 0, double after = 0}) {
    if (stage != ComboStage.loop) return false;
    final u = stageU;
    return u >= winStart - before && u <= winEnd + after;
  }
}
