import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'combos.dart';
import 'shadow_game.dart';
import 'sprites.dart';
import 'weapons.dart';

export 'weapons.dart' show GuardZone;

/// [combo] is a held two-stick combination (see combos.dart): attacks loop a
/// swing per cycle while held, blocks and steps hold their pose.
enum FState { idle, walk, attack, combo, hit, dead, victory }

/// A damage-over-time effect (bleed, burn, poison).
class Dot {
  Dot(this.dps, this.left, this.color);
  final double dps;
  double left;
  final Color color;
}

/// A fighter rendered from the imported sprite packs in assets/images/packs/.
class Fighter extends PositionComponent with HasGameReference<ShadowGame> {
  Fighter({
    required this.charName,
    required this.charKey,
    required this.lib,
    this.build = 1.0,
    Weapon startWeapon = Weapon.fists,
    this.dmgScale = 1.0,
    double maxHealth = 100,
  })  : weapon = startWeapon,
        maxHp = maxHealth,
        hp = maxHealth {
    moves = buildMoves(weapon, lib, charKey);
  }

  final String charName;
  final String charKey;
  final SpriteLibrary lib;
  final double build;
  double dmgScale;

  Weapon weapon;
  late Map<MoveKind, MoveSpec> moves;
  double maxHp;
  double hp;

  /// Both fighters share one lane: [wx] is the only free axis, [zPos] is
  /// pinned to [kLaneZ] and kept only for depth-scaling and old call sites.
  double wx = 0, zPos = kLaneZ;
  double h = 0, vh = 0, kvx = 0;
  double ix = 0, iz = 0;
  int facing = 1;
  double speedMult = 1.0;

  /// Horizontal velocity carried through a jump (no steering mid-air).
  double _airVx = 0;
  bool _jumping = false;

  /// Seconds left of the landing squash.
  double landT = 0;

  static const jumpSpeed = 760.0, gravity = 1600.0;

  bool get airborne => h > 0 || vh != 0;
  bool get jumping => _jumping;

  /// Fired on take-off and on landing (dust, sound).
  void Function()? onJump, onLand;

  /// What each stick holds (relative to the enemy) and the combo the pair
  /// spells; filled by [applySticks] for the HUD.
  Dir? leftDir, rightDir;
  Combo? heldCombo;
  bool _jumpHeld = false;

  /// A puppet is drawn from a network snapshot: no physics, no state
  /// machine, just the frame the authority says it is on (see netplay).
  bool puppet = false;
  String puppetAnim = 'idle';
  int puppetFrame = 0;
  double puppetLean = 0, puppetSquash = 1;

  /// The pack strip and frame drawn right now, for snapshots.
  (String, int) animFrame() => _sampleNamed();

  FState state = FState.idle;
  double stateT = 0;
  MoveSpec? currentMove;
  MoveKind? pendingKind;
  bool hitApplied = false;
  double flashT = 0, blockFlashT = 0;

  /// The held two-stick combo, its clip clock and this cycle's attack.
  late final ComboPlayer comboPlayer = ComboPlayer(lib, charKey);
  MoveSpec? comboMove;

  /// Set by the game each frame: a skull smash started now is unblockable.
  bool smashArmed = false;

  /// Fired at the start of every combo cycle (a swing, a held block, a step).
  void Function(Combo combo, bool smash)? onComboCycle;

  /// A parry covers only its exact zone but takes nothing and staggers the
  /// attacker; [guardFactor] is the damage let through by a plain block.
  bool parrying = false;
  double guardFactor = .25;

  // Status effects.
  final List<Dot> dots = [];
  double slowT = 0;
  double stunMult = 1;

  // Sword-art buffs and debuffs (seconds remaining / points).
  double invulnT = 0, veilT = 0, guardT = 0, rageT = 0, hasteT = 0, auraT = 0, lifestealT = 0;
  double shieldHp = 0;
  double stunT = 0;
  bool guaranteedCrit = false;

  bool get untouchable => invulnT > 0 || veilT > 0;
  bool get stunned => stunT > 0;
  double get outgoingMult => rageT > 0 ? 1.6 : 1.0;

  /// Counts swings so the opponent can react once per swing, not per frame.
  int swingId = 0;

  /// Fired when this fighter starts a swing (drives swing sounds).
  void Function(MoveKind kind)? onSwing;

