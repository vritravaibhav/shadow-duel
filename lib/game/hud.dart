import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';

import 'arts.dart';
import 'combos.dart';
import 'effects.dart';
import 'fighter.dart';
import 'gestures.dart';
import 'shadow_game.dart';
import 'tutorial.dart';
import 'weapons.dart';

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

    final practice = game.practice;
    drawText(c, practice == null ? 'STAGE ${game.stage}' : 'DOJO', const Offset(480, 30),
        size: 13, letterSpacing: 5, color: const Color(0x66FFFFFF));
    if (practice != null) _lessonBanner(c, practice);

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

    // Danger vignette when the hero is nearly out.
    final hpFrac = (game.hero.hp / game.hero.maxHp).clamp(0.0, 1.0);
    if (hpFrac < .25 && game.hero.alive) {
      final beat = .35 + .35 * math.sin(game.t * (6 + (1 - hpFrac) * 8));
      final strength = (1 - hpFrac / .25) * beat;
      c.drawRect(
        const Rect.fromLTWH(0, 0, kW, kH),
        Paint()
          ..shader = ui.Gradient.radial(
            const Offset(kW / 2, kH / 2),
            kW * .62,
            [const Color(0x00FF2B2B), const Color(0xFFFF2B2B).withValues(alpha: .5 * strength)],
            const [0.55, 1.0],
          ),
      );
    }

    // Skull-smash readiness over the right stick.
    final smashReady = game.smashCd <= 0;
    final pulse = .7 + .3 * math.sin(game.t * 6);
    final smashC = Offset(kW - 90, kH - 136);
    drawText(c, smashReady ? 'SMASH ▲+▲' : '${game.smashCd.ceil()}s',
        smashC,
        size: smashReady ? 10 : 12,
        letterSpacing: 2,
        color: smashReady ? const Color(0xFFFF8B7B) : const Color(0x88FFFFFF),
        opacity: smashReady ? pulse : 1,
        glow: smashReady ? 4 : null);

    // The eight sectors around each stick and the combo the pair spells.
    _stickRing(c, game.joystick, game.leftDir, const Color(0xFF99E8FF));
    _stickRing(c, game.attackStick, game.rightDir, const Color(0xFFFF8B7B));
    _comboLabel(c);

    // Controls hint for the first moments of stage 1.
    if (game.stage == 1 && practice == null && game.phase == Phase.fighting && game.stageT < 14) {
      const hint = [
        'BOTH STICKS at the enemy = ATTACK   ●   LEFT height picks head / body / legs   ●   RIGHT picks ▲ smash  ► cut  ▼ kick',
        'LEFT away + RIGHT at the enemy = BLOCK at that height   ●   both away = STEP BACK   ●   draw V / W to cast',
      ];
      for (var i = 0; i < hint.length; i++) {
        drawText(c, hint[i], Offset(480, 404 + i * 18),
            size: 12,
            letterSpacing: 1.2,
            color: const Color(0x73FFFFFF),
            weight: FontWeight.w600);
      }
    }
  }

  /// Eight ticks around a stick, the held sector lit, with the enemy's side
  /// marked so "toward" reads at a glance.
  void _stickRing(Canvas c, JoystickComponent stick, Dir? held, Color tint) {
    if (game.phase != Phase.fighting && game.phase != Phase.intro) return;
    final center = stick.position.toOffset();
    final r = stick.size.x / 2 + 7;
    final face = game.hero.facing;
    for (final d in Dir.values) {
      final ang = math.atan2(-d.v.toDouble(), d.h * face.toDouble());
      final on = d == held;
      c.drawArc(
        Rect.fromCircle(center: center, radius: r),
        ang - .28,
        .56,
        false,
        Paint()
          ..color = on ? tint : const Color(0x40FFFFFF)
          ..strokeWidth = on ? 4.5 : 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..maskFilter = on ? const MaskFilter.blur(BlurStyle.solid, 3) : null,
      );
    }
    // The enemy's side of the stick.
    drawText(c, face > 0 ? '►' : '◄', Offset(center.dx + face * (r + 13), center.dy),
        size: 9, letterSpacing: 0, color: const Color(0x80FFFFFF));
  }

  /// The held combo's name between the sticks, or a nudge when only the
  /// right stick is held.
  void _comboLabel(Canvas c) {
    if (game.phase != Phase.fighting) return;
    final combo = game.heldCombo;
    final y = kH - 118.0;
    if (combo != null) {
      final col = combo.kind.color;
      drawText(c, combo.name, Offset(kW / 2, y),
          size: 15, letterSpacing: 4, color: col, glow: 6, style: FontStyle.italic);
      drawText(c, combo.kind.title, Offset(kW / 2, y + 15),
          size: 8, letterSpacing: 3, color: col.withValues(alpha: .7));
    } else if (game.rightDir != null) {
      drawText(c, 'HOLD THE LEFT STICK TOO', Offset(kW / 2, y),
          size: 9, letterSpacing: 3, color: const Color(0x80FFFFFF));
    }
  }

  /// The lesson being practised: what to do, the sticks to hold, and how
  /// far along it is.
  void _lessonBanner(Canvas c, Practice p) {
    if (p.finished) return;
    final lesson = p.lesson;
    const cx = kW / 2;
    final box = Rect.fromCenter(center: const Offset(cx, 142), width: 640, height: 66);
    c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(10)),
        Paint()..color = const Color(0xB3101018));
    final done = p.lessonDone;
    final col = done ? const Color(0xFF9CFF6B) : const Color(0xFFFFD75A);
    drawText(c, 'LESSON ${p.index + 1} / ${Lesson.all.length}   ·   ${lesson.title}', Offset(cx, box.top + 14),
        size: 11, letterSpacing: 4, color: col, glow: done ? 5 : null);
    drawText(c, lesson.text, Offset(cx, box.top + 34),
        size: 11, letterSpacing: .6, weight: FontWeight.w600, color: const Color(0xE6FFFFFF));
    final face = game.hero.facing > 0;
    final l = lesson.left, r = lesson.right;
    final sticks = [
      if (l != null) 'LEFT ${l.glyph(facingRight: face)}',
      if (r != null) 'RIGHT ${r.glyph(facingRight: face)}',
    ].join('   +   ');
    final progress = '${p.progress} / ${lesson.target} ${lesson.unit}';
    drawText(c, sticks.isEmpty ? progress : '$sticks      $progress', Offset(cx, box.top + 53),
        size: 10, letterSpacing: 2, color: const Color(0xB3FFFFFF));
  }
}

