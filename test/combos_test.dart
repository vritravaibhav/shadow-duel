import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/combos.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/tutorial.dart';
import 'package:shadow_duel/game/weapons.dart';

import 'helpers.dart';

/// Holds the sticks the way a thumb does: [d] is read relative to the enemy.
void hold(ShadowGame game, Dir? left, Dir? right) {
  Vector2 stick(Dir? d) => d == null
      ? Vector2.zero()
      : Vector2(d.h * game.hero.facing.toDouble(), -d.v.toDouble()).normalized();
  game.leftStickOverride = stick(left);
  game.rightStickOverride = stick(right);
}

void main() {
  test('64 combos, each with its own name and clip', () {
    expect(Combo.all.length, 64);
    expect(Combo.all.map((c) => c.id).toSet().length, 64);
    expect(Combo.all.map((c) => c.name).toSet().length, 64);
    // No two combos animate identically.
    final sig = <String>{};
    for (final c in Combo.all) {
      final clip = ComboClip.recipe(c);
      String ph(ClipPhase p) =>
          '${p.anim}/${p.speed}/${p.reverse}/${p.from}-${p.to}/${p.hop}/${p.dx}/${p.lean}/${p.squash}/${p.hold}';
      sig.add([clip.enter, clip.loop, clip.exit].map((l) => l.map(ph).join(',')).join('|'));
    }
    expect(sig.length, 64);
    expect(Combo.ofKind(ComboKind.attack).length, 25);
    expect(Combo.ofKind(ComboKind.block).length, 15);
    expect(Combo.ofKind(ComboKind.stepBack).length, 9);
    expect(Combo.ofKind(ComboKind.advance).length, 15);
  });

  test('the rule: attack, block, step back, guard advance', () {
    // Left ▲ + right ▲ is the head-and-jump smash; left ▼ + right ▼ kicks the legs.
    final smash = Combo.of(Dir.up, Dir.up);
    expect(smash.isSmash, isTrue);
    expect(smash.kind, ComboKind.attack);
    expect(smash.zone, Zone.head);
    expect(smash.aerial, isTrue);
    final lowKick = Combo.of(Dir.down, Dir.down);
    expect(lowKick.name, 'LOW KICK');
    expect(lowKick.zone, Zone.feet);
    expect(lowKick.leg, isTrue);
    // Both sticks away: step back. Left away, right at the enemy: block.
    expect(Combo.of(Dir.back, Dir.back).kind, ComboKind.stepBack);
    expect(Combo.of(Dir.upBack, Dir.downBack).kind, ComboKind.stepBack);
    final highBlock = Combo.of(Dir.back, Dir.up);
    expect(highBlock.kind, ComboKind.block);
    expect(highBlock.guard, GuardZone.high);
    expect(Combo.of(Dir.back, Dir.down).guard, GuardZone.low);
    expect(Combo.of(Dir.back, Dir.fwd).guard, GuardZone.mid);
    expect(Combo.of(Dir.back, Dir.upFwd).parry, isTrue);
    expect(Combo.of(Dir.back, Dir.up).parry, isFalse);
    // Both at the enemy: attack. Left at them, right away: guard advance.
    expect(Combo.of(Dir.fwd, Dir.fwd).kind, ComboKind.attack);
    expect(Combo.of(Dir.fwd, Dir.back).kind, ComboKind.advance);
    expect(Combo.of(Dir.fwd, Dir.back).guard, GuardZone.mid);
  });

  test('sticks decode relative to the enemy, with hysteresis', () {
    // Facing right: pushing right is toward; facing left: pushing left is.
    expect(Dir.decode(Vector2(1, 0), 1), Dir.fwd);
    expect(Dir.decode(Vector2(1, 0), -1), Dir.back);
    expect(Dir.decode(Vector2(0, -1), 1), Dir.up);
    expect(Dir.decode(Vector2(0, 1), -1), Dir.down);
    expect(Dir.decode(Vector2(.7, -.7), 1), Dir.upFwd);
    expect(Dir.decode(Vector2(-.7, .7), 1), Dir.downBack);
    expect(Dir.decode(Vector2(.1, .1), 1), isNull);
    // Just past the sector edge the previous sector is kept…
    final edge = Vector2(1, -0.5); // ~26.6° up: nominally upFwd
    expect(Dir.decode(edge, 1), Dir.upFwd);
    expect(Dir.decode(edge, 1, prev: Dir.fwd), Dir.fwd);
    // …but a clear move switches.
    expect(Dir.decode(Vector2(.5, -1), 1, prev: Dir.fwd), Dir.upFwd);
  });

  testWidgets('holding a combo loops swings; blocks turn matching blows; parries stagger', (tester) async {
    final game = await bootGame(tester);
    game.startStage(1);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 5000;
    v.hp = 5000;
    v.dummy = true;
    hero.wx = -30;
    v.wx = 30;
    hero.zPos = v.zPos = 80;
    await frames(tester, 2);

    // A held attack re-hits every cycle.
    final slash = Combo.of(Dir.fwd, Dir.fwd);
    var swings = 0;
    hero.onComboCycle = (c, smash) => swings++;
    hold(game, Dir.fwd, Dir.fwd);
    await frames(tester, 60);
    expect(hero.state, FState.combo);
    expect(hero.combo, slash);
    expect(game.heldCombo, slash);
    expect(swings, greaterThanOrEqualTo(3));
    expect(v.hp, lessThan(5000));

    // Switching to another combo exits first, then enters the new one.
    final kick = Combo.of(Dir.down, Dir.down);
    hold(game, Dir.down, Dir.down);
    await frames(tester, 1);
    expect(hero.comboPlayer.next ?? hero.combo, kick);
    for (var i = 0; i < 40 && hero.combo != kick; i++) {
      await frames(tester, 1);
    }
    expect(hero.combo, kick);

    // Releasing both sticks ends the combo.
    hold(game, null, null);
    for (var i = 0; i < 60 && hero.state == FState.combo; i++) {
      await frames(tester, 1);
    }
    expect(hero.state, isNot(FState.combo));

    // A high block turns a head cut and a body blow, not a low sweep.
    hold(game, Dir.back, Dir.up);
    for (var i = 0; i < 20 && hero.guardZone != GuardZone.high; i++) {
      await frames(tester, 1);
    }
    expect(hero.combo, Combo.of(Dir.back, Dir.up));
    expect(hero.guardZone, GuardZone.high);
    expect(hero.guards(Zone.head), isTrue);
    expect(hero.guards(Zone.body), isTrue);
    expect(hero.guards(Zone.feet), isFalse);

    // A parry covers only the head, takes nothing and staggers the attacker.
    hold(game, Dir.back, Dir.upFwd);
    for (var i = 0; i < 40 && !hero.parrying; i++) {
      await frames(tester, 1);
    }
    expect(hero.parrying, isTrue);
    expect(hero.guards(Zone.head), isTrue);
    expect(hero.guards(Zone.body), isFalse);
    final hpBefore = hero.hp;
    v.startMove(MoveKind.high);
    for (var i = 0; i < 30 && !v.hitApplied; i++) {
      await frames(tester, 1);
    }
    expect(v.hitApplied, isTrue);
    expect(hero.hp, hpBefore);
    expect(v.stunned, isTrue);
    game.pauseEngine();
  });

  testWidgets('the dojo teaches every lesson and never knocks anyone out', (tester) async {
    final game = await bootGame(tester);
    game.startPractice(1);
    await untilPhase(tester, game, Phase.fighting);
    expect(game.practising, isTrue);
    expect(game.practice!.lesson.goal, LessonGoal.hit);
    final hero = game.hero;
    final v = game.villain!;
    expect(v.dummy, isTrue);
    hero.wx = -30;
    v.wx = 30;
    hero.zPos = v.zPos = 80;
    hold(game, Dir.fwd, Dir.fwd);
    for (var i = 0; i < 200 && !game.practice!.lessonDone; i++) {
      await frames(tester, 1);
    }
    expect(game.practice!.lessonDone, isTrue);
    // The dummy shrugs it off and the next lesson starts.
    expect(v.alive, isTrue);
    hold(game, null, null);
    for (var i = 0; i < 80 && game.practice!.index == 1; i++) {
      await frames(tester, 1);
    }
    expect(game.practice!.index, 2);
    // Quitting from sparring returns to the dojo, not the map.
    game.quitToMap();
    expect(game.overlays.isActive(ShadowGame.overlayDojo), isTrue);
    expect(game.practising, isFalse);
    game.pauseEngine();
  });

  test('every lesson names a goal players can finish', () {
    expect(Lesson.all.length, 9);
    for (final l in Lesson.all) {
      expect(l.target, greaterThan(0));
      expect(l.text, isNotEmpty);
    }
  });
}
