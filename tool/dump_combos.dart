// Writes docs/combos.json: the 64 combos with names, inputs, effects and
// the strips each one's composed clip uses. Run with:
//
//     flutter test tool/dump_combos.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/combos.dart';

void main() {
  test('dump the combo table', () {
    final rows = [
      for (final c in Combo.all)
        {
          'id': c.id,
          'name': c.name,
          'kind': c.kind.name,
          'left': c.left.id,
          'right': c.right.id,
          'leftGlyph': c.left.glyph(),
          'rightGlyph': c.right.glyph(),
          'desc': c.desc,
          'zone': c.kind == ComboKind.attack ? c.zoneName : null,
          'guard': c.kind == ComboKind.attack ? null : c.guardName,
          'parry': c.parry,
          'smash': c.isSmash,
          'clip': {
            for (final s in ComboStage.values)
              s.name: [
                for (final p in ComboClip.recipe(c).stage(s))
                  {
                    'anim': p.anim,
                    'speed': p.speed,
                    'reverse': p.reverse,
                    'from': p.from,
                    'to': p.to,
                    'hop': p.hop,
                    'dx': p.dx,
                    'lean': p.lean,
                    'squash': p.squash,
                    'hold': p.hold,
                    'strike': p.strike,
                  },
              ],
          },
        },
    ];
    File('docs/combos.json').writeAsStringSync(const JsonEncoder.withIndent(' ').convert(rows));
  });
}
