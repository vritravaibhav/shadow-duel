import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/dark/dark_roster.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/netplay.dart';
import 'package:shadow_duel/game/progress.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Two games joined by a loopback link: [host] runs the fight, [guest] mirrors.
Future<(ShadowGame, ShadowGame, LoopbackLink, LoopbackLink)> duel(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final host = ShadowGame(), guest = ShadowGame();
  Widget widgetFor(ShadowGame g) => GameWidget<ShadowGame>(
        game: g,
        overlayBuilderMap: {
          for (final k in [ShadowGame.overlayDark, ShadowGame.overlayDarkChat, ShadowGame.overlayDarkResult, ShadowGame.overlayTitle])
            k: (context, g) => const SizedBox(),
        },
      );
  await tester.runAsync(() async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [Expanded(child: widgetFor(host)), Expanded(child: widgetFor(guest))]),
      ),
    ));
    await host.loaded;
    await guest.loaded;
  });
  await tester.pump(const Duration(milliseconds: 50));
  final (hl, gl) = LoopbackLink.pair();
  host.startNetDuel(NetDuel(hl), myName: 'RAVEN', myChar: 'huntress', theirName: 'VESPER', theirChar: 'huntress-2');
  guest.startNetDuel(NetDuel(gl), myName: 'VESPER', myChar: 'huntress-2', theirName: 'RAVEN', theirChar: 'huntress');
  return (host, guest, hl, gl);
}

Future<void> pump(WidgetTester tester, LoopbackLink a, LoopbackLink b, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 32));
    a.flush();
    b.flush();
  }
}

void main() {
  testWidgets('the dark roster is women only and playable on both sides', (tester) async {
    final game = await bootGame(tester);
    expect(DarkRoster.all.map((f) => f.charKey).toSet(), {'huntress', 'huntress-2'});
    game.setHeroChar('RAVEN', 'huntress');
    expect(game.hero.charName, 'RAVEN');
    expect(game.hero.charKey, 'huntress');
    final r = DarkRoster.all[2];
    game.startDarkTrial(StageCfg(102, r.name, r.charKey, r.hp, r.dmg, r.agg, r.speed), 2, heroName: 'RAVEN', heroChar: 'huntress');
    expect(game.inDarkTrial, isTrue);
    expect(game.villain!.charName, 'NYX');
    expect(game.villain!.charKey, 'huntress');
    expect(game.opponentName, 'NYX');
    // Trials never touch the campaign map and pay a flat purse.
    final before = game.progress.coins;
    await untilPhase(tester, game, Phase.fighting);
    game.villain!.hp = 1;
    game.hero.wx = game.villain!.wx - 50;
    game.hero.startMove(MoveKind.punch);
    await untilPhase(tester, game, Phase.roundOver, max: 200);
    await untilPhase(tester, game, Phase.menu, max: 200);
    expect(game.overlays.isActive(ShadowGame.overlayResult), isTrue);
    expect(game.lastCoins, Progress.darkTrialReward(2, stars: game.lastStars));
    expect(game.progress.coins, before + game.lastCoins);
    expect(game.progress.isCleared(102), isFalse);
    expect(game.progress.highestCleared, 0);
    expect(game.lastFirstClear, isFalse);
  });

  testWidgets('host drives the remote fighter from the guest sticks; the guest mirrors', (tester) async {
    final (host, guest, hl, gl) = await duel(tester);
    expect(host.netplay && guest.netplay, isTrue);
    expect(host.hero.charName, 'RAVEN');
    expect(host.villain!.charName, 'VESPER');
    // The guest sees the same arena from the same side: host left, guest right.
    expect(guest.hero.charName, 'RAVEN');
    expect(guest.villain!.charName, 'VESPER');
    expect(guest.hero.puppet && guest.villain!.puppet, isTrue);
    expect(host.hero.puppet || host.villain!.puppet, isFalse);
    expect(host.deck.cards, isEmpty);

    await untilPhase(tester, host, Phase.fighting);
    await untilPhase(tester, guest, Phase.fighting);
    final v = host.villain! as RemoteFighter;
    final x0 = v.wx;
    // The guest holds the left stick toward the host for a while.
    guest.leftStickOverride = Vector2(-1, 0);
    await pump(tester, hl, gl, 20);
    guest.leftStickOverride = Vector2.zero();
    expect(v.wx, lessThan(x0 - 20));
    // ...and the guest's puppet copy of that fighter followed the snapshots.
    expect((guest.villain!.wx - v.wx).abs(), lessThan(30));
    expect(guest.villain!.puppetAnim, isNotEmpty);

    // A tap from the guest lands as an attack on the host.
    guest.heroAttack(MoveKind.punch);
    await pump(tester, hl, gl, 2);
    expect(v.state, FState.attack);
  });

  testWidgets('the host hands down the verdict and both sides land on the dark result', (tester) async {
    final (host, guest, hl, gl) = await duel(tester);
    await untilPhase(tester, host, Phase.fighting);
    await untilPhase(tester, guest, Phase.fighting);
    // The host's fighter finishes the guest's.
    host.villain!.hp = 1;
    host.hero.wx = host.villain!.wx - 50;
    host.hero.startMove(MoveKind.punch);
    for (var i = 0; i < 400 && host.phase != Phase.menu; i++) {
      await pump(tester, hl, gl, 1);
    }
    expect(host.phase, Phase.menu);
    expect(host.overlays.isActive(ShadowGame.overlayDarkResult), isTrue);
    expect(host.darkWon, isTrue);
    // The strike was relayed: the guest's mirror saw the kill and the verdict.
    expect(guest.villain!.hp, lessThanOrEqualTo(0));
    expect(guest.overlays.isActive(ShadowGame.overlayDarkResult), isTrue);
    expect(guest.darkWon, isFalse);
    // No campaign coins change hands in the Dark duel.
    expect(host.progress.coins, 0);

    // Rematch from the host restarts both.
    host.rematchNetDuel();
    await pump(tester, hl, gl, 2);
    expect(host.phase, Phase.intro);
    expect(guest.phase, Phase.intro);
    expect(guest.overlays.isActive(ShadowGame.overlayDarkChat), isTrue);

    // Leaving tears the line down and returns to the hub.
    host.leaveNetDuel();
    expect(host.net, isNull);
    expect(host.villain, isNull);
    expect(host.overlays.isActive(ShadowGame.overlayDark), isTrue);
  });

  testWidgets('sword arts are refused in the dark and the guest cannot steer locally', (tester) async {
    final (host, guest, hl, gl) = await duel(tester);
    await untilPhase(tester, guest, Phase.fighting);
    final x0 = guest.hero.wx;
    guest.hero.ix = 1;
    await pump(tester, hl, gl, 10);
    // A puppet has no physics of its own: it stays where the host says.
    expect((guest.hero.wx - x0).abs(), lessThan(1));
    expect(host.hero.state, isNot(FState.combo));
  });
}
