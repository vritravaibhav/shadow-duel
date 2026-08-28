import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'arts.dart';
import 'effects.dart';
import 'gestures.dart';
import 'shadow_game.dart';

class Hud extends PositionComponent with HasGameReference<ShadowGame> {
  Hud() : super(priority: 10);

  double _ghostHero = 1, _ghostVillain = 1;

  @override
  void update(double dt) {
    super.update(dt);
    final ht = game.hero.hp / game.hero.maxHp;
    _ghostHero = ht > _ghostHero ? ht : _ghostHero + (ht - _ghostHero) * math.min(1, 4 * dt);
    final v = game.villain;
    if (v != null) {
      final vt = v.hp / v.maxHp;
      _ghostVillain =
          vt > _ghostVillain ? vt : _ghostVillain + (vt - _ghostVillain) * math.min(1, 4 * dt);
    }
  }

  void resetGhosts() {
    _ghostHero = game.hero.hp / game.hero.maxHp;
    _ghostVillain = 1;
  }

  void _artBadge(Canvas c, Offset center, SwordArt art, double cd) {
    final tint = game.hero.weapon.trail.withValues(alpha: 1);
    final ready = cd <= 0;
    final pulse = 0.7 + 0.3 * math.sin(game.t * 6);
    if (ready) {
      c.drawCircle(center, 24, Paint()
        ..color = tint.withValues(alpha: .35 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    c.drawCircle(center, 19, Paint()..color = const Color(0xE6141828));
    c.drawCircle(center, 19, Paint()
      ..color = ready ? tint : const Color(0x55FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ready ? 2.5 : 1.5);
    if (!ready) {
      final frac = (cd / art.cooldown).clamp(0.0, 1.0);
      c.drawArc(Rect.fromCircle(center: center, radius: 17), -math.pi / 2, math.pi * 2 * frac, true,
          Paint()..color = const Color(0x99000000));
    }
    drawText(c, art.glyph, center + const Offset(0, -1),
        size: 20, color: ready ? tint : const Color(0x88FFFFFF), letterSpacing: 0, glow: ready ? 6 : null);
    final label = ready ? art.name.toUpperCase() : '${cd.ceil()}s';
    c.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromCenter(center: center + const Offset(0, 30), width: label.length * 6.2 + 10, height: 13),
          const Radius.circular(6)),
      Paint()..color = const Color(0xB3101018),
    );
    drawText(c, label, center + const Offset(0, 30),
        size: 8, letterSpacing: 1, color: ready ? const Color(0xE6FFFFFF) : const Color(0x99FFFFFF));
  }

  Path _bar(double x, double y, double w, {bool flip = false}) {
    const h = 18.0, skew = 12.0;
    return flip
        ? (Path()
          ..moveTo(x, y)
          ..lineTo(x - w, y)
          ..lineTo(x - w + skew, y + h)
          ..lineTo(x, y + h)
          ..close())
        : (Path()
          ..moveTo(x, y)
          ..lineTo(x + w, y)
          ..lineTo(x + w - skew, y + h)
          ..lineTo(x, y + h)
          ..close());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.phase == Phase.menu) return;
    final c = canvas;
    const barW = 340.0, y = 24.0;
    final edge = Paint()
      ..color = const Color(0x30FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bg = Paint()..color = const Color(0x66101018);

    // Hero bar (drains right-to-left).
    final heroFrac = (game.hero.hp / game.hero.maxHp).clamp(0.0, 1.0);
    c.drawPath(_bar(72, y, barW), bg);
    c.drawPath(_bar(72, y, barW * _ghostHero), Paint()..color = const Color(0x55FFFFFF));
    if (heroFrac > 0) {
      c.drawPath(
        _bar(72, y, barW * heroFrac),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(72, 0),
            const Offset(72 + barW, 0),
            const [Color(0xFF6CF0A0), Color(0xFF1F8A54)],
          ),
      );
    }
    c.drawPath(_bar(72, y, barW), edge);
    drawText(c, game.hero.charName, const Offset(126, 58),
        size: 13, letterSpacing: 4, color: const Color(0x99FFFFFF));

    // Villain bar (mirrored, drains left-to-right).
    final v = game.villain;
    final vFrac = v == null ? 0.0 : (v.hp / v.maxHp).clamp(0.0, 1.0);
    c.drawPath(_bar(888, y, barW, flip: true), bg);
    c.drawPath(_bar(888, y, barW * _ghostVillain, flip: true),
        Paint()..color = const Color(0x55FFFFFF));
    if (vFrac > 0) {
      c.drawPath(
        _bar(888, y, barW * vFrac, flip: true),
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(888, 0),
            const Offset(888 - barW, 0),
            const [Color(0xFFFF6B6B), Color(0xFF8F1D2C)],
          ),
      );
    }
    c.drawPath(_bar(888, y, barW, flip: true), edge);
    if (v != null) {
      drawText(c, v.charName, const Offset(834, 58),
          size: 13, letterSpacing: 4, color: const Color(0x99FFFFFF));
    }

    // Headshot portraits flanking the bars, facing inward.
    game.sprites.portraits[game.hero.charKey]
        ?.render(c, position: Vector2(20, 18), size: Vector2(46, 46));
    if (v != null) {
      c.save();
      c.translate(917, 41);
      c.scale(-1, 1);
      game.sprites.portraits[v.charKey]
          ?.render(c, position: Vector2(-23, -23), size: Vector2(46, 46));
      c.restore();
    }

    drawText(c, 'STAGE ${game.stage}', const Offset(480, 30),
        size: 13, letterSpacing: 5, color: const Color(0x66FFFFFF));

    // Sword-art badges: draw V / W on the right half to cast.
    final (artV, artW) = Arts.of(game.hero.weapon.id);
    _artBadge(c, const Offset(836, 100), artV, game.deck.artCooldown(ArtGesture.v));
    _artBadge(c, const Offset(908, 100), artW, game.deck.artCooldown(ArtGesture.w));

    // Combo counter.
    if (game.combo >= 2) {
      final pop = 1 + math.max(0.0, game.comboT - 1.3) * 3.5;
      drawText(c, '${game.combo} HITS', const Offset(120, 96),
          size: 25 * pop,
          color: const Color(0xFFFFD75A),
          letterSpacing: 3,
          glow: 5,
          style: FontStyle.italic);
    }

    // Controls hint for the first moments of stage 1.
    if (game.stage == 1 && game.phase == Phase.fighting && game.stageT < 14) {
      drawText(
        c,
        'LEFT STICK move   ●   RIGHT STICK flick ▲ head  ▼ feet  ◄► slash, tap strike   ●   BOTH ▲ skull smash   ●   draw V / W in the middle   ●   stand still to guard',
        const Offset(480, 428),
        size: 12,
        letterSpacing: 1.5,
        color: const Color(0x73FFFFFF),
        weight: FontWeight.w600,
      );
    }
  }
}

