import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/progress.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';

import 'helpers.dart';

Future<void> finishVillain(WidgetTester tester, ShadowGame game) async {
  await untilPhase(tester, game, Phase.fighting);
  expect(game.phase, Phase.fighting);
  final v = game.villain!;
  v.hp = 0.5;
  game.hero.wx = v.wx - 50;
  game.hero.zPos = v.zPos;
  for (var i = 0; i < 400 && game.phase == Phase.fighting; i++) {
    game.heroAttack(MoveKind.punch);
    await tester.pump(const Duration(milliseconds: 32));
  }
  expect(game.phase, Phase.roundOver);
  await untilPhase(tester, game, Phase.menu);
  expect(game.phase, Phase.menu);
}

void main() {
  testWidgets('clearing stages saves progress, unlocks swords; defeat allows retry',
      (tester) async {
    final game = await bootGame(tester);

    game.startStage(1);
    await finishVillain(tester, game);
    expect(game.lastWin, isTrue);
    expect(game.progress.highestCleared, 1);
    expect(game.overlays.isActive(ShadowGame.overlayResult), isTrue);
    expect(game.progress.isUnlocked(2), isTrue);
    expect(game.progress.isUnlocked(3), isFalse);

    // A first clear pays the bounty into the purse.
    expect(game.lastFirstClear, isTrue);
    expect(game.lastCoins, Progress.reward(stage: 1, win: true, firstClear: true, stars: game.lastStars));
    expect(game.progress.coins, game.coinsBefore + game.lastCoins);

    game.nextStage();
    expect(game.stage, 2);
    await finishVillain(tester, game);
    expect(game.progress.highestCleared, 2);
    // Clearing stage 2 puts the nodachi on the rack, but not in the deck.
    expect(game.lastUnlocked?.id, 'nodachi');
    expect(game.progress.onSale(Swords.byId('nodachi')), isTrue);
    expect(game.progress.owns(Swords.byId('nodachi')), isFalse);
    expect(game.deck.cards.map((c) => c.sword.id), isNot(contains('nodachi')));

    // Only the free starter is in the deck until something is bought.
    expect(game.deck.cards.map((c) => c.sword.id), ['wakizashi']);
    game.progress.coins = 1000;
    expect(await game.progress.buy(Swords.byId('nodachi')), isTrue);
    game.onArmoryChanged();
    expect(game.deck.cards.map((c) => c.sword.id), contains('nodachi'));

    game.nextStage();
    expect(game.stage, 3);
    expect(game.deck.cards.map((c) => c.sword.id), contains('nodachi'));
    expect(game.stageCfg(3).charKey, 'hero-knight-2');

    // Lose stage 3, then retry it.
    await untilPhase(tester, game, Phase.fighting);
    game.hero.hp = 1;
    await untilPhase(tester, game, Phase.menu, max: 1500);
    expect(game.phase, Phase.menu);
    expect(game.lastWin, isFalse);
    // A loss still pays a coin for the road, and it is not a first clear.
    expect(game.lastCoins, Progress.reward(stage: 3, win: false, firstClear: false));
    expect(game.lastFirstClear, isFalse);
    game.retryStage();
    expect(game.phase, Phase.intro);
    expect(game.stage, 3);
    game.pauseEngine();
  });
}
