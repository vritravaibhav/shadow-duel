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
    this.palette,
  }) : super(position: at, priority: 500);

  final bool heavy, blocked, ko;
  final List<Color>? palette;
  final List<_Spark> _sparks = [];
  double _t = 0;
  late final double _maxT;

  @override
  Future<void> onLoad() async {
    final rng = math.Random();
    final n = ko ? 26 : (heavy ? 18 : (blocked ? 8 : 12));
    final palette = this.palette ??
        (blocked
        ? const [Color(0xFF6FB8FF), Color(0xFFBFE3FF)]
        : ko
            ? const [Color(0xFFFFFFFF), Color(0xFFFFD86B), Color(0xFFFF5A5A)]
            : heavy
                ? const [Color(0xFFFFD86B), Color(0xFFFF9D45), Color(0xFFFFFFFF)]
                : const [Color(0xFFFFFFFF), Color(0xFFFFE9A8)]);
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


/// Expanding ground shockwave (Earthsplitter), drawn as an iso ellipse.
class RingWave extends PositionComponent {
  RingWave({required Vector2 at, required this.color, this.maxR = 280, this.life = .6})
      : super(position: at, priority: 480);
  final Color color;
  final double maxR, life;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final k = (_t / life).clamp(0.0, 1.0);
    final r = 20 + (maxR - 20) * (1 - math.pow(1 - k, 2));
    final rect = Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * .55);
    canvas.drawOval(rect, Paint()
      ..color = color.withValues(alpha: .35 * (1 - k))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18 * (1 - k) + 2
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawOval(rect, Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .8 * (1 - k))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * (1 - k) + .5
      ..blendMode = BlendMode.plus);
    // Debris.
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2;
      final d = Offset(math.cos(a) * r, math.sin(a) * r * .28 - k * 60);
      canvas.drawCircle(d, 3 * (1 - k) + .5,
          Paint()..color = color.withValues(alpha: .9 * (1 - k))..blendMode = BlendMode.plus);
    }
  }
}

/// A forked lightning strike from the sky onto a point (Thunderclap).
class LightningBolt extends PositionComponent {
  LightningBolt({required Vector2 from, required Vector2 to, required this.color, this.life = .5})
      : _from = from.toOffset(), super(position: to, priority: 520);
  final Color color;
  final double life;
  final Offset _from;
  final _rng = math.Random();
  double _t = 0, _since = 0;
  List<Offset> _bolt = const [];

  @override
  Future<void> onLoad() async {
    _rebolt();
  }

  void _rebolt() {
    final start = _from - position.toOffset();
    const n = 9;
    _bolt = [
      for (var i = 0; i <= n; i++)
        Offset(
          start.dx + (0 - start.dx) * i / n + (i == 0 || i == n ? 0 : (_rng.nextDouble() * 2 - 1) * 34),
          start.dy + (0 - start.dy) * i / n,
        ),
    ];
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    _since += dt;
    if (_since > 0.06) {
      _since = 0;
      _rebolt();
    }
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final a = (1 - _t / life).clamp(0.0, 1.0);
    final path = Path()..moveTo(_bolt.first.dx, _bolt.first.dy);
    for (final p in _bolt.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: .55 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.plus);
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..blendMode = BlendMode.plus);
    canvas.drawCircle(Offset.zero, 30 + (1 - a) * 40, Paint()
      ..color = color.withValues(alpha: .5 * a)
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
  }
}

class _Ember {
  _Ember(this.pos, this.vel, this.life, this.max, this.r);
  Offset pos, vel;
  double life;
  final double max, r;
}

/// A cone of fire breathed toward [dir] (Dragon's Breath).
class FireCone extends PositionComponent {
  FireCone({required Vector2 at, required this.dir, this.duration = .4})
      : super(position: at, priority: 510);
  final int dir;
  final double duration;
  final _rng = math.Random();
  final List<_Ember> _embers = [];
  double _t = 0, _spawnAcc = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t < duration) {
      _spawnAcc += dt * 150;
      while (_spawnAcc >= 1) {
        _spawnAcc -= 1;
        final spread = (_rng.nextDouble() - .5) * .9;
        final spd = 340 + _rng.nextDouble() * 260;
        _embers.add(_Ember(
          Offset(dir * 20.0, (_rng.nextDouble() - .5) * 14),
          Offset(math.cos(spread) * spd * dir, math.sin(spread) * spd * .5 - 30),
          .45 + _rng.nextDouble() * .3, .75, 8 + _rng.nextDouble() * 12,
        ));
      }
    }
    for (final e in _embers) {
      e.pos += e.vel * dt;
      e.vel = Offset(e.vel.dx * (1 - 1.6 * dt), e.vel.dy - 40 * dt);
      e.life -= dt;
    }
    _embers.removeWhere((e) => e.life <= 0);
    if (_t > duration && _embers.isEmpty) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final e in _embers) {
      final k = (e.life / e.max).clamp(0.0, 1.0);
      final col = Color.lerp(const Color(0xFFFF4A1F), const Color(0xFFFFE07A), k)!;
      canvas.drawCircle(e.pos, e.r * (0.5 + k), Paint()
        ..color = col.withValues(alpha: .28 * k)
        ..blendMode = BlendMode.plus);
      canvas.drawCircle(e.pos, e.r * (0.25 + k * .5), Paint()
        ..color = col.withValues(alpha: .8 * k)
        ..blendMode = BlendMode.plus);
    }
  }
}

/// A fading, tinted copy of a fighter's current frame (dash ghosts).
class AfterImage extends PositionComponent {
  AfterImage({
    required Vector2 at,
    required this.sprite,
    required this.offset,
    required this.size_,
    required this.sx,
    required this.sy,
    required this.color,
    this.life = .38,
    this.pixel = true,
  }) : super(position: at, priority: 260);
  final Sprite sprite;
  final Vector2 offset, size_;
  final double sx, sy, life;
  final Color color;
  final bool pixel;
  double _t = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= life) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final a = (1 - _t / life).clamp(0.0, 1.0);
    canvas.save();
    canvas.scale(sx, sy);
    sprite.render(canvas,
        position: offset,
        size: size_,
        overridePaint: Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: .7 * a)
          ..colorFilter = ColorFilter.mode(color.withValues(alpha: .85), BlendMode.srcATop)
          ..filterQuality = pixel ? FilterQuality.none : FilterQuality.medium);
    canvas.restore();
  }
}
