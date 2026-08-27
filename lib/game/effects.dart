import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

void drawText(
  Canvas c,
  String text,
  Offset center, {
  double size = 16,
  Color color = const Color(0xFFFFFFFF),
  FontWeight weight = FontWeight.w800,
  double letterSpacing = 2,
  double opacity = 1,
  double? glow,
  FontStyle style = FontStyle.normal,
}) {
  final base = TextStyle(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: style,
  );
  if (glow != null) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: base.copyWith(
          foreground: Paint()
            ..color = color.withValues(alpha: 0.8 * opacity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }
  final tp = TextPainter(
    text: TextSpan(text: text, style: base.copyWith(color: color.withValues(alpha: opacity))),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

class _Spark {
  _Spark(this.pos, this.vel, this.life, this.maxLife, this.len, this.w, this.color);
  Offset pos, vel;
  double life, maxLife, len, w;
  Color color;
}

class SparkBurst extends PositionComponent {
  SparkBurst({
    required Vector2 at,
    this.heavy = false,
    this.blocked = false,
    this.ko = false,
  }) : super(position: at, priority: 500);

  final bool heavy, blocked, ko;
  final List<_Spark> _sparks = [];
  double _t = 0;
  late final double _maxT;

  @override
  Future<void> onLoad() async {
    final rng = math.Random();
    final n = ko ? 26 : (heavy ? 18 : (blocked ? 8 : 12));
    final palette = blocked
        ? const [Color(0xFF6FB8FF), Color(0xFFBFE3FF)]
        : ko
            ? const [Color(0xFFFFFFFF), Color(0xFFFFD86B), Color(0xFFFF5A5A)]
            : heavy
                ? const [Color(0xFFFFD86B), Color(0xFFFF9D45), Color(0xFFFFFFFF)]
                : const [Color(0xFFFFFFFF), Color(0xFFFFE9A8)];
    for (var i = 0; i < n; i++) {
      final ang = rng.nextDouble() * math.pi * 2;
      final spd = 130 + rng.nextDouble() * (heavy || ko ? 330 : 240);
      final life = 0.22 + rng.nextDouble() * 0.24;
      _sparks.add(_Spark(
        Offset.zero,
        Offset(math.cos(ang), math.sin(ang) * .7) * spd,
        life,
        life,
        8 + rng.nextDouble() * 12,
        1.8 + rng.nextDouble() * 1.6,
        palette[rng.nextInt(palette.length)],
      ));
    }
    _maxT = ko ? .6 : .5;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel = Offset(s.vel.dx * (1 - 3 * dt), s.vel.dy * (1 - 3 * dt) + 300 * dt);
      s.life -= dt;
    }
    if (_t >= _maxT) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    // Impact flash.
    final flash = (1 - _t / 0.12).clamp(0.0, 1.0);
    if (flash > 0) {
      c.drawCircle(
        Offset.zero,
        (heavy || ko ? 26 : 16) * (1 + (1 - flash)),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: .6 * flash)
          ..blendMode = BlendMode.plus
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    // Expanding ring on heavy hits and KOs.
    if (heavy || ko) {
      final ra = (1 - _t / _maxT).clamp(0.0, 1.0);
      c.drawCircle(
        Offset.zero,
        14 + _t * (ko ? 340 : 220),
        Paint()
          ..color = (ko ? const Color(0xFFFF7B6B) : const Color(0xFFFFD86B))
              .withValues(alpha: .45 * ra)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * ra + .5
          ..blendMode = BlendMode.plus,
      );
    }
    for (final s in _sparks) {
      if (s.life <= 0) continue;
      final a = (s.life / s.maxLife).clamp(0.0, 1.0);
      final d = s.vel.distance;
      final dir = d == 0 ? const Offset(1, 0) : s.vel / d;
      c.drawLine(
        s.pos,
        s.pos - dir * s.len * a,
        Paint()
          ..color = s.color.withValues(alpha: a)
          ..strokeWidth = s.w * a + .4
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus,
      );
    }
  }
}

class DamagePopup extends PositionComponent {
  DamagePopup(Vector2 at, this.text, {this.big = false})
      : super(position: at, priority: 520);

  final String text;
  final bool big;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.y -= 46 * dt;
    if (_t > .7) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    final a = (1 - _t / .7).clamp(0.0, 1.0);
    final pop = 1 + (1 - (_t / .12).clamp(0.0, 1.0)) * .6;
    drawText(
      c,
      text,
      Offset.zero,
      size: (big ? 26 : 17) * pop,
      color: big ? const Color(0xFFFFB05A) : const Color(0xFFFFF2D9),
      opacity: a,
      letterSpacing: 1,
      glow: big ? 6 : null,
      style: FontStyle.italic,
    );
  }
}

class _Msg {
  _Msg(this.text, this.sub, this.life, this.color);
  final String text;
  final String? sub;
  final double life;
  final Color color;
}

class Announcer extends PositionComponent {
  Announcer() : super(priority: 30);

  final List<_Msg> _queue = [];
  _Msg? _current;
  double _t = 0;

  void show(String text, {String? sub, double life = 1.1, Color color = const Color(0xFFF5F0FF)}) {
    _queue.add(_Msg(text, sub, life, color));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_current == null && _queue.isNotEmpty) {
      _current = _queue.removeAt(0);
      _t = 0;
    }
    if (_current != null) {
      _t += dt;
      if (_t > _current!.life + 0.3) _current = null;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final c = canvas;
    final m = _current;
    if (m == null) return;
    final fadeIn = (_t / .14).clamp(0.0, 1.0);
    final fadeOut = (1 - (_t - m.life) / .3).clamp(0.0, 1.0);
    final a = math.min(fadeIn, fadeOut);
    final ease = 1 - math.pow(1 - fadeIn, 3).toDouble();
    final scale = 1.35 - .35 * ease;
    c.save();
    c.translate(480, 190);
    c.scale(scale, scale);
    drawText(c, m.text, Offset.zero,
        size: 56, color: m.color, letterSpacing: 10, opacity: a, glow: 10, style: FontStyle.italic);
    if (m.sub != null) {
      drawText(c, m.sub!, const Offset(0, 46),
          size: 16, color: const Color(0xFFCFC8DC), letterSpacing: 4, opacity: a * .9);
    }
    c.restore();
  }
}
