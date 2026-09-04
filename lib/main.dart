import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/shadow_game.dart';
import 'ui/dojo.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ShadowDuelApp());
}

class ShadowDuelApp extends StatefulWidget {
  const ShadowDuelApp({super.key});

  @override
  State<ShadowDuelApp> createState() => _ShadowDuelAppState();
}

class _ShadowDuelAppState extends State<ShadowDuelApp> {
  final game = ShadowGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadow Duel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: Colors.black,
        body: GameWidget<ShadowGame>(
          game: game,
          overlayBuilderMap: {
            ShadowGame.overlayTitle: (context, g) => TitleScreen(game: g),
            ShadowGame.overlayMap: (context, g) => MapScreen(game: g),
            ShadowGame.overlayArmory: (context, g) => ArmoryScreen(game: g),
            ShadowGame.overlayResult: (context, g) => ResultScreen(game: g),
            ShadowGame.overlayPause: (context, g) => PauseScreen(game: g),
            ShadowGame.overlayDojo: (context, g) => DojoScreen(game: g),
          },
          initialActiveOverlays: const [ShadowGame.overlayTitle],
        ),
      ),
    );
  }
}