  Fighter? opponent;
  final List<(Offset, double)> _trail = [];
  static final _rng = math.Random();

  static const _moveSpeedX = 200.0;

  GuardZone guardZone = GuardZone.none;

  bool get alive => hp > 0;
  bool get isGuarding => guardZone != GuardZone.none;

  /// Whether a blow to [zone] is turned by the current guard.
  bool guards(Zone zone) {
    if (!alive || (h > 0 && state != FState.combo)) return false;
    switch (guardZone) {
      case GuardZone.none:
        return false;
      case GuardZone.high:
        return parrying ? zone == Zone.head : zone != Zone.feet;
      case GuardZone.mid:
        return zone == Zone.body;
      case GuardZone.low:
        return parrying ? zone == Zone.feet : zone != Zone.head;
    }
  }

  Combo? get combo => comboPlayer.combo;
  bool get attacking =>
      state == FState.attack ||
      (state == FState.combo && combo?.kind == ComboKind.attack && !comboPlayer.exiting);
  bool get burning => dots.any((d) => d.color == burnColor);
  bool get poisoned => dots.any((d) => d.color == poisonColor);
  double get damageTakenMult =>
      guardT > 0 ? 0.3 : (weapon.special == Special.radiance ? 0.6 : 1.0);

  static const bleedColor = Color(0xFFFF3B5C);
  static const burnColor = Color(0xFFFF8A3D);
  static const poisonColor = Color(0xFF7CFF5A);

  void resetFor(double x, double zp, int face) {
    wx = x;
    zPos = kLaneZ;
    facing = face;
    h = 0;
    vh = 0;
    kvx = 0;
    ix = 0;
    iz = 0;
    _airVx = 0;
    _jumping = false;
    landT = 0;
    state = FState.idle;
    stateT = 0;
    currentMove = null;
    pendingKind = null;
    hitApplied = false;
    flashT = 0;
    blockFlashT = 0;
    dots.clear();
    slowT = 0;
    stunMult = 1;
    invulnT = veilT = guardT = rageT = hasteT = auraT = lifestealT = 0;
    shieldHp = 0;
    stunT = 0;
    guaranteedCrit = false;
    guardZone = GuardZone.none;
    _dropCombo();
    smashArmed = false;
    _trail.clear();
  }

  void _dropCombo() {
    comboPlayer.stop();
    comboMove = null;
    parrying = false;
    guardFactor = .25;
    if (state == FState.combo) {
      state = FState.idle;
      stateT = 0;
    }
  }

  /// The combo the sticks hold right now (null when either is centred),
  /// called every frame. A new combo waits for the current one's exit; an
  /// attack always finishes the swing it started.
  void holdCombo(Combo? c) {
    if (!alive || stunned) return;
    if (state != FState.combo) {
      if (c == null || state != FState.idle && state != FState.walk) return;
      comboPlayer.start(c);
      state = FState.combo;
      stateT = 0;
      hitApplied = false;
      if (comboPlayer.stage == ComboStage.loop) _comboCycle();
      return;
    }
    final cur = comboPlayer.combo!;
    if (c == cur) {
      // Re-held before the swing ended: keep looping.
      if (comboPlayer.released && comboPlayer.next == null && !comboPlayer.exiting) {
        comboPlayer.released = false;
      }
      return;
    }
    comboPlayer.release(to: c, now: cur.kind != ComboKind.attack);
  }

  /// A new loop cycle: attacks swing again, everything else just reports.
  void _comboCycle() {
    final c = comboPlayer.combo;
    if (c == null) return;
    hitApplied = false;
    if (c.kind == ComboKind.attack) {
      swingId++;
      final clip = comboPlayer.clip!;
      final (ws, we) = clip.window(lib, charKey);
      final smash = c.isSmash && smashArmed;
      comboMove = moveFor(c, weapon, clip.duration(ComboStage.loop, lib, charKey), ws, we, smash: smash);
      onSwing?.call(comboMove!.kind);
      onComboCycle?.call(c, smash);
    } else {
      comboMove = null;
      onComboCycle?.call(c, false);
    }
  }

  /// Cure every damage-over-time and chill effect.
  void cleanse() {
    dots.clear();
    slowT = 0;
  }

