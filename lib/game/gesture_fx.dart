import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'effects.dart';
import 'gestures.dart';
import 'shadow_game.dart';

class _Spark {
  _Spark(this.pos, this.vel, this.life, this.color);
  Offset pos, vel;
  double life;
  final Color color;
}

class _Flash {
  _Flash(this.points, this.color, this.label, this.ok);
  final List<Offset> points;
  final Color color;
  final String label;
  final bool ok;
  double t = 0;
}

/// The effect shown when a drawn glyph is read: a clean V or W emblem bursts
/// where the stroke was, with the art's name. The finger path itself is
/// never drawn.
class GestureTrail extends PositionComponent with HasGameReference<ShadowGame> {
  GestureTrail() : super(priority: 40);

  final List<_Spark> _sparks = [];
  final List<_Flash> _flashes = [];
  final _rng = math.Random();

  Color get _color => game.hero.weapon.trail.withValues(alpha: 1);

  /// Show the emblem for [kind] inside [box] (the stroke's bounds).
  void flash(GestureKind kind, Rect box, {required String label, required bool ok}) {
    final r = _fit(box);
    final pts = kind == GestureKind.glyphW
        ? [
            r.topLeft,
            Offset(r.left + r.width * .25, r.bottom),
            Offset(r.center.dx, r.top + r.height * .38),
            Offset(r.right - r.width * .25, r.bottom),
            r.topRight,
          ]
        : [r.topLeft, Offset(r.center.dx, r.bottom), r.topRight];
    final col = ok ? _color : const Color(0xFFB0B4C8);
    _flashes.add(_Flash(pts, col, label, ok));
    if (!ok) return;
    for (var i = 0; i < pts.length - 1; i++) {
      for (var k = 0; k < 10; k++) {
        final p = pts[i] + (pts[i + 1] - pts[i]) * (k / 10);
        final a = _rng.nextDouble() * math.pi * 2;
        _sparks.add(_Spark(p, Offset(math.cos(a), math.sin(a)) * (80 + _rng.nextDouble() * 180),
            .35 + _rng.nextDouble() * .3, k.isEven ? const Color(0xFFFFFFFF) : col));
      }
    }
  }

  /// A tidy emblem box: at least 90 px tall, kept clear of the top HUD.
  Rect _fit(Rect box) {
    final h = math.max(90.0, math.min(220.0, box.height));
    final w = math.max(h * .9, math.min(260.0, box.width));
    final cx = box.center.dx.clamp(w / 2 + 12, kW - w / 2 - 12);
    final cy = box.center.dy.clamp(150 + h / 2, kH - 110 - h / 2);
    return Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel = s.vel * (1 - 4 * dt) + Offset(0, 220 * dt);
      s.life -= dt;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    for (final f in _flashes) {
      f.t += dt;
    }
    _flashes.removeWhere((f) => f.t > 0.95);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final s in _sparks) {
      canvas.drawCircle(
        s.pos,
        1.5 + s.life * 4,
        Paint()
          ..color = s.color.withValues(alpha: (s.life * 2.5).clamp(0.0, 1.0))
          ..blendMode = BlendMode.plus,
      );
    }
    for (final f in _flashes) {
      _renderFlash(canvas, f);
    }
  }

  void _renderFlash(Canvas canvas, _Flash f) {
    final grow = (f.t / 0.16).clamp(0.0, 1.0);
    final fade = (1 - (f.t - 0.4) / 0.55).clamp(0.0, 1.0);
    final scale = 0.7 + 0.3 * (1 - math.pow(1 - grow, 3));
    final xs = f.points.map((p) => p.dx);
    final ys = f.points.map((p) => p.dy);
    final cx = (xs.reduce(math.min) + xs.reduce(math.max)) / 2;
    final cy = (ys.reduce(math.min) + ys.reduce(math.max)) / 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale, scale);
    canvas.translate(-cx, -cy);
    final path = Path()..moveTo(f.points.first.dx, f.points.first.dy);
    for (final p in f.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus;
    canvas.drawPath(path, stroke
      ..color = f.color.withValues(alpha: .28 * fade)
      ..strokeWidth = 34);
    canvas.drawPath(path, stroke
      ..color = f.color.withValues(alpha: .9 * fade)
      ..strokeWidth = 10);
    canvas.drawPath(path, stroke
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .95 * fade)
      ..strokeWidth = 3);
    canvas.restore();

    final size = f.ok ? 20.0 : 15.0;
    final labelW = f.label.length * size * .72 + 24;
    final lx = cx.clamp(labelW / 2 + 8, kW - labelW / 2 - 8);
    final top = ys.reduce(math.min);
    final bottom = ys.reduce(math.max);
    final ly = top - 30 > 150 ? top - 30 : math.min(kH - 120, bottom + 30);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(lx, ly), width: labelW, height: size + 14),
          const Radius.circular(8)),
      Paint()..color = const Color(0xFF0E0F1A).withValues(alpha: .72 * fade),
    );
    drawText(canvas, f.label, Offset(lx, ly),
        size: size,
        color: f.ok ? f.color : const Color(0xFFCFD3E6),
        letterSpacing: 4,
        opacity: fade,
        glow: f.ok ? 8 : null,
        style: FontStyle.italic);
  }
}
