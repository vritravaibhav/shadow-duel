
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/arts.dart';
import 'package:shadow_duel/game/gestures.dart';
import 'package:shadow_duel/game/shadow_game.dart';

import 'helpers.dart';

void main() {
  testWidgets('sword arts: V fires a projectile that hits, W grants immunity, cooldowns gate recasts',
      (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);

    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 400;
    v.hp = 400;
    game.equipCard(1);
    expect(hero.weapon.id, 'katana');

    hero.wx = -100;
    hero.zPos = 80;
    v.wx = 120;
    v.zPos = 80;
    hero.facing = 1;
    final hp0 = v.hp;

    game.castArt(ArtGesture.v); // Crescent Cut
    expect(game.deck.artCooldown(ArtGesture.v), greaterThan(0));
    await frames(tester, 40);
    expect(v.hp, lessThan(hp0));
    expect(v.dots, isNotEmpty);

    // Recast while recharging does nothing.
    final cd = game.deck.artCooldown(ArtGesture.v);
    game.castArt(ArtGesture.v);
    expect(game.deck.artCooldown(ArtGesture.v), closeTo(cd, 0.05));

    // Any art locks every art briefly, even on another card.
    expect(game.deck.artCooldown(ArtGesture.w), greaterThan(0));
    game.castArt(ArtGesture.w);
    expect(hero.invulnT, 0);
    game.deck.artLock = 0;

    game.castArt(ArtGesture.w); // Iaijutsu Stance
    expect(hero.invulnT, greaterThan(0));
    expect(hero.guaranteedCrit, isTrue);

    // A drawn V goes through the gesture pipeline (recharging → flash only).
    final vGlyph = [
      for (var i = 0; i <= 10; i++) Offset(600 + i * 8.0, 200 + i * 12.0),
      for (var i = 1; i <= 10; i++) Offset(680 + i * 8.0, 320 - i * 12.0),
    ];
    game.onStroke(GestureRecognizer.recognize(vGlyph));
    await frames(tester, 5);

    // Bare hands have arts too.
    game.equipCard(-1);
    expect(hero.weapon.id, 'fists');
    game.deck.artLock = 0;
    final heroHp = hero.hp = 50;
    game.castArt(ArtGesture.w); // Breathe
    expect(hero.hp, greaterThan(heroHp));
    game.pauseEngine();
  });
}
