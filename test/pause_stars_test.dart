import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/progress.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  testWidgets('pause freezes the fight; quit returns to the map without clearing',
      (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final v = game.villain!;
    final hpBefore = v.hp;
    final xBefore = v.wx;

    game.pauseFight();
    expect(game.battlePaused, isTrue);
    expect(game.overlays.isActive(ShadowGame.overlayPause), isTrue);
    expect(game.timeDilation, 0);

    // The world does not advance while paused.
    await frames(tester, 30);
    expect(v.hp, hpBefore);
    expect(v.wx, xBefore);

    game.resumeFight();
    expect(game.battlePaused, isFalse);
    expect(game.overlays.isActive(ShadowGame.overlayPause), isFalse);
    await frames(tester, 20);
    expect(game.timeDilation, greaterThan(0));

    // Quitting mid-battle goes to the map and does not count as a clear.
    game.pauseFight();
    game.quitToMap();
    expect(game.phase, Phase.menu);
    expect(game.battlePaused, isFalse);
    expect(game.villain, isNull);
    expect(game.overlays.isActive(ShadowGame.overlayMap), isTrue);
    expect(game.progress.highestCleared, 0);
    game.pauseEngine();
  });

  testWidgets('stars: win = 1, healthy win = 2, big combo = 3', (tester) async {
    final game = await bootGame(tester);

    // Scrappy win: low health, no combo -> 1 star.
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    game.hero.hp = game.hero.maxHp * .2;
    game.stageMaxCombo = 0;
    game.villain!.hp = 0.5;
    game.hero.wx = game.villain!.wx - 50;
    game.hero.zPos = game.villain!.zPos;
    for (var i = 0; i < 400 && game.phase == Phase.fighting; i++) {
      game.heroAttack(MoveKind.punch);
      await tester.pump(const Duration(milliseconds: 32));
    }
    await untilPhase(tester, game, Phase.menu);
    expect(game.lastWin, isTrue);
    expect(game.lastStars, 1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.progress.starsFor(1), 1);

    // Clean win: full health and an 8-hit combo -> 3 stars.
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    game.hero.hp = game.hero.maxHp;
    game.stageMaxCombo = 9;
    game.villain!.hp = 0.5;
    game.hero.wx = game.villain!.wx - 50;
    game.hero.zPos = game.villain!.zPos;
    for (var i = 0; i < 400 && game.phase == Phase.fighting; i++) {
      game.heroAttack(MoveKind.punch);
      await tester.pump(const Duration(milliseconds: 32));
    }
    await untilPhase(tester, game, Phase.menu);
    expect(game.lastStars, 3);
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.progress.starsFor(1), 3);
    expect(game.progress.totalStars, 3);
    game.pauseEngine();
  });

  test('progress: stars only improve, combo records a personal best', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Progress();
    await p.load();
    expect(await p.clearStage(3, 2), isTrue);
    expect(p.starsFor(3), 2);
    expect(p.highestCleared, 3);
    // A worse run never lowers the recorded stars.
    expect(await p.clearStage(3, 1), isFalse);
    expect(p.starsFor(3), 2);
    expect(await p.clearStage(3, 3), isTrue);
    expect(p.starsFor(3), 3);
    expect(p.totalStars, 3);

    expect(await p.recordCombo(12), isTrue);
    expect(await p.recordCombo(9), isFalse);
    expect(p.bestCombo, 12);
  });
}
