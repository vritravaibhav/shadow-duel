import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'shadow_game.dart';

/// One strip in assets/images/vfx.json.
class VfxSpec {
  const VfxSpec(this.file, this.fw, this.fh, this.n, this.fps, this.row);
  final String file;
  final int fw, fh, n, row;
  final double fps;
}

/// Plays a downloaded pixel-VFX strip once (or looped for [life] seconds)
/// at a world point, scaled up with nearest-neighbour sampling.
class VfxAnim extends PositionComponent with HasGameReference<ShadowGame> {
  VfxAnim(
    this.name, {
    required Vector2 at,
    this.scale_ = 3,
    this.flipX = false,
    this.additive = true,
    this.loop = false,
    this.life = 0,
    this.bottom = false,
    this.tint,
    int priority = 515,
  }) : super(position: at, priority: priority);

  final String name;
  final double scale_;
  final bool flipX, additive, loop, bottom;
  final double life;
  final Color? tint;

  VfxSpec? _spec;
  List<Sprite> _frames = const [];
  double _t = 0;

  @override
  Future<void> onLoad() async {
    final spec = game.sprites.vfx[name];
    if (spec == null) {
      assert(game.sprites.vfx.isEmpty, 'unknown vfx "$name"');
      removeFromParent();
      return;
    }
    _spec = spec;
    final img = game.images.fromCache(spec.file);
    _frames = [
      for (var i = 0; i < spec.n; i++)
        Sprite(img,
            srcPosition: Vector2(i * spec.fw.toDouble(), spec.row * spec.fh.toDouble()),
            srcSize: Vector2(spec.fw.toDouble(), spec.fh.toDouble())),
    ];
  }

  @override
  void update(double dt) {
    super.update(dt);
    final spec = _spec;
    if (spec == null) return;
    _t += dt;
    final done = loop ? _t >= life : _t * spec.fps >= spec.n;
    if (done) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final spec = _spec;
    if (spec == null || _frames.isEmpty) return;
    var i = (_t * spec.fps).floor();
    i = loop ? i % spec.n : i.clamp(0, spec.n - 1);
    final w = spec.fw * scale_, h = spec.fh * scale_;
    canvas.save();
    canvas.scale(flipX ? -1 : 1, 1);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..blendMode = additive ? BlendMode.plus : BlendMode.srcOver;
    if (tint != null) paint.colorFilter = ColorFilter.mode(tint!, BlendMode.modulate);
    _frames[i].render(canvas,
        position: Vector2(-w / 2, bottom ? -h : -h / 2), size: Vector2(w, h), overridePaint: paint);
    canvas.restore();
  }
}
