import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../game/sfx.dart';

const kGold = Color(0xFFFFD75A);
const kGoldDeep = Color(0xFFE09A1E);
const kGoldPale = Color(0xFFFFF3B8);

/// A coin: gold disc, dark rim, a bright crescent highlight and a stamped
/// inner ring. [spin] flips it about its vertical axis.
void paintCoin(Canvas c, Offset at, double r, {double spin = 0, double alpha = 1}) {
  final w = (0.28 + 0.72 * math.cos(spin).abs());
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(w, 1);
  final edge = math.cos(spin) < 0;
  c.drawCircle(Offset.zero, r, Paint()..color = kGoldDeep.withValues(alpha: alpha));
  c.drawCircle(
    Offset.zero,
    r * .86,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.4),
        colors: [kGoldPale, edge ? kGoldDeep : kGold, kGoldDeep],
        stops: const [0, .55, 1],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: r * .86))
      ..color = Colors.white.withValues(alpha: alpha),
  );
  c.drawCircle(
    Offset.zero,
    r * .58,
    Paint()
      ..color = kGoldDeep.withValues(alpha: .7 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .12,
  );
  c.drawCircle(Offset(-r * .3, -r * .35), r * .16, Paint()..color = Colors.white.withValues(alpha: .85 * alpha));
  c.restore();
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinIconPainter());
}

class _CoinIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) =>
      paintCoin(canvas, size.center(Offset.zero), size.width / 2, spin: .35);

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// The purse: coin + balance. The number rolls toward [value] and the chip
/// pops whenever the balance moves.
class PurseChip extends StatefulWidget {
  const PurseChip({super.key, required this.value, this.compact = false, this.onTap});
  final int value;
  final bool compact;
  final VoidCallback? onTap;

  @override
  State<PurseChip> createState() => _PurseChipState();
}

