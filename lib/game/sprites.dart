import 'dart:convert';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'vfx.dart';
import 'weapons.dart';

/// One animation strip from assets/images plus its atlas data.
class BakedAnim {
  BakedAnim({
    required this.frames,
    required this.duration,
    required this.loop,
    required this.fw,
    required this.fh,
    required this.ax,
    required this.ay,
    required this.scale,
    required this.hand,
    this.tip,
    this.flip = false,
    this.pixel = false,
  });

  final List<Sprite> frames;
  final double duration;
  final bool loop;

  /// Frame size and feet anchor in sheet pixels; [scale] is pixels per game unit.
  final double fw, fh, ax, ay, scale;

  /// Per-frame lead-hand attachment [x, y, angleRad] in game units (facing
  /// +x). Empty for packs whose weapons are painted into the art.
  final List<List<double>> hand;

  /// Per-frame weapon-tip point [x, y] in game units facing +x (attack anims).
  final List<List<double>>? tip;

  /// The art faces left natively and must be mirrored to face +x.
  final bool flip;

  /// Pixel art: render with nearest-neighbour sampling.
  final bool pixel;

  int frameAt(double u, {bool reverse = false}) {
    final n = frames.length;
    int i;
    if (loop) {
      i = (((u % 1) + 1) % 1 * n).floor().clamp(0, n - 1);
    } else {
      i = (u * (n - 1)).round().clamp(0, n - 1);
    }
    return reverse ? n - 1 - i : i;
  }
}

class WeaponArt {
  WeaponArt(this.sprite, this.w, this.h, this.gx, this.gy, this.scale);
  final Sprite sprite;
  final double w, h, gx, gy, scale;
}

/// Loads assets/images/meta.json (icons, arena), assets/images/packs.json
/// (imported character packs), the sword icons and the UI pieces.
class SpriteLibrary {
  SpriteLibrary._(this.chars, this.builds, this.portraits, this.weapons,
      this.icons, this.swordIcons, this.ui, this.arena, this.vfx);

  final Map<String, Map<String, BakedAnim>> chars;

  /// Relative body size per character (drives the ground shadow).
  final Map<String, double> builds;
  final Map<String, Sprite> portraits;
  final Map<String, WeaponArt> weapons;
  final Map<String, Sprite> icons;
  final Map<String, Sprite> swordIcons;
  final Map<String, Sprite> ui;
  final Sprite arena;

  /// Downloaded pixel VFX strips (assets/images/vfx.json).
  final Map<String, VfxSpec> vfx;

  static const uiNames = [
    'card_grey', 'card_blue', 'card_red', 'card_yellow', 'card_green',
    'button_grey', 'button_blue', 'node_grey', 'node_blue', 'node_yellow',
    'bar_grey', 'bar_blue', 'icon_locked', 'icon_star', 'icon_pause',
  ];

  BakedAnim anim(String char, String name) => chars[char]![name]!;

  static Future<SpriteLibrary> load(Images images) async {
    final meta = jsonDecode(await rootBundle.loadString('assets/images/meta.json'))
        as Map<String, dynamic>;
    final packs = jsonDecode(await rootBundle.loadString('assets/images/packs.json'))
        as Map<String, dynamic>;

    final chars = <String, Map<String, BakedAnim>>{};
    final builds = <String, double>{};
    final portraits = <String, Sprite>{};
    for (final src in [meta, packs]) {
      final defaultScale = (src['scale'] as num?)?.toDouble() ?? 1.0;
      for (final ch in (src['chars'] as Map<String, dynamic>).entries) {
        final anims = <String, BakedAnim>{};
        for (final a in (ch.value as Map<String, dynamic>).entries) {
          if (a.key == 'build') {
            builds[ch.key] = (a.value as num).toDouble();
            continue;
          }
          anims[a.key] =
              await _readAnim(a.value as Map<String, dynamic>, defaultScale, images);
        }
        chars[ch.key] = anims;
      }
      for (final p in (src['portraits'] as Map<String, dynamic>).entries) {
        portraits[p.key] = Sprite(await images.load(p.value as String));
      }
    }

    final weapons = <String, WeaponArt>{};
    for (final w in (meta['weapons'] as Map<String, dynamic>).entries) {
      final m = w.value as Map<String, dynamic>;
      weapons[w.key] = WeaponArt(
        Sprite(await images.load(m['file'] as String)),
        (m['w'] as num).toDouble(),
        (m['h'] as num).toDouble(),
        (m['gx'] as num).toDouble(),
        (m['gy'] as num).toDouble(),
        (m['scale'] as num).toDouble(),
      );
    }

    final icons = <String, Sprite>{};
    for (final ic in (meta['icons'] as Map<String, dynamic>).entries) {
      icons[ic.key] = Sprite(await images.load(ic.value as String));
    }

    final swordIcons = <String, Sprite>{};
    for (final s in Swords.all) {
      swordIcons[s.id] = Sprite(await images.load('swords/${s.icon}.png'));
    }

    final ui = <String, Sprite>{};
    for (final n in uiNames) {
      ui[n] = Sprite(await images.load('ui/$n.png'));
    }

    final arena =
        Sprite(await images.load((meta['arena'] as Map)['file'] as String));

    // Only a missing atlas is tolerated (effects fall back to the drawn
    // versions); a broken entry or PNG must fail loudly.
    String? vfxJson;
    try {
      vfxJson = await rootBundle.loadString('assets/images/vfx.json');
    } on FlutterError {
      vfxJson = null;
    }
    final vfx = <String, VfxSpec>{};
    if (vfxJson != null) {
      final vmeta = jsonDecode(vfxJson) as Map<String, dynamic>;
      for (final e in vmeta.entries) {
        final m = e.value as Map<String, dynamic>;
        await images.load(m['file'] as String);
        vfx[e.key] = VfxSpec(m['file'] as String, (m['fw'] as num).toInt(), (m['fh'] as num).toInt(),
            (m['n'] as num).toInt(), (m['fps'] as num).toDouble(), (m['row'] as num).toInt());
      }
    }

    return SpriteLibrary._(
        chars, builds, portraits, weapons, icons, swordIcons, ui, arena, vfx);
  }

  static Future<BakedAnim> _readAnim(
      Map<String, dynamic> m, double defaultScale, Images images) async {
    final img = await images.load(m['file'] as String);
    final n = m['n'] as int;
    final fw = (m['fw'] as num).toDouble();
    final fh = (m['fh'] as num).toDouble();
    List<List<double>> pairs(dynamic v) => [
          for (final f in (v as List?) ?? const [])
            [for (final x in f as List) (x as num).toDouble()],
        ];
    return BakedAnim(
      frames: [
        for (var i = 0; i < n; i++)
          Sprite(img, srcPosition: Vector2(i * fw, 0), srcSize: Vector2(fw, fh)),
      ],
      duration: (m['dur'] as num).toDouble(),
      loop: m['loop'] as bool,
      fw: fw,
      fh: fh,
      ax: (m['ax'] as num).toDouble(),
      ay: (m['ay'] as num).toDouble(),
      scale: (m['scale'] as num?)?.toDouble() ?? defaultScale,
      hand: pairs(m['hand']),
      tip: m['tip'] == null ? null : pairs(m['tip']),
      flip: (m['flip'] as bool?) ?? false,
      pixel: (m['pixel'] as bool?) ?? false,
    );
  }
}
