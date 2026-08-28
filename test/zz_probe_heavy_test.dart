import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/fighter.dart';
import 'package:shadow_duel/game/shadow_game.dart';
import 'package:shadow_duel/game/weapons.dart';

import 'helpers.dart';

/// Drive one fighter's swing frame-by-frame with the target's guard held.
Future<({double dmg, bool blocked, bool crit})> swing(
  ShadowGame game, Fighter from, Fighter to, MoveKind k, GuardZone g) async {
  to.hp = to.maxHp;
  to.h = 0; to.vh = 0; to.kvx = 0; to.state = FState.idle; to.stateT = 0; to.stunT = 0;
  to.blockFlashT = 0; to.flashT = 0;
  from.state = FState.idle; from.stateT = 0; from.h = 0; from.vh = 0; from.kvx = 0; from.stunT = 0;
  from.wx = to.wx - 50 * from.facing; from.zPos = to.zPos;
  final before = to.hp;
  from.startMove(k);
  expect(from.state, FState.attack, reason: 'swing $k should start');
  var blocked = false;
  for (var i = 0; i < 200 && from.state == FState.attack; i++) {
    to.guardZone = g;
    from.update(0.01);
    if (to.blockFlashT > 0) blocked = true;
  }
  final dmg = before - to.hp;
  return (dmg: dmg, blocked: blocked, crit: false);
}

void main() {
  testWidgets('probe: heavy vs guards, per blade; villain heavy vs hero high guard', (tester) async {
    final game = await bootGame(tester);
    game.startStage(3);
    await untilPhase(tester, game, Phase.fighting);
    final hero = game.hero;
    final v = game.villain!;
    v.maxHp = 100000; v.hp = v.maxHp;
    hero.facing = 1; v.facing = -1;
    print('stage3 cfg hp=${game.stageCfg(3).hp} dmg=${game.stageCfg(3).dmg}');
    for (final s in [1,3,16,17,29,43]) { final c = game.stageCfg(s); print('stage $s: hp=${c.hp} dmg=${c.dmg}'); }

    // Hero heavy / high / slash vs villain HIGH and LOW guard, each blade.
    for (final sw in Swords.all) {
      hero.setWeapon(sw.weapon);
      final hv = hero.moves[MoveKind.heavy]!;
      final out = <String>[];
      for (final g in [GuardZone.none, GuardZone.high, GuardZone.low]) {
        final r = await swing(game, hero, v, MoveKind.heavy, g);
        out.add('heavy/${g.name}=${r.dmg.toStringAsFixed(1)}${r.blocked ? "(BLK)" : ""}');
      }
      // head cut (high) vs high guard, min over 20 trials to see block value
      final rHigh = await swing(game, hero, v, MoveKind.high, GuardZone.high);
      out.add('high/high=${rHigh.dmg.toStringAsFixed(1)}${rHigh.blocked ? "(BLK)" : ""}');
      final rSlash = await swing(game, hero, v, MoveKind.slash, GuardZone.high);
      out.add('slash/high=${rSlash.dmg.toStringAsFixed(1)}${rSlash.blocked ? "(BLK)" : ""}');
      // heavy repeated 5 times: any variance? (should be constant if crit is guaranteed)
      final reps = <double>[];
      for (var i = 0; i < 5; i++) reps.add((await swing(game, hero, v, MoveKind.heavy, GuardZone.high)).dmg);
      print('${sw.name.padRight(15)} base=${hv.dmg.toStringAsFixed(2)} dur=${hv.duration.toStringAsFixed(3)}s '
            'slashDur=${hero.moves[MoveKind.slash]!.duration.toStringAsFixed(3)}s  ${out.join("  ")}  reps=$reps');
    }

    // Draconic rage x1.6
    hero.setWeapon(Swords.byId('dragon').weapon);
    hero.rageT = 6;
    final rage = await swing(game, hero, v, MoveKind.heavy, GuardZone.high);
    print('DRAGON heavy under rage vs high guard = ${rage.dmg.toStringAsFixed(1)} blocked=${rage.blocked}');
    hero.rageT = 0;

    // Villain heavy vs hero HIGH guard (hero idle) — several stages' dmgScale.
    hero.maxHp = 100000;
    for (final s in [1, 3, 6, 17, 43]) {
      v.dmgScale = game.stageCfg(s).dmg;
      final rv = await swing(game, v, hero, MoveKind.heavy, GuardZone.high);
      final rvSlash = await swing(game, v, hero, MoveKind.slash, GuardZone.high);
      print('villain(stage $s dmg x${v.dmgScale.toStringAsFixed(2)}) heavy vs hero HIGH guard = ${rv.dmg.toStringAsFixed(1)} blocked=${rv.blocked}; slash vs high = ${rvSlash.dmg.toStringAsFixed(1)} blocked=${rvSlash.blocked}');
    }
    game.pauseEngine();
  });
}