/// Clash-style sword card bar at the bottom center: bare hands + every owned
/// sword. Shows the time left on the drawn blade and each card's recharge.
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
          final t = '${card.activeLeft.ceil()}s';
          final chip = Rect.fromCenter(
              center: Offset(r.right - 12, r.top + 10), width: t.length * 6.0 + 8, height: 13);
          canvas.drawRRect(RRect.fromRectAndRadius(chip, const Radius.circular(4)),
              Paint()..color = const Color(0xD9101018));
          drawText(canvas, t, chip.center,
              size: 9, color: const Color(0xFFFFFFFF), letterSpacing: 0);
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
      // Cards shrink as the deck grows, so the caption keeps only what fits.
      final full = card == null ? 'FISTS' : card.sword.name;
      final maxChars = (cardW / 4.6).floor();
      final caption = full.length <= maxChars ? full : full.split(' ').first;
      drawText(canvas, caption, Offset(r.center.dx, r.bottom + 9),
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


/// Guard read-out: the villain's open zone is ringed in amber (hit there),
/// the covered zone shows a shield. Drawn above the card bar so it is never
/// hidden by the deck, and mirrored for the hero's own guard.
class GuardMarkers extends PositionComponent with HasGameReference<ShadowGame> {
  GuardMarkers() : super(priority: 45);

  static const _open = Color(0xFFFFC24D);
  static const _covered = Color(0xFF9FDBFF);
  static const _incoming = Color(0xFFFF5A5A);

  /// World space is centred on the viewport in this fixed-resolution camera.
  Offset _screen(Fighter f) =>
      Offset(f.position.x + kW / 2, f.position.y + kH / 2) -
      game.camera.viewfinder.position.toOffset();

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.phase != Phase.fighting) return;
    final v = game.villain;
    if (v != null && v.alive) _draw(canvas, v, labelled: true);
    if (game.hero.alive) _draw(canvas, game.hero, labelled: false);
  }

  void _draw(Canvas canvas, Fighter f, {required bool labelled}) {
    final s = 0.80 + f.zPos / kZMax * 0.32;
    final feet = _screen(f);
    final headY = feet.dy - 150 * f.build * s;
    final bodyY = feet.dy - 84 * f.build * s;
    final footY = feet.dy - 6;
    final pulse = .65 + .35 * math.sin(game.t * 9);
    double yOf(Zone z) => switch (z) { Zone.head => headY, Zone.body => bodyY, Zone.feet => footY };

    void ring(double y, Color col, double alpha, {double width = 2.5}) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(feet.dx, y), width: 52 * s, height: 13 * s),
        Paint()
          ..color = col.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }

    if (f.guardZone != GuardZone.none) {
      // Shield on what is covered, target ring on what is open.
      final covered = Zone.values.where(f.guards).toList();
      final open = Zone.values.where((z) => !f.guards(z)).toList();
      for (final z in covered) {
        ring(yOf(z), _covered, f.parrying ? .9 : .5, width: f.parrying ? 3.5 : 2.5);
      }
      for (final z in open) {
        ring(yOf(z), _open, .85 * pulse);
      }
      if (labelled && open.isNotEmpty) {
        // Name the highest open zone with the left-stick height that hits it.
        final z = open.first;
        final glyph = switch (z) { Zone.head => '▲', Zone.body => '►', Zone.feet => '▼' };
        final y = z == Zone.feet ? footY + 16 : yOf(z) - 16;
        final label = 'OPEN $glyph';
        final box = Rect.fromCenter(
            center: Offset(feet.dx, y), width: label.length * 7.5 + 12, height: 16);
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(6)),
            Paint()..color = const Color(0xCC101018));
        drawText(canvas, label, box.center,
            size: 11, letterSpacing: 2, color: _open, opacity: pulse, glow: 4);
      }
    }

    // The enemy's telegraphed blow: where it will land on the hero and the
    // right-stick height that blocks it.
    if (!labelled) {
      final v = game.villain;
      Zone? incoming = v?.incomingZone;
      var u = v?.windUpU ?? 0;
      if (incoming == null && v != null && v.attacking && v.currentMove != null) {
        final m = v.currentMove!;
        final su = v.stateT / m.duration;
        if (su < m.winStart) {
          incoming = m.zone;
          u = 1;
        }
      }
      if (incoming != null && f.alive) {
        final y = yOf(incoming);
        final flash = .5 + .5 * math.sin(game.t * 22);
        ring(y, _incoming, .55 + .45 * flash, width: 3 + 2 * u);
        final glyph = switch (incoming) { Zone.head => '▲', Zone.body => '►', Zone.feet => '▼' };
        final labelY = incoming == Zone.feet ? footY + 16 : y - 16;
        drawText(canvas, 'BLOCK $glyph', Offset(feet.dx, labelY),
            size: 11, letterSpacing: 2, color: _incoming, glow: 5);
      }
    }
  }
}


/// The pause button: freezes the battle and opens the quit-to-map menu.
class PauseButton extends PositionComponent with HasGameReference<ShadowGame>, TapCallbacks {
  PauseButton() : super(position: Vector2(kW / 2 - 22, 74), size: Vector2(44, 30), priority: 26);

  double _pop = 0;

  @override
  bool containsLocalPoint(Vector2 point) =>
      game.phase == Phase.fighting && !game.battlePaused && super.containsLocalPoint(point);

  @override
  void onTapDown(TapDownEvent event) => _pop = 1;

  @override
  void onTapUp(TapUpEvent event) => game.pauseFight();

  @override
  void update(double dt) {
    super.update(dt);
    _pop = math.max(0, _pop - 5 * dt);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.phase != Phase.fighting) return;
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(8));
    canvas.drawRRect(r, Paint()..color = Color.lerp(const Color(0xB3101018), const Color(0xFF2B3350), _pop)!);
    canvas.drawRRect(
      r,
      Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    final bar = Paint()..color = const Color(0xE6FFFFFF);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.x / 2 - 7, 9, 4.5, 12), const Radius.circular(2)), bar);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(size.x / 2 + 2.5, 9, 4.5, 12), const Radius.circular(2)), bar);
  }
}