class _PurseChipState extends State<PurseChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late double _shown = widget.value.toDouble();
  late int _target = widget.value;
  Ticker? _roll;

  @override
  void didUpdateWidget(PurseChip old) {
    super.didUpdateWidget(old);
    if (widget.value != _target) {
      _target = widget.value;
      _pop.forward(from: 0);
      _roll ??= createTicker(_tick)..start();
    }
  }

  void _tick(Duration _) {
    final d = _target - _shown;
    if (d.abs() < .5) {
      _shown = _target.toDouble();
      _roll?.stop();
      _roll?.dispose();
      _roll = null;
    } else {
      _shown += d * .18;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pop.dispose();
    _roll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Curves.elasticOut.transform(_pop.value);
    final scale = 1 + .28 * (1 - _pop.value) * t;
    return GestureDetector(
      onTap: widget.onTap,
      child: Transform.scale(
        scale: scale,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 9 : 12, vertical: widget.compact ? 5 : 7),
          decoration: BoxDecoration(
            color: const Color(0xCC1A1408),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kGold.withValues(alpha: .75), width: 1.5),
            boxShadow: [BoxShadow(color: kGold.withValues(alpha: .25 + .45 * _pop.value), blurRadius: 14 + 20 * _pop.value)],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CoinIcon(size: widget.compact ? 15 : 19),
            const SizedBox(width: 7),
            Text(
              _shown.round().toString(),
              style: TextStyle(
                fontFamily: 'Kenney',
                color: kGoldPale,
                fontSize: widget.compact ? 13 : 17,
                letterSpacing: 1.5,
                shadows: const [Shadow(color: kGoldDeep, blurRadius: 8)],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Wraps a tappable so it squashes on press and springs back: everything
/// in the menus should feel like it has some give.
class Springy extends StatefulWidget {
  const Springy({super.key, required this.child, this.onTap, this.pressScale = .9});
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;

  @override
  State<Springy> createState() => _SpringyState();
}

class _SpringyState extends State<Springy> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 90), reverseDuration: const Duration(milliseconds: 520));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _c.forward() : null,
      onTapCancel: enabled ? () => _c.reverse() : null,
      onTapUp: enabled
          ? (_) {
              _c.reverse();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final v = _c.status == AnimationStatus.reverse
              ? 1 - Curves.elasticOut.transform(1 - _c.value)
              : _c.value;
          return Transform.scale(scale: 1 - (1 - widget.pressScale) * v, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Coin {
  _Coin(this.pos, this.vel, this.r, this.spin, this.spinV, this.launchAt, this.flyAt, this.value);
  Offset pos, vel;
  final double r;
  double spin, spinV;
  final double launchAt, flyAt;
  final int value;
  bool live = false, flying = false, landed = false;
  double flyT = 0;
  Offset flyFrom = Offset.zero, ctrl = Offset.zero;
  final List<Offset> trail = [];
}

class _Sparkle {
  _Sparkle(this.pos, this.vel, this.life, this.color);
  Offset pos, vel;
  double life;
  final Color color;
}

/// The pay-out. Coins erupt from [source], bounce on an invisible floor,
/// then one by one whip up into the purse at [target]; every arrival ticks
/// the counter, pops the chip, clicks and taps the haptics. The last coin
/// lands with a flash and calls [onDone].
class CoinShower extends StatefulWidget {
  const CoinShower({
    super.key,
    required this.amount,
    required this.source,
    required this.target,
    required this.onCollected,
    this.onDone,
    this.big = false,
    this.delay = .35,
  });

  final int amount;
  final Offset source, target;

  /// Called with the running total collected so far.
  final void Function(int collected) onCollected;
  final VoidCallback? onDone;

  /// A first clear: more coins, bigger, louder.
  final bool big;
  final double delay;

  @override
  State<CoinShower> createState() => _CoinShowerState();
}

class _CoinShowerState extends State<CoinShower> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rng = math.Random();
  final List<_Coin> _coins = [];
  final List<_Sparkle> _sparks = [];
  double _t = 0, _last = 0;
  int _collected = 0, _landed = 0;
  double _flash = 0, _burst = 0;
  bool _done = false, _erupted = false;

  @override
  void initState() {
    super.initState();
    final n = widget.amount <= 0 ? 0 : (widget.big ? 26 : 12).clamp(1, math.max(1, widget.amount));
    var left = widget.amount;
    for (var i = 0; i < n; i++) {
      final share = i == n - 1 ? left : (widget.amount / n).round();
      left -= share;
      final ang = -math.pi / 2 + (_rng.nextDouble() - .5) * (widget.big ? 2.4 : 1.8);
      final spd = (widget.big ? 520 : 400) + _rng.nextDouble() * 260;
      _coins.add(_Coin(
        widget.source,
        Offset(math.cos(ang), math.sin(ang)) * spd,
        (widget.big ? 13.0 : 11.0) + _rng.nextDouble() * 3,
        _rng.nextDouble() * math.pi,
        6 + _rng.nextDouble() * 10,
        widget.delay + i * (widget.big ? .035 : .05),
        widget.delay + .95 + i * (widget.big ? .055 : .08),
        share,
      ));
    }
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration e) {
    final now = e.inMicroseconds / 1e6;
    final dt = math.min(.05, now - _last);
    _last = now;
    _t = now;
    final floor = widget.source.dy + (widget.big ? 150 : 120);
    var allDone = true;
    for (final c in _coins) {
      if (!c.live) {
        if (_t >= c.launchAt) {
          c.live = true;
          if (!_erupted) {
            _erupted = true;
            _burst = 1;
            Sfx.play('card', volume: .9);
            HapticFeedback.mediumImpact();
          }
        } else {
          allDone = false;
          continue;
        }
      }
      if (c.landed) continue;
      allDone = false;
      c.trail.add(c.pos);
      if (c.trail.length > 6) c.trail.removeAt(0);
      if (!c.flying) {
        c.vel += Offset(0, 1500 * dt);
        c.pos += c.vel * dt;
        c.spin += c.spinV * dt;
        if (c.pos.dy > floor) {
          c.pos = Offset(c.pos.dx, floor);
          c.vel = Offset(c.vel.dx * .8, -c.vel.dy * .48);
          c.spinV *= .7;
          if (c.vel.dy.abs() > 60) _puff(c.pos, 2);
        }
        if (_t >= c.flyAt) {
          c.flying = true;
          c.flyFrom = c.pos;
          final mid = Offset.lerp(c.pos, widget.target, .5)!;
          c.ctrl = mid + Offset((_rng.nextDouble() - .5) * 240, -160 - _rng.nextDouble() * 120);
        }
      } else {
        c.flyT += dt / .5;
        final u = Curves.easeInCubic.transform(c.flyT.clamp(0.0, 1.0));
        c.pos = _bezier(c.flyFrom, c.ctrl, widget.target, u);
        c.spin += (c.spinV + 18) * dt;
        if (c.flyT >= 1) {
          c.landed = true;
          _landed++;
          _collected += c.value;
          _flash = 1;
          _puff(widget.target, 7, gold: true);
          Sfx.play('click', volume: .55 + .3 * (_landed / _coins.length));
          HapticFeedback.selectionClick();
          widget.onCollected(_collected);
        }
      }
    }
    for (final s in _sparks) {
      s.pos += s.vel * dt;
      s.vel = Offset(s.vel.dx * (1 - 4 * dt), s.vel.dy * (1 - 4 * dt) + 500 * dt);
      s.life -= dt;
    }
    _sparks.removeWhere((s) => s.life <= 0);
    _flash = math.max(0, _flash - dt * 4);
    _burst = math.max(0, _burst - dt * 2.2);
    if (allDone && !_done) {
      _done = true;
      if (_coins.isNotEmpty) {
        Sfx.play('heal', volume: .8);
        HapticFeedback.heavyImpact();
        _puff(widget.target, 26, gold: true);
      }
      widget.onDone?.call();
    }
    if (_done && _sparks.isEmpty && _flash <= 0) _ticker.stop();
    setState(() {});
  }

  void _puff(Offset at, int n, {bool gold = false}) {
    for (var i = 0; i < n; i++) {
      final a = _rng.nextDouble() * math.pi * 2;
      final sp = 80 + _rng.nextDouble() * (gold ? 260 : 120);
      _sparks.add(_Sparkle(at, Offset(math.cos(a), math.sin(a)) * sp, .25 + _rng.nextDouble() * .3,
          gold ? (i.isEven ? kGoldPale : kGold) : Colors.white70));
    }
  }

  static Offset _bezier(Offset a, Offset c, Offset b, double u) {
    final v = 1 - u;
    return a * (v * v) + c * (2 * v * u) + b * (u * u);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ShowerPainter(_coins, _sparks, _flash, _burst, widget.source, widget.target),
      ),
    );
  }
}

class _ShowerPainter extends CustomPainter {
  _ShowerPainter(this.coins, this.sparks, this.flash, this.burst, this.source, this.target);
  final List<_Coin> coins;
  final List<_Sparkle> sparks;
  final double flash, burst;
  final Offset source, target;

  @override
  void paint(Canvas c, Size size) {
    if (burst > 0) {
      // The eruption: a ring racing outward and a white-gold flash.
      final u = 1 - burst;
      c.drawCircle(source, 30 + u * 260,
          Paint()
            ..color = kGold.withValues(alpha: .7 * burst)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10 * burst);
      c.drawCircle(source, 60 * burst, Paint()..color = kGoldPale.withValues(alpha: .6 * burst));
    }
    for (final s in sparks) {
      c.drawCircle(s.pos, 1.5 + s.life * 5, Paint()..color = s.color.withValues(alpha: (s.life * 3).clamp(0.0, 1.0)));
    }
    for (final co in coins) {
      if (!co.live || co.landed) continue;
      for (var i = 0; i < co.trail.length; i++) {
        final a = (i + 1) / (co.trail.length + 1);
        c.drawCircle(co.trail[i], co.r * .55 * a, Paint()..color = kGold.withValues(alpha: .28 * a));
      }
      c.drawCircle(co.pos + const Offset(0, 3), co.r * 1.1, Paint()..color = kGoldDeep.withValues(alpha: .35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      paintCoin(c, co.pos, co.r, spin: co.spin);
    }
    if (flash > 0) {
      c.drawCircle(target, 22 + 40 * (1 - flash),
          Paint()
            ..color = kGoldPale.withValues(alpha: .8 * flash)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * flash);
    }
  }

  @override
  bool shouldRepaint(covariant _ShowerPainter old) => true;
}