  /// An unblockable sword-art strike from [from].
  void artHit(Fighter from, double dmg, {double kx = 200, double kup = 0, double stun = 0, bool crit = false}) {
    if (!alive || untouchable) return;
    var amount = dmg * from.outgoingMult * damageTakenMult * (crit ? 1.6 : 1);
    amount = _absorb(amount);
    kvx = from.facing * kx;
    if (kup > 0) {
      vh = kup;
      h = math.max(h, 0.01);
    }
    pendingKind = null;
    currentMove = null;
    _dropCombo();
    state = FState.hit;
    stateT = 0;
    stunMult = 1.2;
    stunT = math.max(stunT, stun);
    flashT = .22;
    hp = math.max(0, hp - amount);
    final killed = hp <= 0;
    if (killed) {
      state = FState.dead;
      stateT = 0;
      dots.clear();
    }
    game.onStrike(from, this, MoveSpec.art(amount, kx: kx, kup: kup, shake: crit ? 9 : 6), amount, false, killed, crit);
  }

  double _absorb(double amount) {
    if (shieldHp <= 0) return amount;
    final used = math.min(shieldHp, amount);
    shieldHp -= used;
    return amount - used;
  }

  void setWeapon(Weapon w) {
    weapon = w;
    moves = buildMoves(w, lib, charKey);
  }

  /// Adds a damage-over-time effect; a weaker one never overwrites a stronger.
  void addDot(double dps, double seconds, Color color) {
    for (final d in dots) {
      if (d.color != color) continue;
      if (d.dps * d.left >= dps * seconds) {
        d.left = math.max(d.left, seconds);
        return;
      }
    }
    dots.removeWhere((d) => d.color == color);
    dots.add(Dot(dps, seconds, color));
  }

  void heal(double amount) {
    if (!alive) return;
    hp = math.min(maxHp, hp + amount);
  }

  /// Two held sticks spell a combo (see combos.dart); the left stick alone
  /// walks, and flicked up, jumps. Sectors are read relative to the enemy,
  /// so "toward" is always the same combo whichever side we stand on.
  void applySticks(Vector2 ls, Vector2 rs, {required bool smashArmed}) {
    if (!alive) {
      ix = 0;
      iz = 0;
      heldCombo = null;
      holdCombo(null);
      guardZone = GuardZone.none;
      return;
    }
    leftDir = Dir.decode(ls, facing, prev: leftDir);
    rightDir = Dir.decode(rs, facing, prev: rightDir);
    this.smashArmed = smashArmed;
    final l = leftDir, r = rightDir;
    if (l != null && r != null) {
      heldCombo = Combo.of(l, r);
      holdCombo(heldCombo);
      ix = 0;
      iz = 0;
    } else {
      heldCombo = null;
      holdCombo(null);
      ix = ls.x.abs() < 0.18 ? 0 : ls.x;
      iz = 0;
      // Left stick alone, flicked up: jump (once per flick, not while held).
      final up = ls.y < -.55 && ls.length > .6;
      if (up && !_jumpHeld) jump();
      _jumpHeld = up;
    }
    // Guards only come from held combos; the fighter owns them while in one.
    if (state != FState.combo) guardZone = GuardZone.none;
  }

  /// Leap straight up, or over the opponent when running at them. The arc
  /// clears a standing fighter, so face-to-face duels can swap sides.
  bool jump() {
    if (!alive || stunned || airborne || (state != FState.idle && state != FState.walk)) return false;
    _jumping = true;
    vh = jumpSpeed;
    h = 0.01;
    _airVx = ix.abs() > 0.18 ? ix.sign * _moveSpeedX * 1.15 * speedMult : 0;
    state = FState.idle;
    stateT = 0;
    onJump?.call();
    return true;
  }

