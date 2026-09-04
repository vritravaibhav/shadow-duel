import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/combos.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';

import 'helpers.dart';

void hold(ShadowGame game, Dir? left, Dir? right) {
  Vector2 stick(Dir? d) => d == null
      ? Vector2.zero()
      : Vector2(d.h * game.hero.facing.toDouble(), -d.v.toDouble()).normalized();
  game.leftStickOverride = stick(left);
  game.rightStickOverride = stick(right);
}

void main() {
  testWidgets('q7 probe smash', (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 500000; v.hp = 500000; v.dummy = true;
    hero.maxHp = 500000; hero.hp = 500000;
    hero.wx = -30; v.wx = 30; hero.zPos = v.zPos = 80;
    await frames(tester, 2);

    var cycles = 0, smashes = 0, hits = 0;
    final dmgs = <double>[];
    hero.onComboCycle = (c, s) { cycles++; if (s) smashes++; };
    double lastHp = v.hp;
    hold(game, Dir.up, Dir.up);
    for (var i = 0; i < 250; i++) {
      await frames(tester, 1);
      if (v.hp != lastHp) { hits++; dmgs.add(double.parse((lastHp - v.hp).toStringAsFixed(2))); lastHp = v.hp; }
    }
    print('Q7 smash: cycles=$cycles smashes=$smashes hits=$hits smashCd=${game.smashCd} t=${game.t} dmgs=$dmgs');
    print('Q7 pos hero.wx=${hero.wx} v.wx=${v.wx}');
    game.pauseEngine();
  });

  testWidgets('q7 probe slash', (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 500000; v.hp = 500000; v.dummy = true;
    hero.maxHp = 500000; hero.hp = 500000;
    hero.wx = -30; v.wx = 30; hero.zPos = v.zPos = 80;
    await frames(tester, 2);
    var cycles = 0, hits = 0; double lastHp = v.hp;
    final dmgs = <double>[];
    hero.onComboCycle = (c, s) { cycles++; };
    hold(game, Dir.fwd, Dir.fwd);
    for (var i = 0; i < 150; i++) {
      await frames(tester, 1);
      if (v.hp != lastHp) { hits++; dmgs.add(double.parse((lastHp - v.hp).toStringAsFixed(2))); lastHp = v.hp; }
    }
    print('Q7 slash: cycles=$cycles hits=$hits t=${game.t} dmgs=$dmgs');
    print('Q7 pos hero.wx=${hero.wx} v.wx=${v.wx} guard=${v.guardZone}');
    game.pauseEngine();
  });

  testWidgets('q7 probe block/parry/stepback damage', (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.dummy = true;
    hero.maxHp = 500000; hero.hp = 500000;
    hero.wx = -30; v.wx = 30; hero.zPos = v.zPos = 80;
    await frames(tester, 2);

    Future<double> take(Dir? l, Dir? r, MoveKind k) async {
      hold(game, l, r);
      for (var i = 0; i < 30; i++) { await frames(tester, 1); }
      final before = hero.hp;
      v.wx = 30; hero.wx = -30;
      v.startMove(k);
      for (var i = 0; i < 30 && !v.hitApplied; i++) { await frames(tester, 1); }
      final dealt = before - hero.hp;
      for (var i = 0; i < 10; i++) { await frames(tester, 1); }
      return dealt;
    }

    print('Q7 no guard vs high: ${await take(null, null, MoveKind.high)}');
    print('Q7 high block vs high: ${await take(Dir.back, Dir.up, MoveKind.high)} guard=${hero.guardZone} f=${hero.guardFactor}');
    print('Q7 high block vs kick(feet): ${await take(Dir.back, Dir.up, MoveKind.kick)}');
    print('Q7 low block vs kick: ${await take(Dir.back, Dir.down, MoveKind.kick)}');
    print('Q7 high parry vs high: ${await take(Dir.back, Dir.upFwd, MoveKind.high)} parrying=${hero.parrying} vstun=${v.stunT}');
    print('Q7 stepback guard vs high: ${await take(Dir.back, Dir.upBack, MoveKind.high)} guard=${hero.guardZone} f=${hero.guardFactor}');
    print('Q7 advance guard vs high: ${await take(Dir.fwd, Dir.upBack, MoveKind.high)} guard=${hero.guardZone} f=${hero.guardFactor}');
    print('Q7 mid block vs punch(body): ${await take(Dir.back, Dir.fwd, MoveKind.punch)} guard=${hero.guardZone}');
    game.pauseEngine();
  });
}