/// Clash-style sword card bar at the bottom center: bare hands + every owned
/// sword. Shows durability, recharge, and the equipped card.
class CardBar extends PositionComponent with HasGameReference<ShadowGame>, TapCallbacks {
  CardBar() : super(position: Vector2(0, kH - 96), size: Vector2(kW, 96), priority: 25);

  static const gap = 6.0;
  double _pop = 0;
  int _popIndex = -2;

  int get _count => game.deck.cards.length + 1;

  /// Cards shrink so the whole deck fits between the two sticks.
  double get cardW => math.min(58.0, (600 - (_count - 1) * gap) / _count);
  double get _startX => kW / 2 - (_count * cardW + (_count - 1) * gap) / 2;

  Rect _cardRect(int slot) {
    final x = _startX + slot * (cardW + gap);
    return Rect.fromLTWH(x, 12, cardW, cardW);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (game.phase == Phase.menu) return false;
    for (var i = 0; i < _count; i++) {
      if (_cardRect(i).inflate(4).contains(point.toOffset())) return true;
    }
    return false;
  }

  @override
  void onTapDown(TapDownEvent event) {
    final p = event.localPosition.toOffset();
    for (var i = 0; i < _count; i++) {
      if (_cardRect(i).inflate(4).contains(p)) {
        game.equipCard(i - 1);
        _pop = 1;
        _popIndex = i - 1;
        return;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pop = math.max(0, _pop - 5 * dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.phase == Phase.menu) return;
    final deck = game.deck;
    final ui = game.sprites.ui;
    for (var slot = 0; slot < _count; slot++) {
      final index = slot - 1;
      final r = _cardRect(slot);
      final equipped = deck.equipped == index;
      final card = index < 0 ? null : deck.cards[index];
      final ready = card == null || card.ready;

      canvas.save();
      final s = 1.0 + (_popIndex == index ? _pop * .12 : 0.0) + (equipped ? .06 : 0.0);
      canvas.translate(r.center.dx, r.center.dy);
      canvas.scale(s, s);
      canvas.translate(-r.center.dx, -r.center.dy);

      final frame = equipped
          ? 'card_yellow'
          : (!ready ? 'card_red' : (card == null ? 'card_grey' : 'card_blue'));
      ui[frame]!.render(canvas, position: Vector2(r.left, r.top), size: Vector2(cardW, cardW));

      final icon = card == null ? game.sprites.icons['fists'] : game.sprites.swordIcons[card.sword.id];
      final iconSize = cardW * .69;
      icon?.render(
        canvas,
        position: Vector2(r.left + (cardW - iconSize) / 2, r.top + cardW * .1),
        size: Vector2(iconSize, iconSize),
        overridePaint: Paint()
          ..filterQuality = FilterQuality.none
          ..color = const Color(0xFFFFFFFF).withValues(alpha: ready ? 1 : .45),
      );

      if (card != null) {
        // Time left on the blade (drains while drawn).
        final frac = card.activeFrac;
        final barR = Rect.fromLTWH(r.left + 6, r.bottom - 10, cardW - 12, 5);
        canvas.drawRRect(RRect.fromRectAndRadius(barR, const Radius.circular(2)),
            Paint()..color = const Color(0x99000000));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(barR.left, barR.top, barR.width * frac, barR.height),
              const Radius.circular(2)),
          Paint()
            ..color = Color.lerp(const Color(0xFFFF5A5A), const Color(0xFF7DEBFF), frac)!,
        );
        if (equipped) {
          drawText(canvas, '${card.activeLeft.ceil()}s', Offset(r.right - 10, r.top + 9),
              size: 9, color: const Color(0xFFFFFFFF), letterSpacing: 0, glow: 3);
        }
        // Recharge overlay.
        if (card.cooldown > 0) {
          final cf = card.cooldownFrac;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(r.left, r.top, r.width, r.height * cf), const Radius.circular(8)),
            Paint()..color = const Color(0xB3101018),
          );
          drawText(canvas, '${card.cooldown.ceil()}s', r.center,
              size: 16, color: const Color(0xFFFFFFFF), glow: 4);
        }
      }
      drawText(canvas, card == null ? 'FISTS' : card.sword.name, Offset(r.center.dx, r.bottom + 9),
          size: 7.5, letterSpacing: 1, color: Color(equipped ? 0xFFFFD75A : 0x99FFFFFF));
      canvas.restore();
    }
  }
}

