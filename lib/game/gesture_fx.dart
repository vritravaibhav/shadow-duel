import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'effects.dart';
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

/// The sword-stroke trail that follows the finger on the right half of the
/// screen, plus the glyph flash when a drawn V / W fires a sword art.
class GestureTrail extends PositionComponent with HasGameReference<ShadowGame> {
  GestureTrail() : super(priority: 40);

  static const trailLife = 0.32;
  final List<(Offset, double)> _trail = [];
  final List<_Spark> _sparks = [];
  final List<_Flash> _flashes = [];
  final _rng = math.Random();
  bool _down = false;
  double _released = 0;

  Color get _color => game.hero.weapon.trail.withValues(alpha: 1);

  void begin(Offset p) {
    _down = true;
    _trail
      ..clear()
      ..add((p, game.t));
  }

  void extend(Offset p) {
    if (!_down) return;
    if (_trail.isNotEmpty && (p - _trail.last.$1).distance < 3) return;
    _trail.add((p, game.t));
    for (var i = 0; i < 2; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      _sparks.add(_Spark(
        p,
        Offset(math.cos(a), math.sin(a)) * (40 + _rng.nextDouble() * 90),
        .25 + _rng.nextDouble() * .2,
        _rng.nextBool() ? _color : const Color(0xFFFFFFFF),
      ));
    }
  }

  void end() {
    _down = false;
    _released = game.t;
  }

  /// Re-draw the recognised glyph as a bright stroke with a label.
  void flash(List<Offset> points, {required String label, required bool ok}) {
    _flashes.add(_Flash(List.of(points), ok ? _color : const Color(0xFFB0B4C8), label, ok));
    if (ok) {
      for (final p in points) {
        for (var i = 0; i < 3; i++) {
          final a = _rng.nextDouble() * math.pi * 2;
          _sparks.add(_Spark(p, Offset(math.cos(a), math.sin(a)) * (80 + _rng.nextDouble() * 160),
              .35 + _rng.nextDouble() * .25, i == 0 ? const Color(0xFFFFFFFF) : _color));
        }
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    // The whole stroke stays visible while the finger is down; it fades as
    // one shape after release.
    if (!_down && game.t - _released > trailLife) _trail.clear();
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel = s.vel * (1 - 4 * dt) + Offset(0, 220 * dt);
      s.life -= dt;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    for (final f in _flashes) {
      f.t += dt;
    }
    _flashes.removeWhere((f) => f.t > 0.9);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderTrail(canvas);
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

  void _renderTrail(Canvas canvas) {
    if (_trail.length < 2) return;
    final c = _color;
    final n = _trail.length;
    final fade = _down ? 0.0 : ((game.t - _released) / trailLife).clamp(0.0, 1.0);
    final glow = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus;
    final blade = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus;
    final core = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.plus;
    // One wide translucent pass reads as a glow without a blur filter.
    for (var i = 0; i < n - 1; i++) {
      final (p1, _) = _trail[i];
      final (p2, _) = _trail[i + 1];
      final k = (i + 1) / n; // 0 tail .. 1 head
      final width = (2.5 + 7.5 * k) * (1 - fade * .7);
      canvas.drawLine(p1, p2, glow
        ..color = c.withValues(alpha: .22 * (1 - fade))
        ..strokeWidth = width * 2.4);
      canvas.drawLine(p1, p2, blade
        ..color = c.withValues(alpha: .9 * (1 - fade))
        ..strokeWidth = width);
      canvas.drawLine(p1, p2, core
        ..color = const Color(0xFFFFFFFF).withValues(alpha: (.35 + .55 * k) * (1 - fade))
        ..strokeWidth = width * .3);
    }
  }

  void _renderFlash(Canvas canvas, _Flash f) {
    final grow = (f.t / 0.18).clamp(0.0, 1.0);
    final fade = (1 - (f.t - 0.35) / 0.55).clamp(0.0, 1.0);
    final path = Path()..moveTo(f.points.first.dx, f.points.first.dy);
    for (final p in f.points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final glow = 10 + grow * 22;
    canvas.drawPath(path, Paint()
      ..color = f.color.withValues(alpha: .55 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + grow * 10));
    canvas.drawPath(path, Paint()
      ..color = f.color.withValues(alpha: fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus);
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus);
    final xs = f.points.map((p) => p.dx);
    final ys = f.points.map((p) => p.dy);
    final top = ys.reduce(math.min), bottom = ys.reduce(math.max);
    final size = f.ok ? 20.0 : 15.0;
    final labelW = f.label.length * size * .72 + 24;
    // Keep the label on screen and off the HUD: below the glyph when the
    // glyph sits high, otherwise above it.
    final cx = ((xs.reduce(math.min) + xs.reduce(math.max)) / 2)
        .clamp(kW / 2 + labelW / 2, kW - labelW / 2 - 8);
    final above = top - 26 - grow * 6;
    final y = above < 150 ? math.min(kH - 120, bottom + 30 + grow * 6) : above;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y), width: labelW, height: size + 14),
          const Radius.circular(8)),
      Paint()..color = const Color(0xFF0E0F1A).withValues(alpha: .72 * fade),
    );
    drawText(canvas, f.label, Offset(cx, y),
        size: size,
        color: f.ok ? f.color : const Color(0xFFCFD3E6),
        letterSpacing: 4,
        opacity: fade,
        glow: f.ok ? 8 : null,
        style: FontStyle.italic);
  }
}
