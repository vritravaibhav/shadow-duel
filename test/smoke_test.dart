import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/shadow_game.dart';

import 'helpers.dart';

void main() {
  testWidgets('game boots to the menu, starts stage 1 and fights', (tester) async {
    final game = await bootGame(tester);
    expect(game.phase, Phase.menu);
    expect(game.deck.cards.length, 2); // wakizashi + katana starters

    game.startStage(1);
    expect(game.phase, Phase.intro);
    await frames(tester, 90);
    expect(game.phase, isNot(Phase.intro));
    expect(game.hero.hp, greaterThan(0));
    expect(game.villain, isNotNull);
    expect(game.hero.weapon.id, 'wakizashi');
    game.pauseEngine();
  });
}