/// The right half of the screen: taps strike, swipes slash / kick / smash,
/// and drawn glyphs (V, W) cast the equipped blade's sword arts. Every stroke
/// is shown as a sword trail while the finger moves.
class GestureZone extends PositionComponent
    with HasGameReference<ShadowGame>, TapCallbacks, DragCallbacks {
  GestureZone()
      : super(position: Vector2(160, 0), size: Vector2(kW - 320, kH), priority: 5);

  final List<Offset> _pts = [];
  int? _pointer;

  Offset _viewport(Vector2 local) => Offset(local.x + position.x, local.y + position.y);

  /// The card bar owns its own taps: a drag that begins on a card is not a stroke.
  @override
  bool containsLocalPoint(Vector2 point) {
    if (!super.containsLocalPoint(point)) return false;
    final vp = point + position;
    return !game.cardBar.containsLocalPoint(vp - game.cardBar.position);
  }

  @override
  void onTapUp(TapUpEvent event) {
    game.onStroke(const GestureResult(GestureKind.tap, [], []));
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (_pointer != null) return; // one stroke at a time
    _pointer = event.pointerId;
    _pts
      ..clear()
      ..add(_viewport(event.localPosition));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (event.pointerId != _pointer) return;
    _pts.add(_viewport(event.localEndPosition));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (event.pointerId != _pointer) return;
    _pointer = null;
    game.onStroke(GestureRecognizer.recognize(_pts));
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (event.pointerId != _pointer) return;
    _pointer = null;
  }
}


/// The right stick: flick up to cut at the head, down to sweep the feet,
/// sideways to slash the body; a tap is a quick strike. Both sticks up at
/// once is the unblockable skull smash.
class AttackStick extends JoystickComponent with TapCallbacks {
  AttackStick({required this.onTap, required super.knob, required super.background, super.margin});

  /// A tap without a flick: the quick strike.
  final void Function() onTap;

  @override
  void onTapUp(TapUpEvent event) => onTap();
}
