import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';

import 'helpers.dart';

void main() {
  testWidgets('zone guards, smash recharge and deferred card swaps', (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 500;
    v.hp = 500;
    hero.wx = -60;
    hero.zPos = v.zPos = 80;
    v.wx = 40;
    hero.facing = 1;

    // A high guard turns a head cut but not a low sweep.
    v.guardZone = GuardZone.high;
    expect(v.guards(Zone.head), isTrue);
    expect(v.guards(Zone.body), isTrue);
    expect(v.guards(Zone.feet), isFalse);
    v.guardZone = GuardZone.low;
    expect(v.guards(Zone.head), isFalse);
    expect(v.guards(Zone.feet), isTrue);
    v.guardZone = GuardZone.none;

    // The skull smash rests between uses.
    expect(game.smashCd, 0);
    game.heroAttack(MoveKind.heavy);
    game.smashCd = ShadowGame.smashRecharge;
    await frames(tester, 3);
    expect(game.smashCd, greaterThan(0));

    // A card tapped mid-swing is drawn only once the swing finishes, so a
    // blow never mixes two blades.
    await untilState(tester, hero, FState.idle);
    game.equipCard(0);
    final before = hero.weapon.id;
    game.heroAttack(MoveKind.slash);
    expect(hero.attacking, isTrue);
    game.equipCard(1);
    expect(hero.weapon.id, before);
    await untilState(tester, hero, FState.idle, max: 200);
    await frames(tester, 3);
    expect(hero.weapon.id, 'katana');
    game.pauseEngine();
  });
}
