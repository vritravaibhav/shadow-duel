// Asset-pipeline painter: draws each weapon (blade pointing along +x, grip at
// the origin) and the HUD icons. Used only by the sprite baker.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

void paintKatana(Canvas c) {
  c.drawLine(
    const Offset(-9, 0),
    const Offset(3, 0),
    Paint()
      ..color = const Color(0xFF2B2330)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round,
  );
  c.drawCircle(const Offset(3, 0), 3.6, Paint()..color = const Color(0xFF54422E));
  final blade = Path()
    ..moveTo(5, -2.4)
    ..lineTo(52, -1.4)
    ..lineTo(62, 0)
    ..lineTo(52, 1.6)
    ..lineTo(5, 2.6)
    ..close();
  c.drawPath(
    blade,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(5, 0),
        const Offset(62, 0),
        const [Color(0xFFEAF2FA), Color(0xFF8E9CB0)],
      ),
  );
  c.drawLine(
    const Offset(7, -1.9),
    const Offset(57, -0.9),
    Paint()
      ..color = const Color(0xB3FFFFFF)
      ..strokeWidth = 0.9,
  );
}

void paintAxe(Canvas c) {
  c.drawLine(
    const Offset(-4, 0),
    const Offset(44, 0),
    Paint()
      ..color = const Color(0xFF3B2B1F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round,
  );
  c.drawCircle(const Offset(-4, 0), 2.6, Paint()..color = const Color(0xFF54422E));
  final spike = Path()
    ..moveTo(30, -4)
    ..lineTo(19, 0)
    ..lineTo(30, 4)
    ..close();
  c.drawPath(spike, Paint()..color = const Color(0xFF6E7885));
  final head = Path()
    ..moveTo(28, -16)
    ..quadraticBezierTo(48, -11, 52, 0)
    ..quadraticBezierTo(48, 11, 28, 16)
    ..quadraticBezierTo(37, 0, 28, -16)
    ..close();
  c.drawPath(
    head,
    Paint()
      ..shader = ui.Gradient.linear(
        const Offset(28, 0),
        const Offset(52, 0),
        const [Color(0xFFB8C4D2), Color(0xFFEDF4FB)],
      ),
  );
  final edge = Path()
    ..moveTo(49, -8)
    ..quadraticBezierTo(52.5, 0, 49, 8);
  c.drawPath(
    edge,
    Paint()
      ..color = const Color(0xBFFFFFFF)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke,
  );
}

/// Icon painters draw centered at the origin into a box of side [s].
void paintIcon(Canvas c, String weapon, double s) {
  final steel = Paint()..color = const Color(0xFFD8E2EC);
  final wood = Paint()
    ..color = const Color(0xFF7A5B38)
    ..strokeCap = StrokeCap.round;
  switch (weapon) {
    case 'fists':
      final fist = Paint()..color = const Color(0xFFC8D2DE);
      c.drawCircle(Offset(-s * .14, -s * .06), s * .15, fist);
      c.drawCircle(Offset(s * .14, s * .08), s * .15, fist);
    case 'katana':
      c.rotate(-math.pi / 4);
      c.drawLine(Offset(-s * .38, 0), Offset(-s * .24, 0), wood..strokeWidth = s * .1);
      c.drawLine(
        Offset(-s * .22, 0),
        Offset(s * .34, 0),
        steel
          ..strokeWidth = s * .085
          ..strokeCap = StrokeCap.round,
      );
    case 'axe':
      c.rotate(-math.pi / 4);
      c.drawLine(Offset(-s * .34, 0), Offset(s * .22, 0), wood..strokeWidth = s * .09);
      final head = Path()
        ..moveTo(s * .1, -s * .2)
        ..lineTo(s * .34, 0)
        ..lineTo(s * .1, s * .2)
        ..lineTo(s * .17, 0)
        ..close();
      c.drawPath(head, steel);
  }
}
