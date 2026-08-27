// Asset-pipeline painter: renders the static arena backdrop (sky, moon,
// mountains, torii, pagoda, iso floor) once. The baker writes it to
// assets/images/arena.png; only fog and leaves stay dynamic in-game.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Paints in world coordinates: x -500..500, y -290..290 (floor top at 96).
void paintArena(Canvas c) {
  const left = -500.0, right = 500.0, top = -290.0, bottom = 290.0;
  const floorTop = 96.0;

  // Dusk sky.
  c.drawRect(
    const Rect.fromLTRB(left, top, right, floorTop),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, top),
        const Offset(0, floorTop),
        const [Color(0xFF07071A), Color(0xFF251034), Color(0xFF4A1D2E)],
        const [0.0, 0.6, 1.0],
      ),
  );

  // Stars.
  final rng = math.Random(7);
  for (var i = 0; i < 42; i++) {
    final p = Offset(
      left + rng.nextDouble() * 1000,
      top + rng.nextDouble() * (floorTop - top - 90),
    );
    final a = 0.2 + rng.nextDouble() * 0.4;
    c.drawCircle(p, i % 5 == 0 ? 1.4 : 0.9,
        Paint()..color = const Color(0xFFFFF6E0).withValues(alpha: a));
  }

  // Moon.
  const moonC = Offset(252, -152);
  c.drawCircle(
    moonC,
    86,
    Paint()
      ..color = const Color(0xFFFFE9C4).withValues(alpha: .14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
  );
  c.drawCircle(moonC, 50, Paint()..color = const Color(0xFFF5E3C0));
  c.drawCircle(const Offset(238, -166), 9,
      Paint()..color = const Color(0xFF000000).withValues(alpha: .05));
  c.drawCircle(const Offset(266, -140), 6,
      Paint()..color = const Color(0xFF000000).withValues(alpha: .05));

  // Mountain layers.
  final far = Path()
    ..moveTo(left, floorTop)
    ..lineTo(left, 46)
    ..lineTo(-330, 8)
    ..lineTo(-180, 52)
    ..lineTo(-40, 18)
    ..lineTo(120, 58)
    ..lineTo(300, 26)
    ..lineTo(right, 54)
    ..lineTo(right, floorTop)
    ..close();
  c.drawPath(far, Paint()..color = const Color(0xFF160F26));
  final near = Path()
    ..moveTo(left, floorTop)
    ..lineTo(left, 78)
    ..lineTo(-240, 48)
    ..lineTo(-80, 82)
    ..lineTo(90, 52)
    ..lineTo(260, 86)
    ..lineTo(right, 62)
    ..lineTo(right, floorTop)
    ..close();
  c.drawPath(near, Paint()..color = const Color(0xFF0E0A1A));

  _torii(c, -302, floorTop);
  _pagoda(c, 330, floorTop);

  // Isometric floor slab.
  c.drawRect(
    const Rect.fromLTRB(left, floorTop, right, bottom),
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, floorTop),
        const Offset(0, 270),
        const [Color(0xFF191320), Color(0xFF060509)],
      ),
  );

  // 2:1 diamond grid for the iso read.
  c.save();
  c.clipRect(const Rect.fromLTRB(left, floorTop, right, bottom));
  for (var k = -24; k <= 24; k++) {
    final bright = k % 4 == 0;
    final grid = Paint()
      ..color = const Color(0xFF6FE7FF).withValues(alpha: bright ? .09 : .045)
      ..strokeWidth = bright ? 1.2 : 1;
    final x0 = k * 56.0;
    c.drawLine(Offset(-560, floorTop + 0.5 * (-560 - x0)),
        Offset(560, floorTop + 0.5 * (560 - x0)), grid);
    c.drawLine(Offset(-560, floorTop - 0.5 * (-560 - x0)),
        Offset(560, floorTop - 0.5 * (560 - x0)), grid);
  }
  c.restore();

  // Glowing back edge of the platform.
  c.drawLine(
    const Offset(left, floorTop),
    const Offset(right, floorTop),
    Paint()
      ..color = const Color(0xFF6FE7FF).withValues(alpha: .12)
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
  );
  c.drawLine(
    const Offset(left, floorTop),
    const Offset(right, floorTop),
    Paint()
      ..color = const Color(0xFF9FEFFF).withValues(alpha: .30)
      ..strokeWidth = 1.4,
  );
}

void _torii(Canvas c, double x, double floorTop) {
  final ink = Paint()..color = const Color(0xFF0A0712).withValues(alpha: .95);
  final base = floorTop + 2.0;
  for (final px in [x - 46.0, x + 46.0]) {
    c.drawRect(Rect.fromLTRB(px - 6, base - 118, px + 6, base), ink);
  }
  final beam = Path()
    ..moveTo(x - 74, base - 112)
    ..quadraticBezierTo(x, base - 128, x + 74, base - 112)
    ..lineTo(x + 74, base - 102)
    ..quadraticBezierTo(x, base - 118, x - 74, base - 102)
    ..close();
  c.drawPath(beam, ink);
  c.drawRect(Rect.fromLTRB(x - 58, base - 92, x + 58, base - 84), ink);
}

void _pagoda(Canvas c, double x, double floorTop) {
  final ink = Paint()..color = const Color(0xFF0B0813).withValues(alpha: .95);
  final base = floorTop + 2.0;
  void roof(double w, double y, double lift) {
    final p = Path()
      ..moveTo(x - w, y)
      ..quadraticBezierTo(x - w * .5, y - lift * .3, x, y - lift)
      ..quadraticBezierTo(x + w * .5, y - lift * .3, x + w, y)
      ..lineTo(x + w * .55, y + 7)
      ..lineTo(x - w * .55, y + 7)
      ..close();
    c.drawPath(p, ink);
  }

  c.drawRect(Rect.fromLTRB(x - 30, base - 42, x + 30, base), ink);
  roof(58, base - 42, 14);
  c.drawRect(Rect.fromLTRB(x - 22, base - 86, x + 22, base - 48), ink);
  roof(46, base - 86, 13);
  c.drawRect(Rect.fromLTRB(x - 15, base - 122, x + 15, base - 92), ink);
  roof(34, base - 122, 12);
  c.drawLine(Offset(x, base - 148), Offset(x, base - 122), ink..strokeWidth = 3);
}