  void startMove(MoveKind k) {
    if (!alive || stunned || state == FState.dead || state == FState.victory || state == FState.hit ||
        state == FState.combo) {
      return;
    }
    if (state == FState.attack && currentMove != null) {
      if (stateT > currentMove!.duration * 0.45) pendingKind = k;
      return;
    }
    currentMove = moves[k];
    state = FState.attack;
    stateT = 0;
    hitApplied = false;
    swingId++;
    onSwing?.call(k);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (puppet) {
      // Mirrored from the authority: only the cosmetic timers tick here.
      flashT = math.max(0, flashT - dt);
      blockFlashT = math.max(0, blockFlashT - dt);
      landT = math.max(0, landT - dt);
      _trail.removeWhere((e) => game.t - e.$2 > 0.16);
      zPos = kLaneZ;
      position.setValues(wx, kFloorTop + zPos - h);
      priority = 100 + zPos.round() + (h > 0 ? 40 : 0);
      return;
    }
    final slowed = slowT > 0;
    slowT = math.max(0, slowT - dt);
    for (final f in [
      () => invulnT = math.max(0, invulnT - dt),
      () => veilT = math.max(0, veilT - dt),
      () => guardT = math.max(0, guardT - dt),
      () => rageT = math.max(0, rageT - dt),
      () => hasteT = math.max(0, hasteT - dt),
      () => auraT = math.max(0, auraT - dt),
      () => lifestealT = math.max(0, lifestealT - dt),
    ]) {
      f();
    }
    var adt = slowed && state != FState.dead ? dt * 0.6 : dt;
    if (hasteT > 0 && attacking) adt *= 1.4;
    if (stunT > 0 && alive) {
      stunT = math.max(0, stunT - dt);
      if (state != FState.hit) {
        _dropCombo();
        state = FState.hit;
        stateT = 0;
      }
      // Hold the flinch pose while stunned.
      adt = 0;
      ix = 0;
      iz = 0;
    }
    stateT += adt;
    flashT = math.max(0, flashT - dt);
    blockFlashT = math.max(0, blockFlashT - dt);
    _trail.removeWhere((e) => game.t - e.$2 > 0.16);

    if (alive && dots.isNotEmpty) {
      var tick = 0.0;
      for (final d in dots) {
        d.left -= dt;
        tick += d.dps * dt;
      }
      dots.removeWhere((d) => d.left <= 0);
      hp = math.max(0, hp - tick);
      if (hp <= 0) {
        _dropCombo();
        state = FState.dead;
        stateT = 0;
        dots.clear();
        game.onKO(this);
      }
    }

    landT = math.max(0, landT - dt);
    if (state == FState.combo) {
      // The clip owns the height; a knock-up ends the combo first.
      h = comboPlayer.hop;
      vh = 0;
      _jumping = false;
    } else if (h > 0 || vh != 0) {
      h += vh * dt;
      vh -= gravity * dt;
      if (h <= 0) {
        h = 0;
        vh = 0;
        if (_jumping) {
          _jumping = false;
          landT = .18;
          onLand?.call();
        }
        _airVx = 0;
      }
    }
    kvx *= math.max(0, 1 - 7 * dt);
    if (kvx.abs() < 2) kvx = 0;

    var vx = kvx;
    // Only the ground axis moves: the fight is a 2D lane.
    final moving = ix.abs() > 0.18;
    final moveScale = slowed ? 0.45 : 1.0;

    if (state == FState.attack) {
      final m = currentMove!;
      final u = stateT / m.duration;
      if (!hitApplied && u >= m.winStart && u <= m.winEnd) _tryHit(m);
      if (stateT >= m.duration) {
        state = FState.idle;
        stateT = 0;
        currentMove = null;
        final p = pendingKind;
        pendingKind = null;
        if (p != null) startMove(p);
      }
    } else if (state == FState.combo) {
      final ev = comboPlayer.advance(adt);
      if (ev == ComboEvent.finished || !comboPlayer.active) {
        _dropCombo();
        h = 0;
        guardZone = GuardZone.none;
      } else {
        if (ev == ComboEvent.cycle) _comboCycle();
        final c = comboPlayer.combo!;
        vx += facing * comboPlayer.dxRate * speedMult * moveScale;
        h = comboPlayer.hop;
        final exiting = comboPlayer.exiting;
        guardZone = exiting ? GuardZone.none : c.guard;
        parrying = !exiting && c.parry;
        guardFactor = c.guardFactor;
        final m = comboMove;
        if (m != null && !hitApplied && !exiting && comboPlayer.inWindow(m.winStart, m.winEnd)) {
          _tryHit(m);
        }
      }
    } else if (state == FState.hit) {
      if (stateT >= lib.anim(charKey, 'hit').duration * stunMult && h <= 0) {
        state = FState.idle;
        stateT = 0;
        stunMult = 1;
      }
    } else if (state == FState.idle || state == FState.walk) {
      if (_jumping) {
        // Committed arc: the take-off speed carries through the air.
        vx += _airVx * moveScale;
        if (state != FState.idle) {
          state = FState.idle;
          stateT = 0;
        }
      } else if (moving) {
        vx += ix * _moveSpeedX * speedMult * moveScale;
        if (state != FState.walk) {
          state = FState.walk;
          stateT = 0;
        }
      } else if (state != FState.idle) {
        state = FState.idle;
        stateT = 0;
      }
    }

    wx = (wx + vx * dt).clamp(-kArenaHalf, kArenaHalf);
    zPos = kLaneZ;
    position.setValues(wx, kFloorTop + zPos - h);
    // The one in the air is drawn over the one on the ground.
    priority = 100 + zPos.round() + (airborne ? 40 : 0);
  }

