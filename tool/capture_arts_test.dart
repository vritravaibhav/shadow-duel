import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/arts.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/gestures.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/ui/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 32));
  }
}

Future<void> shot(WidgetTester tester, String name) =>
    expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('../test/goldens/$name.png'));

/// Hand a finished stroke to the game (the finger path itself is never drawn).
void stroke(ShadowGame game, List<Offset> pts) {
  game.onStroke(GestureRecognizer.recognize(pts));
}

List<Offset> vGlyph() => [
      for (var i = 0; i <= 14; i++) Offset(600 + i * 6.0, 190 + i * 10.0),
      for (var i = 1; i <= 14; i++) Offset(684 + i * 6.0, 330 - i * 10.0),
    ];

void main() {
  testWidgets('capture sword-art visuals', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'highestCleared': 16});

    final game = ShadowGame();
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: RepaintBoundary(
            child: GameWidget<ShadowGame>(
              game: game,
              overlayBuilderMap: {
                ShadowGame.overlayTitle: (context, g) => TitleScreen(game: g),
                ShadowGame.overlayMap: (context, g) => MapScreen(game: g),
                ShadowGame.overlayArmory: (context, g) => ArmoryScreen(game: g),
                ShadowGame.overlayResult: (context, g) => ResultScreen(game: g),
                ShadowGame.overlayPause: (context, g) => PauseScreen(game: g),
              },
            ),
          ),
        ),
      ));
      await game.loaded;
    });
    await tester.pump(const Duration(milliseconds: 50));

    game.startStage(3);
    for (var i = 0; i < 100 && game.phase != Phase.fighting; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 900;
    v.hp = 900;
    hero.wx = -120;
    hero.zPos = 80;
    v.wx = 140;
    v.zPos = 80;
    hero.facing = 1;

    // Katana: the V emblem flashes and the crescent flies.
    game.equipCard(1);
    game.deck.artLock = 0;
    stroke(game, vGlyph());
    await frames(tester, 4);
    await shot(tester, 'art_glyph');
    await frames(tester, 30);

    // Thunder Fang: Thunderclap.
    game.equipCard(6);
    game.deck.artLock = 0;
    game.castArt(ArtGesture.v);
    await frames(tester, 4);
    await shot(tester, 'art_thunderclap');
    await frames(tester, 30);

    // Nodachi: Earthsplitter.
    v.wx = hero.wx + 150;
    v.zPos = hero.zPos;
    game.equipCard(2);
    game.deck.artLock = 0;
    game.castArt(ArtGesture.v);
    await frames(tester, 6);
    await shot(tester, 'art_earthsplitter');
    await frames(tester, 30);

    // Dragon Cleaver: Rage aura + Dragon's Breath.
    v.wx = hero.wx + 150;
    v.zPos = hero.zPos;
    game.equipCard(9);
    game.castArt(ArtGesture.w);
    game.deck.artLock = 0;
    game.castArt(ArtGesture.v);
    await frames(tester, 5);
    await shot(tester, 'art_dragon');

    // Guard read-out: the villain covers high, so the feet are ringed open.
    game.startStage(2);
    for (var i = 0; i < 120 && game.phase != Phase.fighting; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    game.hero.wx = -80;
    game.villain!.wx = 60;
    game.hero.zPos = game.villain!.zPos = 90;
    game.villain!.guardZone = GuardZone.high;
    await frames(tester, 3);
    await shot(tester, 'guard_open');

    // Pause menu over a live battle.
    game.startStage(4);
    for (var i = 0; i < 120 && game.phase != Phase.fighting; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    game.pauseFight();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    await shot(tester, 'pause_menu');
    game.resumeFight();

    game.showArmory();
    await tester.pump(const Duration(milliseconds: 100));
    await shot(tester, 'armory_game');
    game.pauseEngine();
  });
}
