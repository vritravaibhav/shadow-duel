import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'effects.dart';
import 'fighter.dart';
import 'shadow_game.dart';
import 'vfx.dart';

enum ProjectileStyle { crescent, fire, ice, holy }

/// A sword-art projectile flying along the owner's lane.
class ArtProjectile extends PositionComponent with HasGameReference<ShadowGame> {
  ArtProjectile({
    required this.owner,
    required this.target,
    required this.style,
    required this.color,
    required this.dmg,
    this.kx = 220,
    this.kup = 0,
    this.speed = 560,
    this.onHit,
    this.hitVfx,
  });

  final Fighter owner;
  final Fighter? target;
  final ProjectileStyle style;
  final Color color;
  final double dmg, kx, kup, speed;
  final void Function(Fighter target)? onHit;
  final String? hitVfx;

  late final int dir = owner.facing;
  late final double lane = owner.zPos;
  double _t = 0;
  bool _hit = false;
  final _rng = math.Random();

  @override
  Future<void> onLoad() async {
    position = Vector2(owner.wx + dir * 44, kFloorTop + lane - 68);
    priority = 100 + lane.round() + 1;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    position.x += dir * speed * dt;
    final v = target;
    if (!_hit && v != null && v.alive &&
        (v.wx - position.x).abs() < 44 && (v.zPos - lane).abs() < 40) {
      _hit = true;
      v.artHit(owner, dmg, kx: kx, kup: kup);
      onHit?.call(v);
      game.world.add(SparkBurst(at: position.clone(), heavy: true, palette: [color, const Color(0xFFFFFFFF)]));
      if (hitVfx != null) {
        game.world.add(VfxAnim(hitVfx!, at: position.clone(), scale_: 3.2, flipX: dir < 0));
      }
      removeFromParent();
      return;
    }
    if (_t > 1.6 || position.x.abs() > kW / 2 + 80) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.scale(dir.toDouble(), 1);
    final glow = Paint()
      ..color = color.withValues(alpha: .5)
      ..blendMode = BlendMode.plus
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final core = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .9)..blendMode = BlendMode.plus;
    switch (style) {
      case ProjectileStyle.crescent:
        final arc = Rect.fromCircle(center: Offset.zero, radius: 34);
        canvas.drawArc(arc, -1.15, 2.3, false, glow..style = PaintingStyle.stroke..strokeWidth = 22);
        canvas.drawArc(arc, -1.15, 2.3, false, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus);
        canvas.drawArc(arc, -1.0, 2.0, false, core..style = PaintingStyle.stroke..strokeWidth = 3);
        for (var i = 1; i <= 3; i++) {
          canvas.drawArc(Rect.fromCircle(center: Offset(-i * 16.0, 0), radius: 30), -.9, 1.8, false, Paint()
            ..color = color.withValues(alpha: .28 / i)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..blendMode = BlendMode.plus);
        }
      case ProjectileStyle.fire:
        for (var i = 0; i < 4; i++) {
          final wob = math.sin(_t * 30 + i * 1.7) * 6;
          final c = Offset(-i * 12.0, wob);
          canvas.drawCircle(c, 22 - i * 3, glow);
          canvas.drawCircle(c, 14 - i * 2.5, Paint()
            ..color = Color.lerp(const Color(0xFFFF4A1F), const Color(0xFFFFE07A), i / 4)!
            ..blendMode = BlendMode.plus);
        }
        canvas.drawCircle(const Offset(4, 0), 6, core);
        for (var i = 0; i < 5; i++) {
          canvas.drawCircle(Offset(-40 - _rng.nextDouble() * 30, (_rng.nextDouble() - .5) * 30), 2.5,
              Paint()..color = const Color(0xFFFFB05A).withValues(alpha: .7)..blendMode = BlendMode.plus);
        }
      case ProjectileStyle.ice:
        final shard = Path()
          ..moveTo(38, 0)
          ..lineTo(6, -11)
          ..lineTo(-34, -4)
          ..lineTo(-34, 4)
          ..lineTo(6, 11)
          ..close();
        canvas.drawPath(shard, glow);
        canvas.drawPath(shard, Paint()..color = color..blendMode = BlendMode.plus);
        canvas.drawPath(Path()..moveTo(30, 0)..lineTo(6, -4)..lineTo(-20, 0)..lineTo(6, 4)..close(), core);
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(Offset(-42 - i * 10.0, math.sin(_t * 20 + i) * 8), 2,
              Paint()..color = const Color(0xFFE6F7FF).withValues(alpha: .8)..blendMode = BlendMode.plus);
        }
      case ProjectileStyle.holy:
        canvas.drawLine(const Offset(-40, 0), const Offset(40, 0), glow..strokeWidth = 26..strokeCap = StrokeCap.round);
        canvas.drawLine(const Offset(-38, 0), const Offset(40, 0), Paint()
          ..color = color
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round
          ..blendMode = BlendMode.plus);
        canvas.drawLine(const Offset(-30, 0), const Offset(42, 0), core..strokeWidth = 3..strokeCap = StrokeCap.round);
        final ring = 18 + math.sin(_t * 18) * 3;
        canvas.drawOval(Rect.fromCenter(center: const Offset(-10, 0), width: 12, height: ring * 2), Paint()
          ..color = const Color(0xFFFFF4C2).withValues(alpha: .8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..blendMode = BlendMode.plus);
    }
    canvas.restore();
  }
}