  void _tryHit(MoveSpec m) {
    final op = opponent;
    if (op == null || !op.alive) return;
    final dx = (op.wx - wx) * facing;
    final dz = (op.zPos - zPos).abs();
    if (dx > -16 && dx < m.range + 20 && dz < 30 && (op.h - h).abs() < 70) {
      hitApplied = true;
      final blocked = op.guards(m.zone) && !m.heavy;
      op._receiveHit(this, m, blocked);
    }
  }

  void _receiveHit(Fighter from, MoveSpec m, bool blocked) {
    if (untouchable) {
      game.onImmune(this);
      return;
    }
    final dir = from.facing.toDouble();
    var dmg = m.dmg * from.dmgScale * from.outgoingMult * damageTakenMult;
    // Headshots: certain for the skull smash, likely for head cuts, rare for
    // a sweep that catches the chin.
    var crit = false;
    var critChance = m.heavy ? .55 : (m.zone == Zone.head ? .45 : (m.kind == MoveKind.kick ? .15 : 0.0));
    if (from.weapon.special == Special.shock) critChance = math.min(1, critChance * 2);
    if (from.guaranteedCrit && !blocked) {
      crit = true;
      from.guaranteedCrit = false;
      dmg *= 1.6;
    } else if (!blocked && _rng.nextDouble() < critChance) {
      crit = true;
      dmg *= 1.6;
    }
    if (auraT > 0) from.addDot(5, 3, burnColor);
    if (blocked && parrying) {
      // A parry: nothing gets through and the attacker is thrown off balance.
      blockFlashT = .35;
      from.kvx = -dir * 170;
      from.stunT = math.max(from.stunT, .45);
      game.onStrike(from, this, m, 0, true, false, false, parried: true);
      return;
    }
    if (blocked) dmg *= guardFactor;
    final before = dmg;
    dmg = _absorb(dmg);
    // A shield that soaks the whole hit leaves no flinch, just a flash.
    if (dmg <= 0 && before > 0) {
      blocked = true;
      kvx = dir * m.kx * 0.25;
      blockFlashT = .35;
      game.onStrike(from, this, m, 0, true, false, false);
      return;
    }
    if (blocked) {
      kvx = dir * m.kx * 0.4;
      blockFlashT = .35;
    } else {
      kvx = dir * m.kx;
      if (m.kup > 0) {
        vh = m.kup;
        h = math.max(h, 0.01);
      }
      pendingKind = null;
      currentMove = null;
      _dropCombo();
      state = FState.hit;
      stateT = 0;
      stunMult = from.weapon.special == Special.shock ? 1.6 : 1.0;
      flashT = .22;
    }
    hp = math.max(0, hp - dmg);
    final killed = hp <= 0;
    if (killed) {
      state = FState.dead;
      stateT = 0;
      dots.clear();
    }
    game.onStrike(from, this, m, dmg, blocked, killed, crit);
  }

  /// The current frame and its draw transform, for after-images.
  ({Sprite sprite, Vector2 offset, Vector2 size, double sx, double sy, bool pixel}) snapshot() {
    final (ba, fi) = _sampleAnim();
    final s = 0.80 + zPos / kZMax * 0.32;
    return (
      sprite: ba.frames[fi],
      offset: Vector2(-ba.ax / ba.scale, -ba.ay / ba.scale),
      size: Vector2(ba.fw / ba.scale, ba.fh / ba.scale),
      sx: facing * (ba.flip ? -1 : 1) * s,
      sy: s,
      pixel: ba.pixel,
    );
  }

