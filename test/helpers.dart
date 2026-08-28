import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/shadow_game.dart';
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
