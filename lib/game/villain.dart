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

  @override
  void update(double dt) {
    final hero = opponent;
    if (game.phase == Phase.fighting && alive && hero != null && hero.alive && !stunned && hero.veilT <= 0) {
      _ai(dt, hero);
    } else {
      ix = 0;
      iz = 0;
    }
    super.update(dt);
  }

  void _ai(double dt, Fighter hero) {
    _cool -= dt;
    _thinkT -= dt;
    _modeT -= dt;

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
    }

    if ((state == FState.idle || state == FState.walk) &&
        _cool <= 0 &&
        adx < reach + 26 &&
        dz.abs() < 24) {
      startMove(_pickMove());
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
