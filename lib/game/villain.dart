import 'dart:math' as math;

import 'fighter.dart';
import 'shadow_game.dart';
import 'weapons.dart';

class VillainFighter extends Fighter {
  VillainFighter({
    required String name,
    required super.charKey,
    required super.lib,
    required Weapon weapon,
    required super.maxHealth,
    required this.aggression,
    super.build,
    super.dmgScale,
    double moveSpeed = 1.0,
  }) : super(
          charName: name,
          startWeapon: weapon,
        ) {
    speedMult = moveSpeed;
  }

  final double aggression;
  final _rng = math.Random();
  double _thinkT = .6;
  double _cool = 1.4;
  int _mode = 0; // 0 chase, 1 strafe away, 2 hold ground (guard)
  double _modeT = 0;
  double _guardT = 0;
  int _guardedSwing = -1;

  /// A sparring dummy: no AI, the game scripts its guard and swings.
  bool dummy = false;

  /// Every swing is telegraphed: the villain plants its feet for
  /// [windUpTime] before it starts, long enough to read the zone and block.
  MoveKind? _windUp;
  double _windUpT = 0;
  static const windUpTime = .42;

  bool get windingUp => _windUp != null;

  /// The zone of the swing being telegraphed, for the incoming marker.
  Zone? get incomingZone => _windUp == null ? null : moves[_windUp!]!.zone;

  /// Fraction of the wind-up elapsed.
  double get windUpU => _windUp == null ? 0 : 1 - (_windUpT / windUpTime).clamp(0.0, 1.0);

  void windUp(MoveKind k, [double seconds = windUpTime]) {
    if (!alive || stunned || state == FState.hit || attacking) return;
    _windUp = k;
    _windUpT = seconds;
    ix = 0;
    iz = 0;
  }

  @override
  void update(double dt) {
    final hero = opponent;
    if (_windUp != null) {
      _windUpT -= dt;
      ix = 0;
      iz = 0;
      if (state == FState.hit || stunned || !alive) {
        _windUp = null;
      } else if (_windUpT <= 0) {
        final k = _windUp!;
        _windUp = null;
        startMove(k);
      }
    } else if (dummy) {
      ix = 0;
      iz = 0;
    } else if (game.phase == Phase.fighting && alive && hero != null && hero.alive && !stunned && hero.veilT <= 0) {
      _ai(dt, hero);
    } else {
      ix = 0;
      iz = 0;
      guardZone = GuardZone.none;
    }
    super.update(dt);
  }

  void _ai(double dt, Fighter hero) {
    _cool -= dt;
    _thinkT -= dt;
    _modeT -= dt;
    _guardT -= dt;
    if (_guardT <= 0) guardZone = GuardZone.none;

    final dx = hero.wx - wx;
    final adx = dx.abs();
    final dz = hero.zPos - zPos;
    final reach = moves[MoveKind.punch]!.range + 6;

    if (_thinkT <= 0) {
      _thinkT = 0.22 + _rng.nextDouble() * 0.3;
      final roll = _rng.nextDouble();
      if (hero.attacking && adx < 130 && roll < 0.35) {
        _mode = 2;
        _modeT = .45;
      } else if (roll < 0.12) {
        _mode = 1;
        _modeT = .5;
      } else {
        _mode = 0;
        _modeT = 1.0;
      }
    }
    if (_modeT <= 0) _mode = 0;

    // One guard decision per hero swing, taken as the swing starts and held
    // long enough that reading the open zone actually pays off.
    if (hero.attacking && hero.swingId != _guardedSwing && adx < 150 &&
        (state == FState.idle || state == FState.walk)) {
      _guardedSwing = hero.swingId;
      if (_rng.nextDouble() < 0.55) {
        guardZone = _rng.nextDouble() < 0.55 ? GuardZone.high : GuardZone.low;
        _guardT = 1.1;
        ix = 0;
        iz = 0;
        return;
      }
    }
    if (guardZone != GuardZone.none) {
      ix = 0;
      iz = 0;
      return;
    }

    switch (_mode) {
      case 0:
        ix = adx > reach - 10 ? dx.sign : 0;
        iz = dz.abs() > 12 ? dz.sign : 0;
      case 1:
        ix = -dx.sign * .7;
        iz = dz.abs() > 40 ? dz.sign : 0;
      default:
        ix = 0;
        iz = 0;
        guardZone = GuardZone.high;
        _guardT = math.max(_guardT, .3);
    }

    if ((state == FState.idle || state == FState.walk) &&
        _cool <= 0 &&
        adx < reach + 26 &&
        dz.abs() < 24) {
      windUp(_pickMove());
      _cool = (0.7 + _rng.nextDouble() * 0.9) / aggression;
      ix = 0;
      iz = 0;
    }
  }

  MoveKind _pickMove() {
    final roll = _rng.nextDouble();
    if (roll < 0.14) return MoveKind.heavy;
    if (roll < 0.34) return MoveKind.kick;
    if (roll < 0.64 && weapon.range > 0) return MoveKind.slash;
    return MoveKind.punch;
  }
}
