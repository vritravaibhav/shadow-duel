import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ShadowGame> bootGame(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final game = ShadowGame();
  await tester.runAsync(() async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameWidget<ShadowGame>(
            game: game,
            overlayBuilderMap: {
              for (final k in [
                ShadowGame.overlayTitle,
                ShadowGame.overlayMap,
                ShadowGame.overlayArmory,
                ShadowGame.overlayResult,
                ShadowGame.overlayPause,
                ShadowGame.overlayDojo,
                ShadowGame.overlayDark,
                ShadowGame.overlayDarkChat,
                ShadowGame.overlayDarkResult,
              ])
                k: (context, g) => const SizedBox(),
            },
          ),
        ),
      ),
    );
    await game.loaded;
  });
  await tester.pump(const Duration(milliseconds: 50));
  return game;
}

/// Buys the katana so the deck holds two cards (starter wakizashi + katana),
/// the way it did before blades had to be bought.
Future<void> buyKatana(ShadowGame game) async {
  await game.progress.addCoins(Swords.byId('katana').price);
  await game.progress.buy(Swords.byId('katana'));
  game.onArmoryChanged();
}

Future<void> frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

Future<void> untilPhase(WidgetTester tester, ShadowGame game, Phase phase, {int max = 300}) async {
  for (var i = 0; i < max && game.phase != phase; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

Future<void> untilState(WidgetTester tester, dynamic fighter, dynamic state, {int max = 120}) async {
  for (var i = 0; i < max && fighter.state != state; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}
