import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/combos.dart';

void main() {
  test('probe', () {
    // 1. sector coverage: sweep 0..360 for both facings, no prev
    for (final face in [1, -1]) {
      final hits = <Dir, List<double>>{};
      for (var deg = 0.0; deg < 360; deg += 0.25) {
        final rad = deg * math.pi / 180;
        // physical stick offset (screen space, y down)
        final v = Vector2(math.cos(rad), math.sin(rad));
        final d = Dir.decode(v, face);
        hits.putIfAbsent(d!, () => []).add(deg);
      }
      print('face=$face sectors hit=${hits.length}');
      for (final e in hits.entries) {
        final l = e.value;
        print('  ${e.key.id}: ${l.length} samples ${l.first}..${l.last} span=${l.length*0.25}');
      }
    }
    // 2. Combo.of indexing round trip
    for (final l in Dir.values) {
      for (final r in Dir.values) {
        final c = Combo.of(l, r);
        if (c.left != l || c.right != r) print('MISMATCH $l $r -> $c');
      }
    }
    // 3. hysteresis: from every prev, which dirs are reachable at any angle?
    for (final prev in Dir.values) {
      final reach = <Dir>{};
      for (var deg = 0.0; deg < 360; deg += 0.25) {
        final rad = deg * math.pi / 180;
        final v = Vector2(math.cos(rad), math.sin(rad));
        reach.add(Dir.decode(v, 1, prev: prev)!);
      }
      print('prev=${prev.id} -> reachable ${reach.map((d)=>d.id).toList()}');
    }
  });
}
