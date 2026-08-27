// Bakes the game's own small art — weapon sprites, HUD icons, and the arena
// backdrop — to PNG files under assets/images/ plus meta.json. Character
// sprites come from downloaded packs instead (see tool/import_packs.py).
//
//   flutter test tool/bake_sprites_test.dart
//
// It is outside test/ on purpose so `flutter test` doesn't rebake on every run.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_painter.dart';
import 'weapon_painter.dart';

const weaponScale = 4.0; // weapons are small; bake them at 4x
const outDir = 'assets/images';

Future<void> writePng(ui.Picture pic, int w, int h, String path) async {
  final img = await pic.toImage(w, h);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('bake weapon, icon and arena assets', () async {
    final meta = <String, dynamic>{
      'chars': <String, dynamic>{},
      'portraits': <String, dynamic>{},
      'weapons': <String, dynamic>{},
      'icons': <String, dynamic>{},
      'arena': {'file': 'arena.png', 'scale': 2},
    };

    // Weapons: blade along +x, grip at the origin.
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..translate(13 * weaponScale, 8 * weaponScale)
        ..scale(weaponScale);
      paintKatana(c);
      await writePng(rec.endRecording(), (79 * weaponScale).toInt(),
          (16 * weaponScale).toInt(), '$outDir/weapons/katana.png');
      (meta['weapons'] as Map<String, dynamic>)['katana'] = {
        'file': 'weapons/katana.png',
        'w': 79 * weaponScale,
        'h': 16 * weaponScale,
        'gx': 13 * weaponScale,
        'gy': 8 * weaponScale,
        'scale': weaponScale,
      };
    }
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..translate(10 * weaponScale, 20 * weaponScale)
        ..scale(weaponScale);
      paintAxe(c);
      await writePng(rec.endRecording(), (67 * weaponScale).toInt(),
          (40 * weaponScale).toInt(), '$outDir/weapons/axe.png');
      (meta['weapons'] as Map<String, dynamic>)['axe'] = {
        'file': 'weapons/axe.png',
        'w': 67 * weaponScale,
        'h': 40 * weaponScale,
        'gx': 10 * weaponScale,
        'gy': 20 * weaponScale,
        'scale': weaponScale,
      };
    }

    // HUD icons.
    for (final name in ['fists', 'katana', 'axe']) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.save();
      c.translate(48, 48);
      paintIcon(c, name, 88);
      c.restore();
      await writePng(rec.endRecording(), 96, 96, '$outDir/weapons/${name}_icon.png');
      (meta['icons'] as Map<String, dynamic>)[name] = 'weapons/${name}_icon.png';
    }

    // Arena backdrop at 2x.
    {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)
        ..scale(2)
        ..translate(500, 290);
      paintArena(c);
      await writePng(rec.endRecording(), 2000, 1160, '$outDir/arena.png');
    }

    File('$outDir/meta.json').writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(meta));
  });
}