  (BakedAnim, int) _sampleAnim() {
    final (name, frame) = _sampleNamed();
    return (lib.animOr(charKey, name), frame);
  }

  /// The strip name and frame index for the current pose.
  (String, int) _sampleNamed() {
    if (puppet) return (puppetAnim, puppetFrame);
    if (_jumping && (state == FState.idle || state == FState.walk)) {
      // Rising frames on the way up, falling frames past the apex.
      final name = vh > 0 ? 'jump' : 'fall';
      final ba = lib.animOr(charKey, name);
      final u = vh > 0 ? 1 - vh / jumpSpeed : (-vh / jumpSpeed).clamp(0.0, 1.0);
      return (name, ba.frameAt(ba.loop ? u : u * .999));
    }
    switch (state) {
      case FState.idle:
        final ba = lib.anim(charKey, 'idle');
        return ('idle', ba.frameAt(stateT / ba.duration));
      case FState.walk:
        final ba = lib.anim(charKey, 'walk');
        final reverse = ix * facing < -0.05;
        return ('walk', ba.frameAt(stateT / ba.duration, reverse: reverse));
      case FState.attack:
        final m = currentMove!;
        final ba = lib.anim(charKey, m.animName);
        return (m.animName, ba.frameAt(stateT / m.duration));
      case FState.combo:
        final cs = comboPlayer.sample();
        return (cs.name, cs.frame);
      case FState.hit:
        final ba = lib.anim(charKey, 'hit');
        return ('hit', ba.frameAt(stateT / (ba.duration * stunMult)));
      case FState.dead:
        final ba = lib.anim(charKey, 'death');
        return ('death', ba.frameAt(stateT / ba.duration));
      case FState.victory:
        final ba = lib.anim(charKey, 'victory');
        return ('victory', ba.frameAt(stateT / ba.duration));
    }
  }

  /// Body shear and crouch for the current pose (combo motion, or a puppet's
  /// mirrored values).
  (double, double) get poseLeanSquash => puppet
      ? (puppetLean, puppetSquash)
      : (state == FState.combo ? (comboPlayer.lean, comboPlayer.squash) : (0.0, 1.0));

