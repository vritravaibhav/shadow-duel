import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/progress.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  test('rewards: a first clear pays well, a repeat a token, a loss a coin', () {
    final first = Progress.reward(stage: 3, win: true, firstClear: true, stars: 3);
    final firstOneStar = Progress.reward(stage: 3, win: true, firstClear: true, stars: 1);
    final repeat = Progress.reward(stage: 3, win: true, firstClear: false);
    final loss = Progress.reward(stage: 3, win: false, firstClear: false);
    expect(first, greaterThan(firstOneStar));
    expect(firstOneStar, greaterThan(repeat * 8));
    expect(repeat, greaterThan(loss));
    expect(loss, greaterThan(0));
    // Later stages pay more on a first clear.
    expect(Progress.reward(stage: 9, win: true, firstClear: true), greaterThan(first));
  });

  test('the purse buys blades once their stage is cleared and forges marks', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    final waki = Swords.byId('wakizashi');
    final katana = Swords.byId('katana');
    final nodachi = Swords.byId('nodachi');

    // The starter is free and already yours; everything else costs coins.
    expect(p.owns(waki), isTrue);
    expect(p.owns(katana), isFalse);
    expect(p.ownedSwords.map((s) => s.id), ['wakizashi']);
    expect(p.canBuy(katana), isFalse);
    expect(await p.buy(katana), isFalse);

    await p.addCoins(katana.price + 5);
    expect(p.canBuy(katana), isTrue);
    // Not on the rack yet: stage 2 has not fallen.
    expect(p.canBuy(nodachi), isFalse);
    expect(await p.buy(katana), isTrue);
    expect(p.coins, 5);
    expect(p.owns(katana), isTrue);
    expect(p.ownedSwords.map((s) => s.id), ['wakizashi', 'katana']);

    // Forging a mark makes the blade better and costs more each time.
    final cost1 = p.forged(katana).upgradeCost;
    expect(p.canUpgrade(katana), isFalse);
    await p.addCoins(cost1);
    expect(await p.upgrade(katana), isTrue);
    expect(p.levelOf(katana), 1);
    expect(p.forged(katana).weapon.strength, greaterThan(katana.weapon.strength));
    expect(p.forged(katana).active, greaterThan(katana.active));
    expect(p.forged(katana).upgradeCost, greaterThan(cost1));

    // Everything survives a reload.
    final q = Progress();
    await q.load();
    expect(q.coins, p.coins);
    expect(q.owns(katana), isTrue);
    expect(q.levelOf(katana), 1);
    expect(q.forged(waki).level, 0);

    // The starter can be forged too, and no blade goes past masterwork.
    await q.addCoins(100000);
    for (var i = 0; i < Sword.maxLevel + 2; i++) {
      await q.upgrade(waki);
    }
    expect(q.levelOf(waki), Sword.maxLevel);
    expect(q.forged(waki).maxed, isTrue);
    expect(q.forged(waki).upgradeCost, 0);
  });

  testWidgets('the duel is a 2D lane: no depth walking, and a jump clears the enemy',
      (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.hp = 500;
    v.maxHp = 500;

    // Pushing the left stick up/down alone never changes depth.
    expect(hero.zPos, kLaneZ);
    expect(v.zPos, kLaneZ);
    game.leftStickOverride = Vector2(0, .4);
    await frames(tester, 10);
    expect(hero.zPos, kLaneZ);
    game.leftStickOverride = Vector2(0, 0);
    await frames(tester, 2);

    // Stand toe to toe: bodies on the ground cannot pass through each other.
    hero.wx = -30;
    v.wx = 30;
    v.ix = 0;
    game.leftStickOverride = Vector2(1, 0);
    await frames(tester, 20);
    expect(hero.wx, lessThan(v.wx));
    expect(hero.facing, 1);
    expect(v.facing, -1);

    // Flick up while running at them: a leap that lands on the far side.
    hero.wx = v.wx - 60;
    game.leftStickOverride = Vector2(1, -1);
    await frames(tester, 2);
    expect(hero.jumping, isTrue);
    expect(hero.h, greaterThan(0));
    game.leftStickOverride = Vector2(1, 0);
    var crossed = false;
    for (var i = 0; i < 60 && hero.jumping; i++) {
      await tester.pump(const Duration(milliseconds: 32));
      if (hero.wx > v.wx) crossed = true;
    }
    expect(crossed, isTrue);
    expect(hero.jumping, isFalse);
    expect(hero.h, 0);
    // Landed, and both fighters turned to face each other across the swap.
    game.leftStickOverride = Vector2(0, 0);
    await frames(tester, 2);
    expect(hero.wx, greaterThan(v.wx));
    expect(hero.facing, -1);
    expect(v.facing, 1);
    expect(hero.zPos, kLaneZ);

    // Holding up does not bounce repeatedly: one jump per flick.
    game.leftStickOverride = Vector2(0, -1);
    await frames(tester, 2);
    expect(hero.jumping, isTrue);
    await untilState(tester, hero, FState.idle, max: 200);
    for (var i = 0; i < 60 && hero.jumping; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await frames(tester, 5);
    expect(hero.jumping, isFalse);
    game.pauseEngine();
  });
}
