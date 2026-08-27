import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'shadow_game.dart';

class _Leaf {
  _Leaf(this.x, this.y, this.phase, this.size, this.spin);
  double x, y, phase, size, spin;
}

/// Draws the baked arena sprite (assets/images/arena.png) plus the two
/// dynamic ambience layers: drifting fog and falling leaves.
class Backdrop extends PositionComponent with HasGameReference<ShadowGame> {
  Backdrop() : super(priority: -50);

  double _t = 0;
  final _rng = math.Random(7);
  late final List<_Leaf> _leaves;

  @override
  Future<void> onLoad() async {
    _leaves = List.generate(
      16,
      (_) => _Leaf(
        -kW / 2 + _rng.nextDouble() * kW,
        -kH / 2 + _rng.nextDouble() * kH,
        _rng.nextDouble() * math.pi * 2,
        2.5 + _rng.nextDouble() * 3,
        _rng.nextDouble() * 4,
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    for (final l in _leaves) {
      l.y += (14 + l.size * 4) * dt;
      l.x += math.sin(_t * 1.2 + l.phase) * 16 * dt - 6 * dt;
      if (l.y > kH / 2 + 10) {
        l.y = -kH / 2 - 10;
        l.x = -kW / 2 + _rng.nextDouble() * kW;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    game.sprites.arena.render(
      canvas,
      position: Vector2(-500, -290),
      size: Vector2(1000, 580),
    );

    // Drifting fog.
    for (var i = 0; i < 3; i++) {
      final fx = math.sin(_t * (0.12 + i * 0.05) + i * 2.1) * 220;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(fx, 130.0 + i * 46), width: 640, height: 60),
        Paint()
          ..color = const Color(0xFFB8C8E8).withValues(alpha: .035)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24),
      );
    }

    // Falling crimson leaves.
    for (final l in _leaves) {
      canvas.save();
      canvas.translate(l.x, l.y);
      canvas.rotate(_t * l.spin + l.phase);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: l.size * 2.4, height: l.size),
        Paint()..color = const Color(0xFFA22735).withValues(alpha: .55),
      );
      canvas.restore();
    }
  }
}