  Color? _tint() {
    if (flashT > 0) {
      return const Color(0xFFFF4040).withValues(alpha: .55 * flashT / .22);
    }
    final pulse = 0.25 + 0.15 * math.sin(game.t * 14);
    if (burning) return burnColor.withValues(alpha: pulse);
    if (poisoned) return poisonColor.withValues(alpha: pulse);
    if (dots.isNotEmpty) return bleedColor.withValues(alpha: pulse * .8);
    if (slowT > 0) return const Color(0xFF7DD8FF).withValues(alpha: .35);
    return null;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final s = 0.80 + zPos / kZMax * 0.32;
    var op = state == FState.dead
        ? math.max(0.55, 1 - stateT * 0.6).toDouble()
        : 1.0;
    if (veilT > 0) op *= 0.45;
    _renderAura(canvas, s);

    // Ground shadow stays on the floor even when the body is launched.
    final shW = 48 * build * s * math.max(0.4, 1 - h / 260);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, h), width: shW, height: shW * 0.3),
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: .42 * op)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    _renderTrail(canvas);

    final (ba, fi) = _sampleAnim();
    // The packs are magnified ~3x; bilinear sampling melts the stair-steps
    // and a dark silhouette pass gives the body a clean inked edge.
    final paint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: op)
      ..filterQuality = FilterQuality.low;
    final tint = _tint();
    if (tint != null) {
      paint.colorFilter = ColorFilter.mode(tint, BlendMode.srcATop);
    }

    canvas.save();
    canvas.scale(facing * (ba.flip ? -1 : 1) * s, s);
    final (lean, sq) = poseLeanSquash;
    if (state == FState.combo || (puppet && (lean != 0 || sq != 1))) {
      // Crouch (squash at the feet) and lean (shear toward the enemy).
      canvas.scale(1 + (1 - sq) * .5, sq);
      canvas.skew(-lean, 0);
    } else if (landT > 0) {
      // Touch-down squash that springs back.
      final u = landT / .18;
      final sq = 1 - .16 * math.sin(u * math.pi);
      canvas.scale(1 + (1 - sq) * 1.2, sq);
    } else if (_jumping) {
      // Stretch on the way up, tuck on the way down.
      final st = 1 + (vh / jumpSpeed).clamp(-1.0, 1.0) * .08;
      canvas.scale(1 / st, st);
    }
    final framePos = Vector2(-ba.ax / ba.scale, -ba.ay / ba.scale);
    final frameSize = Vector2(ba.fw / ba.scale, ba.fh / ba.scale);
    final ink = Paint()
      ..filterQuality = FilterQuality.low
      ..colorFilter = ColorFilter.mode(const Color(0xFF0A0912).withValues(alpha: .85 * op), BlendMode.srcIn);
    const o = 1.6;
    for (final d in const [Offset(o, 0), Offset(-o, 0), Offset(0, o), Offset(0, -o)]) {
      ba.frames[fi].render(
        canvas,
        position: framePos + Vector2(d.dx, d.dy),
        size: frameSize,
        overridePaint: ink,
      );
    }
    ba.frames[fi].render(
      canvas,
      position: framePos,
      size: frameSize,
      overridePaint: paint,
    );

    // Guard flash when a hit is blocked.
    if (blockFlashT > 0) {
      final ga = blockFlashT / .35;
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(24, -98), radius: 26),
        -1.0,
        2.0,
        false,
        Paint()
          ..color = const Color(0xFF6FB8FF).withValues(alpha: .7 * ga * op)
          ..strokeWidth = 3.5
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
    canvas.restore();

    final tips = ba.tip;
    if (tips != null) {
      var swinging = false;
      if (state == FState.attack && currentMove != null) {
        final u = stateT / currentMove!.duration;
        swinging = u >= currentMove!.winStart - 0.22 && u <= currentMove!.winEnd + 0.12;
      } else if (state == FState.combo && comboMove != null) {
        swinging = comboPlayer.inWindow(comboMove!.winStart, comboMove!.winEnd, before: .22, after: .12);
      }
      if (swinging) {
        final tip = tips[math.min(fi, tips.length - 1)];
        _trail.add((
          Offset(position.x + tip[0] * facing * s, position.y + tip[1] * s),
          game.t,
        ));
      }
    }
  }

  /// A glowing ring at the feet while a sword-art buff is active.
  void _renderAura(Canvas canvas, double s) {
    Color? col;
    if (invulnT > 0) {
      col = const Color(0xFFFFE28A);
    } else if (shieldHp > 0) {
      col = const Color(0xFF9FDBFF);
    } else if (rageT > 0) {
      col = const Color(0xFFFF5C3D);
    } else if (guardT > 0) {
      col = const Color(0xFFC9D2E8);
    } else if (hasteT > 0) {
      col = const Color(0xFFFFF176);
    } else if (auraT > 0) {
      col = const Color(0xFFFF8A3D);
    } else if (veilT > 0) {
      col = const Color(0xFFC77DFF);
    }
    if (col == null) return;
    final pulse = 0.75 + 0.25 * math.sin(game.t * 9);
    final r = Rect.fromCenter(center: Offset(0, h), width: 74 * build * s, height: 24 * build * s);
    canvas.drawOval(r, Paint()
      ..color = col.withValues(alpha: .18 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawOval(r, Paint()
      ..color = col.withValues(alpha: .8 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..blendMode = BlendMode.plus);
    // Rising motes.
    for (var i = 0; i < 6; i++) {
      final ph = (game.t * 0.9 + i * 0.37) % 1.0;
      final x = math.sin(i * 2.1 + game.t * 1.3) * 26 * s;
      canvas.drawCircle(Offset(x, h - ph * 120 * s), 2.2 * (1 - ph) + .6,
          Paint()..color = col.withValues(alpha: .7 * (1 - ph))..blendMode = BlendMode.plus);
    }
  }

  void _renderTrail(Canvas canvas) {
    if (_trail.length < 2) return;
    for (var i = 0; i < _trail.length - 1; i++) {
      final (p1, t1) = _trail[i];
      final (p2, _) = _trail[i + 1];
      final age = ((game.t - t1) / 0.16).clamp(0.0, 1.0);
      final a = (1 - age) * 0.55 * (weapon.trail.a);
      canvas.drawLine(
        p1 - position.toOffset(),
        p2 - position.toOffset(),
        Paint()
          ..color = weapon.trail.withValues(alpha: a)
          ..strokeWidth = 2 + (1 - age) * 8
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus,
      );
    }
  }
}
