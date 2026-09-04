import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/arts.dart';
import '../game/progress.dart';
import '../game/sfx.dart';
import '../game/shadow_game.dart';
import '../game/weapons.dart';
import 'coins.dart';

const _bg = Color(0xFF0B0913);
const _accent = Color(0xFFFFD75A);
const _ink = Color(0xFF1B1B2A);

/// A Kenney UI-pack button (assets/images/ui/button_COLOR.png).
class KButton extends StatelessWidget {
  const KButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = 'blue',
    this.width = 180,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onTap;
  final String color;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    return Springy(
      pressScale: .88,
      onTap: onTap == null
          ? null
          : () {
              Sfx.play('click', volume: .6);
              onTap!();
            },
      child: Opacity(
        opacity: onTap == null ? .45 : 1,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/ui/button_$color.png', fit: BoxFit.fill),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

/// The front door. Nothing sits still: the letters of the title drop in one
/// by one on springs and keep riding a slow wave, the start pill beats like
/// a heart, the purse swings down from the top and everything you can press
/// squashes under the thumb.
class _TitleScreenState extends State<TitleScreen> with TickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  late final AnimationController _bob =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

  @override
  void dispose() {
    _in.dispose();
    _bob.dispose();
    super.dispose();
  }

  /// Entry easing for something that arrives at [from] seconds over [len].
  double _pop(double from, double len, {Curve curve = Curves.elasticOut}) {
    final u = ((_in.value * 2.6 - from) / len).clamp(0.0, 1.0);
    return curve.transform(u);
  }

  Widget _letters(String word, Color color, Color glow, double startAt, {bool fromBelow = false}) {
    final chars = word.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chars.length; i++)
          () {
            final drop = _pop(startAt + i * .09, 1.0);
            final wave = math.sin((_bob.value + i * .11) * math.pi * 2);
            return Transform.translate(
              offset: Offset(0, (fromBelow ? 140 : -160) * (1 - drop) + wave * 5),
              child: Transform.rotate(
                angle: (1 - drop) * (fromBelow ? -.4 : .4) + wave * .03,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    chars[i],
                    style: TextStyle(
                      color: color,
                      fontSize: 70,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      shadows: [Shadow(color: glow, blurRadius: 26 + 10 * wave)],
                    ),
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return FutureBuilder<void>(
      future: game.loaded,
      builder: (context, snap) {
        final ready = snap.connectionState == ConnectionState.done;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: ready ? game.showMap : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([_in, _bob]),
            builder: (context, _) {
              final beat = math.pow(math.max(0.0, math.sin(_bob.value * math.pi * 4)), 3).toDouble();
              final tilt = -.06 + .015 * math.sin(_bob.value * math.pi * 2);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/arena.png', fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x33000000), Color(0xCC000000)],
                      ),
                    ),
                  ),
                  // The title, hung a little crooked, riding a slow wave.
                  Align(
                    alignment: const Alignment(0.22, -0.28),
                    child: Transform.rotate(
                      angle: tilt,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _letters('SHADOW', Colors.white, const Color(0xFF7DEBFF), .1),
                          Transform.translate(
                            offset: const Offset(36, -10),
                            child: _letters('DUEL', _accent, const Color(0xFFFF8A3D), .55, fromBelow: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Tagline slides in from the right.
                  Align(
                    alignment: const Alignment(0.22, 0.2),
                    child: Transform.translate(
                      offset: Offset(300 * (1 - _pop(1.1, .9, curve: Curves.easeOutBack)), 0),
                      child: const Text(
                        'AN ENDLESS ROAD OF DUELS  ·  14 WARRIORS  ·  10 BLADES TO BUY AND FORGE',
                        style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 3),
                      ),
                    ),
                  ),
                  // The start pill: a heartbeat, so the thumb knows where to go.
                  Align(
                    alignment: const Alignment(0.22, 0.52),
                    child: Transform.scale(
                      scale: _pop(1.5, 1.0) * (1 + .08 * beat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFE28A), Color(0xFFE09A1E)]),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: kGoldPale, width: 2),
                          boxShadow: [BoxShadow(color: kGold.withValues(alpha: .35 + .35 * beat), blurRadius: 24 + 20 * beat)],
                        ),
                        child: Text(
                          ready ? 'TAP TO FIGHT' : 'LOADING…',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 7,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The purse swings down from the top bar.
                  if (ready)
                    Positioned(
                      top: 14,
                      right: 18,
                      child: Transform.translate(
                        offset: Offset(0, -90 * (1 - _pop(1.9, 1.0))),
                        child: Transform.rotate(
                          angle: .3 * (1 - _pop(1.9, 1.0)),
                          child: PurseChip(value: game.progress.coins, onTap: game.showArmory),
                        ),
                      ),
                    ),
                  // How far the road has been walked, swinging in from the left.
                  if (ready && game.progress.highestCleared > 0)
                    Positioned(
                      top: 16,
                      left: 18,
                      child: Transform.translate(
                        offset: Offset(-200 * (1 - _pop(2.0, 1.0)), 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xAA0B0913),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star_rounded, size: 16, color: _accent),
                            const SizedBox(width: 5),
                            Text('${game.progress.totalStars}',
                                style: const TextStyle(fontFamily: 'Kenney', color: _accent, fontSize: 14)),
                            const SizedBox(width: 12),
                            Text('STAGE ${game.progress.highestCleared + 1}',
                                style: const TextStyle(
                                    fontFamily: 'KenneyNarrow', color: Colors.white70, fontSize: 12, letterSpacing: 2)),
                          ]),
                        ),
                      ),
                    ),
                  // The door to the Dark: bottom left, breathing purple.
                  if (ready)
                    Positioned(
                      left: 18,
                      bottom: 16,
                      child: Transform.translate(
                        offset: Offset(0, 120 * (1 - _pop(2.2, 1.0))),
                        child: DarkDoor(onTap: game.showDark, pulse: _bob.value),
                      ),
                    ),
                  const Positioned(
                    right: 12,
                    bottom: 8,
                    child: Text(
                      'Art: LuizMelo (CC0) · Kyrise (CC BY 4.0) · Kenney (CC0)',
                      style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

/// Endless vertical stage map: stage 1 at the bottom, winding upward forever.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.game});
  final ShadowGame game;

  static const rowH = 132.0;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final ScrollController _scroll = ScrollController(
    initialScrollOffset:
        math.max(0, (widget.game.progress.highestCleared - 1) * MapScreen.rowH),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Material(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  _IconButton(icon: 'icon_home', onTap: game.showTitle),
                  const SizedBox(width: 14),
                  const Text(
                    'STAGE MAP',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 6),
                  ),
                  const Spacer(),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 18, color: _accent),
                    const SizedBox(width: 4),
                    Text(
                      '${game.progress.totalStars}',
                      style: const TextStyle(
                          fontFamily: 'Kenney', color: _accent, fontSize: 16, letterSpacing: 2),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'BEST  ${game.progress.highestCleared}',
                      style: const TextStyle(
                          fontFamily: 'KenneyNarrow', color: Colors.white60, fontSize: 13, letterSpacing: 2),
                    ),
                  ]),
                  const SizedBox(width: 14),
                  PurseChip(value: game.progress.coins, compact: true, onTap: game.showArmory),
                  const SizedBox(width: 14),
                  KButton(label: 'DOJO', onTap: game.showDojo, color: 'blue', width: 120, height: 44),
                  const SizedBox(width: 10),
                  KButton(label: 'ARMORY', onTap: game.showArmory, color: 'yellow', width: 140, height: 44),
                  const SizedBox(width: 10),
                  DarkDoor(onTap: game.showDark, compact: true),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  itemBuilder: (context, i) => _StageRow(game: game, stage: i + 1, width: c.maxWidth),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double _nodeX(int stage, double width) => width / 2 + math.sin(stage * 0.95) * width * 0.3;

class _StageRow extends StatelessWidget {
  const _StageRow({required this.game, required this.stage, required this.width});
  final ShadowGame game;
  final int stage;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cfg = game.stageCfg(stage);
    final highest = game.progress.highestCleared;
    final unlocked = game.progress.isUnlocked(stage);
    final cleared = stage <= highest;
    final sword = game.swordUnlockedByStage(stage);
    final x = _nodeX(stage, width);
    return SizedBox(
      height: MapScreen.rowH,
      width: width,
      child: CustomPaint(
        painter: _PathPainter(
          from: Offset(x, MapScreen.rowH / 2),
          to: Offset(_nodeX(stage + 1, width), -MapScreen.rowH / 2),
          lit: cleared,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: x - 44,
              top: MapScreen.rowH / 2 - 44,
              child: GestureDetector(
                onTap: unlocked ? () => game.startStage(stage) : null,
                child: SizedBox(
                  width: 88,
                  height: 110,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/images/ui/node_${cleared ? 'yellow' : unlocked ? 'blue' : 'grey'}.png',
                                fit: BoxFit.fill,
                              ),
                            ),
                            Center(
                              child: ClipOval(
                                child: ColorFiltered(
                                  colorFilter: unlocked
                                      ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                      : const ColorFilter.mode(Color(0xAA000000), BlendMode.srcATop),
                                  child: Image.asset(
                                    'assets/images/packs/${cfg.charKey}/portrait.png',
                                    width: 56,
                                    height: 56,
                                    filterQuality: FilterQuality.none,
                                  ),
                                ),
                              ),
                            ),
                            if (!unlocked)
                              Center(child: Image.asset('assets/images/ui/icon_locked.png', width: 30)),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _ink,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cleared ? _accent : Colors.white38, width: 2),
                                ),
                                child: Text(
                                  '$stage',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            if (sword != null)
                              // The blade this stage puts up for sale.
                              Positioned(
                                bottom: -8,
                                left: -10,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: _ink,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cleared ? sword.weapon.trail : Colors.white38, width: 2),
                                    boxShadow: [BoxShadow(color: sword.weapon.trail.withValues(alpha: cleared ? .5 : .15), blurRadius: 10)],
                                  ),
                                  child: Opacity(
                                    opacity: cleared ? 1 : .55,
                                    child: Image.asset('assets/images/swords/${sword.icon}.png',
                                        width: 26, height: 26, filterQuality: FilterQuality.none),
                                  ),
                                ),
                              ),
                            if (!cleared && unlocked)
                              // First clear pays the bounty.
                              Positioned(
                                top: -6,
                                left: -8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE61A1408),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: kGold.withValues(alpha: .8)),
                                  ),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    const CoinIcon(size: 10),
                                    const SizedBox(width: 3),
                                    Text('${Progress.reward(stage: stage, win: true, firstClear: true)}',
                                        style: const TextStyle(fontFamily: 'Kenney', color: kGoldPale, fontSize: 9)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cfg.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'KenneyNarrow',
                          color: unlocked ? Colors.white70 : Colors.white30,
                          fontSize: 10,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (cleared)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < 3; i++)
                              Icon(
                                i < game.progress.starsFor(stage)
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 13,
                                color: i < game.progress.starsFor(stage)
                                    ? _accent
                                    : Colors.white24,
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({required this.from, required this.to, required this.lit});
  final Offset from, to;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lit ? _accent.withValues(alpha: .7) : Colors.white24
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final d = to - from;
    final len = d.distance;
    final dir = d / len;
    for (var s = 0.0; s < len; s += 18) {
      canvas.drawLine(from + dir * s, from + dir * math.min(s + 9, len), paint);
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.from != from || old.to != to || old.lit != lit;
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Image.asset('assets/images/ui/$icon.png'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class ArmoryScreen extends StatefulWidget {
  const ArmoryScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  State<ArmoryScreen> createState() => _ArmoryScreenState();
}

class _ArmoryScreenState extends State<ArmoryScreen> with SingleTickerProviderStateMixin {
  int _selected = 0;

  /// A purchase or a forge: the blade flares and the panel jolts.
  late final AnimationController _flare =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _denied = false;

  @override
  void dispose() {
    _flare.dispose();
    super.dispose();
  }

  Future<void> _buy(Sword s) async {
    final p = widget.game.progress;
    if (!p.canBuy(s)) return _deny();
    await p.buy(s);
    widget.game.onArmoryChanged();
    Sfx.play('card', volume: .9);
    Sfx.play('win', volume: .5);
    HapticFeedback.heavyImpact();
    _denied = false;
    _flare.forward(from: 0);
    setState(() {});
  }

  Future<void> _forge(Sword s) async {
    final p = widget.game.progress;
    if (!p.canUpgrade(s)) return _deny();
    await p.upgrade(s);
    widget.game.onArmoryChanged();
    Sfx.play('shield', volume: .9);
    Sfx.play('heal', volume: .6);
    HapticFeedback.mediumImpact();
    _denied = false;
    _flare.forward(from: 0);
    setState(() {});
  }

  void _deny() {
    Sfx.play('immune', volume: .6);
    HapticFeedback.vibrate();
    _denied = true;
    _flare.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final progress = game.progress;
    final highest = progress.highestCleared;
    final sword = progress.forged(Swords.all[_selected]);
    final owned = progress.owns(sword);
    final tint = sword.weapon.trail;

    return Material(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The arena itself, pushed back behind the rack.
          Image.asset('assets/images/arena.png', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF20A0812), Color(0xE6140F22), Color(0xF20A0812)],
              ),
            ),
          ),
          // A wash of the selected blade's colour; it flares on a purchase.
          AnimatedBuilder(
            animation: _flare,
            builder: (context, _) {
              final f = (1 - _flare.value);
              final col = _denied ? const Color(0xFFFF5A5A) : tint;
              return IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.35, 0.1),
                      radius: 1.1 + .4 * f,
                      colors: [col.withValues(alpha: (owned ? .22 : .06) + .4 * f * f), Colors.transparent],
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _ArmoryHeader(game: game),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The rack.
                      SizedBox(
                        width: 300,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 4, 8, 16),
                          itemCount: Swords.all.length,
                          itemBuilder: (context, i) {
                            final s = progress.forged(Swords.all[i]);
                            return _RackSlot(
                              sword: s,
                              owned: progress.owns(s),
                              onSale: progress.onSale(s),
                              affordable: progress.canAfford(s.price),
                              selected: i == _selected,
                              onTap: () {
                                Sfx.play('card', volume: .7);
                                setState(() => _selected = i);
                              },
                            );
                          },
                        ),
                      ),
                      // The blade under the light.
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _flare,
                          builder: (context, child) {
                            final f = 1 - _flare.value;
                            final dx = _denied ? math.sin(_flare.value * math.pi * 6) * 10 * f : 0.0;
                            final sc = _denied ? 1.0 : 1 + .05 * math.sin(f * math.pi);
                            return Transform.translate(
                              offset: Offset(dx, 0),
                              child: Transform.scale(scale: sc, alignment: Alignment.topLeft, child: child),
                            );
                          },
                          child: _BladeDetail(
                            sword: sword,
                            owned: owned,
                            onSale: progress.onSale(sword),
                            coins: progress.coins,
                            highest: highest,
                            onBuy: () => _buy(sword),
                            onForge: () => _forge(sword),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArmoryHeader extends StatelessWidget {
  const _ArmoryHeader({required this.game});
  final ShadowGame game;

  @override
  Widget build(BuildContext context) {
    final owned = game.progress.ownedSwords.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 8),
      child: Row(
        children: [
          _GlyphButton(icon: 'icon_return', onTap: game.showMap),
          const SizedBox(width: 14),
          const Text(
            'ARMORY',
            style: TextStyle(
              fontFamily: 'Kenney',
              color: Colors.white,
              fontSize: 26,
              letterSpacing: 4,
              shadows: [Shadow(color: Color(0xFF7DEBFF), blurRadius: 18)],
            ),
          ),
          const SizedBox(width: 12),
          const Text('buy  ·  forge  ·  fight',
              style: TextStyle(fontFamily: 'KenneyNarrow', color: Colors.white38, fontSize: 11, letterSpacing: 3)),
          const Spacer(),
          _Counter(
              icon: Icons.shield_moon_outlined,
              value: '$owned/${Swords.all.length}',
              tint: const Color(0xFF7DEBFF)),
          const SizedBox(width: 14),
          PurseChip(value: game.progress.coins),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.icon, required this.value, required this.tint});
  final IconData icon;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x66000000),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: .5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: tint),
        const SizedBox(width: 6),
        Text(value,
            style: TextStyle(
                fontFamily: 'Kenney', color: tint, fontSize: 14, letterSpacing: 1.5)),
      ]),
    );
  }
}

/// One blade in the rack down the left-hand side.
class _RackSlot extends StatelessWidget {
  const _RackSlot({
    required this.sword,
    required this.owned,
    required this.onSale,
    required this.affordable,
    required this.selected,
    required this.onTap,
  });

  final Sword sword;
  final bool owned, onSale, affordable, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = sword.weapon.trail;
    return Springy(
      pressScale: .96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            selected ? tint.withValues(alpha: .28) : const Color(0x33141024),
            const Color(0x11000000),
          ]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: selected ? tint.withValues(alpha: .6) : Colors.white10),
        ),
        child: Row(
          children: [
            // Blade-coloured spine down the left edge.
            Container(
              width: 4,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: selected ? tint : tint.withValues(alpha: owned ? .35 : .12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: owned ? 1 : (onSale ? .7 : .3),
                    child: Image.asset('assets/images/swords/${sword.icon}.png',
                        filterQuality: FilterQuality.none),
                  ),
                  if (!onSale)
                    Image.asset('assets/images/ui/icon_locked.png', width: 18, color: Colors.white70),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sword.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Kenney',
                      fontSize: 13,
                      letterSpacing: 1.5,
                      color: owned || onSale ? Colors.white : Colors.white38,
                    ),
                  ),
                  if (owned)
                    // Forge marks as pips.
                    Row(children: [
                      for (var i = 0; i < Sword.maxLevel; i++)
                        Container(
                          width: 9,
                          height: 5,
                          margin: const EdgeInsets.only(right: 3, top: 3),
                          decoration: BoxDecoration(
                            color: i < sword.level ? tint : Colors.white12,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: i < sword.level ? [BoxShadow(color: tint.withValues(alpha: .6), blurRadius: 5)] : null,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(sword.maxed ? 'MASTERWORK' : 'MK ${sword.level + 1}',
                          style: TextStyle(fontFamily: 'KenneyNarrow', fontSize: 9, letterSpacing: 1.5, color: tint)),
                    ])
                  else if (onSale)
                    Row(children: [
                      const CoinIcon(size: 11),
                      const SizedBox(width: 3),
                      Text('${sword.price}',
                          style: TextStyle(
                              fontFamily: 'Kenney',
                              fontSize: 11,
                              color: affordable ? kGoldPale : Colors.white38)),
                      if (affordable) ...[
                        const SizedBox(width: 6),
                        const Text('BUY',
                            style: TextStyle(fontFamily: 'KenneyNarrow', fontSize: 9, letterSpacing: 2, color: kGold)),
                      ],
                    ])
                  else
                    Text(
                      'CLEAR STAGE ${sword.unlockLevel}',
                      style: const TextStyle(
                          fontFamily: 'KenneyNarrow', fontSize: 10, letterSpacing: 1.5, color: Colors.white30),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.chevron_right_rounded, color: tint, size: 20),
          ],
        ),
      ),
    );
  }
}

/// The selected blade, lit like a display case.
class _BladeDetail extends StatelessWidget {
  const _BladeDetail({
    required this.sword,
    required this.owned,
    required this.onSale,
    required this.coins,
    required this.highest,
    required this.onBuy,
    required this.onForge,
  });
  final Sword sword;
  final bool owned, onSale;
  final int coins, highest;
  final VoidCallback onBuy, onForge;

  @override
  Widget build(BuildContext context) {
    final w = sword.weapon;
    final tint = w.trail;
    final (artV, artW) = Arts.of(sword.id);
    // What the next mark would do, ghosted behind the current pips.
    final next = owned && !sword.maxed ? sword.at(sword.level + 1).weapon : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(10, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Blade on its pedestal.
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    tint.withValues(alpha: owned ? .35 : .1),
                    Colors.transparent,
                  ]),
                  border: Border.all(color: tint.withValues(alpha: owned ? .8 : .25), width: 2),
                ),
                padding: const EdgeInsets.all(18),
                child: Opacity(
                  opacity: owned ? 1 : .35,
                  child: Image.asset('assets/images/swords/${sword.icon}.png',
                      filterQuality: FilterQuality.none),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sword.name,
                      style: TextStyle(
                        fontFamily: 'Kenney',
                        fontSize: 30,
                        letterSpacing: 3,
                        color: Colors.white,
                        shadows: [Shadow(color: tint, blurRadius: 20)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: owned ? tint.withValues(alpha: .18) : Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: owned ? tint : Colors.white24),
                      ),
                      child: Text(
                        owned
                            ? (sword.maxed ? 'IN YOUR DECK  ·  MASTERWORK' : 'IN YOUR DECK  ·  MK ${sword.level + 1}')
                            : (onSale ? 'ON THE RACK  ·  FOR SALE' : 'LOCKED  ·  CLEAR STAGE ${sword.unlockLevel}'),
                        style: TextStyle(
                            fontFamily: 'KenneyNarrow',
                            fontSize: 11,
                            letterSpacing: 2,
                            color: owned ? tint : Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ShopAction(
                      sword: sword,
                      owned: owned,
                      onSale: onSale,
                      coins: coins,
                      onBuy: onBuy,
                      onForge: onForge,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatBar(label: 'STRENGTH', value: w.strength, next: next?.strength, max: 2.6, tint: tint),
          _StatBar(label: 'POWER', value: w.power, next: next?.power, max: 3.0, tint: tint),
          _StatBar(label: 'SPEED', value: w.speed, next: next?.speed, max: 1.6, tint: tint),
          _StatBar(label: 'REACH', value: w.range.toDouble(), next: next?.range, max: 60, tint: tint),
          const SizedBox(height: 12),
          Row(children: [
            _TimeChip(label: 'ACTIVE', seconds: sword.active, tint: const Color(0xFF6CF0A0)),
            const SizedBox(width: 10),
            _TimeChip(label: 'RECHARGE', seconds: sword.recharge, tint: const Color(0xFFFF8B7B)),
          ]),
          const SizedBox(height: 18),
          Text('SWORD ARTS',
              style: TextStyle(
                  fontFamily: 'Kenney', fontSize: 13, letterSpacing: 3, color: tint)),
          const SizedBox(height: 8),
          _ArtLine(art: artV, tint: tint),
          const SizedBox(height: 8),
          _ArtLine(art: artW, tint: tint),
        ],
      ),
    );
  }
}

/// A segmented stat meter — pips, not a progress bar.
class _StatBar extends StatelessWidget {
  const _StatBar({required this.label, required this.value, required this.max, required this.tint, this.next});
  final String label;
  final double value, max;

  /// The value after the next forge mark: shown as ghost pips.
  final double? next;
  final Color tint;

  static const _pips = 12;

  @override
  Widget build(BuildContext context) {
    final filled = (value / max * _pips).clamp(0, _pips).round();
    final ghost = next == null ? filled : (next! / max * _pips).clamp(0, _pips).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: const TextStyle(
                    fontFamily: 'KenneyNarrow',
                    fontSize: 11,
                    letterSpacing: 1.6,
                    color: Colors.white60)),
          ),
          for (var i = 0; i < _pips; i++)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(
                color: i < filled
                    ? tint.withValues(alpha: .85)
                    : (i < ghost ? kGold.withValues(alpha: .35) : Colors.white10),
                borderRadius: BorderRadius.circular(2),
                border: i >= filled && i < ghost ? Border.all(color: kGold.withValues(alpha: .7)) : null,
                boxShadow: i < filled
                    ? [BoxShadow(color: tint.withValues(alpha: .5), blurRadius: 6)]
                    : null,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            max > 10 ? value.toStringAsFixed(0) : '\u00d7${value.toStringAsFixed(2)}',
            style: const TextStyle(
                fontFamily: 'KenneyNarrow', fontSize: 11, color: Colors.white54),
          ),
          if (next != null && ghost > filled)
            Text(
              max > 10 ? '  \u2192 ${next!.toStringAsFixed(0)}' : '  \u2192 ${next!.toStringAsFixed(2)}',
              style: const TextStyle(fontFamily: 'KenneyNarrow', fontSize: 11, color: kGold),
            ),
        ],
      ),
    );
  }
}

/// The one button that matters in the shop: buy the blade, or forge the
/// next mark into it. Greyed with the shortfall when the purse is light.
class _ShopAction extends StatelessWidget {
  const _ShopAction({
    required this.sword,
    required this.owned,
    required this.onSale,
    required this.coins,
    required this.onBuy,
    required this.onForge,
  });
  final Sword sword;
  final bool owned, onSale;
  final int coins;
  final VoidCallback onBuy, onForge;

  @override
  Widget build(BuildContext context) {
    if (!owned && !onSale) {
      return Text('Clear stage ${sword.unlockLevel} to put this blade on the rack.',
          style: const TextStyle(color: Colors.white38, fontSize: 12));
    }
    if (owned && sword.maxed) {
      return Row(children: [
        const Icon(Icons.auto_awesome, color: kGold, size: 16),
        const SizedBox(width: 6),
        const Text('MASTERWORK  ·  nothing left to forge',
            style: TextStyle(fontFamily: 'KenneyNarrow', color: kGold, fontSize: 12, letterSpacing: 2)),
      ]);
    }
    final cost = owned ? sword.upgradeCost : sword.price;
    final can = coins >= cost;
    final label = owned ? 'FORGE  MK ${sword.level + 2}' : 'BUY';
    return Row(children: [
      Springy(
        pressScale: .9,
        // A light purse still taps through: the shop shakes its head.
        onTap: owned ? onForge : onBuy,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 9, 14, 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: can
                  ? const [Color(0xFFFFE28A), Color(0xFFE09A1E)]
                  : const [Color(0xFF3A3A48), Color(0xFF26262F)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: can ? [BoxShadow(color: kGold.withValues(alpha: .45), blurRadius: 18)] : null,
            border: Border.all(color: can ? kGoldPale : Colors.white12, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'Kenney',
                    fontSize: 15,
                    letterSpacing: 2,
                    color: can ? _ink : Colors.white38)),
            const SizedBox(width: 12),
            CoinIcon(size: can ? 18 : 14),
            const SizedBox(width: 5),
            Text('$cost',
                style: TextStyle(
                    fontFamily: 'Kenney', fontSize: 16, color: can ? _ink : Colors.white54)),
          ]),
        ),
      ),
      if (!can) ...[
        const SizedBox(width: 12),
        Text('${cost - coins} more',
            style: const TextStyle(fontFamily: 'KenneyNarrow', color: Color(0xFFFF8B7B), fontSize: 12, letterSpacing: 1.5)),
      ],
    ]);
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.seconds, required this.tint});
  final String label;
  final double seconds;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: .55)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ',
            style: const TextStyle(
                fontFamily: 'KenneyNarrow', fontSize: 11, letterSpacing: 1.5, color: Colors.white54)),
        Text('${seconds.toStringAsFixed(0)}s',
            style: TextStyle(fontFamily: 'Kenney', fontSize: 15, color: tint)),
      ]),
    );
  }
}

/// One sword art: the glyph to draw, its name, effect and cooldown.
class _ArtLine extends StatelessWidget {
  const _ArtLine({required this.art, required this.tint});
  final SwordArt art;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            margin: const EdgeInsets.only(right: 9),
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tint, width: 2),
              boxShadow: [BoxShadow(color: tint.withValues(alpha: .45), blurRadius: 10)],
            ),
            child: Text(art.glyph,
                style: TextStyle(
                    fontFamily: 'Kenney', color: tint, fontSize: 16, height: 1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(art.name.toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'Kenney',
                            fontSize: 14,
                            letterSpacing: 2,
                            color: Colors.white)),
                  ),
                  Text('${art.cooldown.toStringAsFixed(0)}s',
                      style: const TextStyle(
                          fontFamily: 'KenneyNarrow', fontSize: 11, color: Colors.white38)),
                ]),
                const SizedBox(height: 2),
                Text(art.description,
                    style: const TextStyle(fontSize: 12, height: 1.3, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round icon button used across the game screens.
class _GlyphButton extends StatelessWidget {
  const _GlyphButton({required this.icon, required this.onTap});
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', volume: .6);
        onTap();
      },
      child: Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0x66000000),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Image.asset('assets/images/ui/$icon.png'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Battle paused: resume, or bail out to the map.
class PauseScreen extends StatelessWidget {
  const PauseScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  Widget build(BuildContext context) {
    final where = game.practising
        ? 'DOJO  ·  SPARRING'
        : game.inDarkTrial
            ? 'DARK TRIAL  ·  ${game.opponentName}'
            : 'STAGE ${game.stage}  ·  ${game.opponentName}';
    return Container(
      color: const Color(0xCC05040A),
      alignment: Alignment.center,
      child: Container(
        width: 420,
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
        decoration: BoxDecoration(
          color: const Color(0xF2100D1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7DEBFF), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x667DEBFF), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAUSED',
                style: TextStyle(
                  fontFamily: 'Kenney',
                  fontSize: 34,
                  letterSpacing: 8,
                  color: Colors.white,
                  shadows: [Shadow(color: Color(0xFF7DEBFF), blurRadius: 18)],
                )),
            const SizedBox(height: 4),
            Text(where,
                style: const TextStyle(
                    fontFamily: 'KenneyNarrow',
                    fontSize: 12,
                    letterSpacing: 3,
                    color: Colors.white54)),
            const SizedBox(height: 20),
            KButton(label: 'RESUME', onTap: game.resumeFight, color: 'blue', width: 230),
            const SizedBox(height: 10),
            KButton(label: game.practising ? 'BACK TO DOJO' : (game.inDarkTrial ? 'BACK TO THE DARK' : 'QUIT TO MAP'),
                onTap: game.quitToMap, color: 'grey', width: 230),
            const SizedBox(height: 10),
            Text(game.practising ? 'the dummy will miss you' : 'quitting forfeits this stage',
                style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// After the duel: the card slams in, the stars drop one by one, then the
/// pay-out rains and whips up into the purse. Once it has, the forge lights
/// up: the whole point of the coins is the next blade.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with TickerProviderStateMixin {
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();
  late final AnimationController _cta =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  final _purseKey = GlobalKey();
  Offset? _purseAt;
  late int _shown = widget.game.coinsBefore;
  bool _collected = false;

  @override
  void initState() {
    super.initState();
    // Measure the purse once it has finished dropping into place (the coins
    // only start flying after that).
    WidgetsBinding.instance.addPostFrameCallback((_) => _locatePurse());
    Future<void>.delayed(const Duration(milliseconds: 1250), _locatePurse);
  }

  void _locatePurse() {
    if (!mounted) return;
    final box = _purseKey.currentContext?.findRenderObject() as RenderBox?;
    final root = context.findRenderObject() as RenderBox?;
    if (box == null || root == null) return;
    final c = box.localToGlobal(box.size.center(Offset.zero), ancestor: root);
    setState(() => _purseAt = c);
  }

  @override
  void dispose() {
    _in.dispose();
    _cta.dispose();
    super.dispose();
  }

  /// A slice of the intro clock, 0..1, eased with a bounce.
  double _pop(double from, double len, {Curve curve = Curves.elasticOut}) {
    final u = ((_in.value * 2.4 - from) / len).clamp(0.0, 1.0);
    return curve.transform(u);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final win = game.lastWin;
    final trial = game.darkTrial;
    final unlocked = game.lastUnlocked;
    final coins = game.lastCoins;
    final first = game.lastFirstClear;
    final bounty = !win
        ? 'A COIN FOR THE ROAD'
        : trial != null
            ? 'DARK PURSE'
            : (first ? 'FIRST CLEAR BOUNTY' : 'SPOILS  ·  ALREADY CLEARED');
    final where = trial != null ? 'DARK TRIAL ${trial + 1}  ·  ${game.opponentName}' : 'STAGE ${game.stage}  ·  ${game.opponentName}';
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      final source = size.center(const Offset(0, -10));
      final target = _purseAt ?? Offset(size.width - 70, 32);
      return AnimatedBuilder(
        animation: Listenable.merge([_in, _cta]),
        builder: (context, _) {
          final cardIn = _pop(0, 1.0);
          final tilt = (1 - _pop(0, 1.0, curve: Curves.easeOutBack)) * -.12;
          return Stack(
            fit: StackFit.expand,
            children: [
              Container(color: Color.lerp(const Color(0x00000000), const Color(0xA6000000), _pop(0, .3, curve: Curves.easeOut))),
              // The purse, top right, where every coin is headed.
              Positioned(
                top: 14,
                right: 18,
                child: Transform.translate(
                  offset: Offset(0, -80 * (1 - _pop(.2, .9))),
                  child: PurseChip(key: _purseKey, value: _shown),
                ),
              ),
              Center(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scaleByDouble(.55 + .45 * cardIn, .55 + .45 * cardIn, 1, 1)
                    ..rotateZ(tilt),
                  child: Container(
                    width: 500,
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
                    decoration: BoxDecoration(
                      color: const Color(0xF0100D1A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: win ? _accent : const Color(0xFFFF6B6B), width: 2.5),
                      boxShadow: [
                        BoxShadow(color: (win ? _accent : const Color(0xFFFF6B6B)).withValues(alpha: .25), blurRadius: 40)
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: .6 + .4 * _pop(.15, .9),
                          child: Text(
                            win ? 'VICTORY' : 'DEFEAT',
                            style: TextStyle(
                              color: win ? _accent : const Color(0xFFFF8B7B),
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 10,
                              height: 1,
                              shadows: [Shadow(color: win ? const Color(0xFFFF8A3D) : const Color(0xFFFF2B2B), blurRadius: 24)],
                            ),
                          ),
                        ),
                        Text(
                          where,
                          style: const TextStyle(
                              fontFamily: 'KenneyNarrow', color: Colors.white70, fontSize: 13, letterSpacing: 3),
                        ),
                        if (win) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < 3; i++)
                                Transform.translate(
                                  offset: Offset(0, -60 * (1 - _pop(.45 + i * .18, .8, curve: Curves.bounceOut))),
                                  child: Transform.rotate(
                                    angle: (i - 1) * .18 * (1 - _pop(.45 + i * .18, .8)),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 3),
                                      child: Icon(
                                        i < game.lastStars ? Icons.star_rounded : Icons.star_outline_rounded,
                                        size: i < game.lastStars ? 46 : 36,
                                        color: i < game.lastStars ? _accent : Colors.white24,
                                        shadows: i < game.lastStars ? const [Shadow(color: _accent, blurRadius: 18)] : null,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (game.lastNewStars)
                            const Text('NEW BEST',
                                style: TextStyle(fontFamily: 'Kenney', color: _accent, fontSize: 12, letterSpacing: 4)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ScoreCell(
                                  label: 'HEALTH LEFT',
                                  value: '${(game.lastHpFrac * 100).round()}%',
                                  hit: game.lastHpFrac >= .5),
                              const SizedBox(width: 14),
                              _ScoreCell(
                                  label: 'BEST COMBO',
                                  value: '${game.stageMaxCombo}',
                                  hit: game.stageMaxCombo >= 8),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),
                        // The pay-out line: what the duel paid and why.
                        Transform.scale(
                          scale: .3 + .7 * _pop(.95, 1.0),
                          child: Column(children: [
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              const CoinIcon(size: 26),
                              const SizedBox(width: 8),
                              Text(
                                '+$coins',
                                style: TextStyle(
                                  fontFamily: 'Kenney',
                                  color: kGoldPale,
                                  fontSize: first ? 40 : 30,
                                  height: 1,
                                  letterSpacing: 2,
                                  shadows: const [Shadow(color: kGoldDeep, blurRadius: 16)],
                                ),
                              ),
                            ]),
                            Text(bounty,
                                style: TextStyle(
                                    fontFamily: 'KenneyNarrow',
                                    color: first ? kGold : Colors.white54,
                                    fontSize: 11,
                                    letterSpacing: 3)),
                          ]),
                        ),
                        if (unlocked != null) ...[
                          const SizedBox(height: 14),
                          Transform.translate(
                            offset: Offset(0, 30 * (1 - _pop(1.3, .9))),
                            child: Opacity(
                              opacity: _pop(1.3, .5, curve: Curves.easeOut),
                              child: _UnveiledBlade(sword: unlocked),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (trial != null)
                              KButton(
                                label: win ? 'THE DARK' : 'RETRY',
                                onTap: win ? game.showDark : () => game.retryDarkTrial(),
                                color: win ? 'yellow' : 'red',
                                width: 160,
                              )
                            else
                              KButton(
                                label: win ? 'NEXT STAGE' : 'RETRY',
                                onTap: win ? game.nextStage : game.retryStage,
                                color: win ? 'yellow' : 'red',
                                width: 160,
                              ),
                            const SizedBox(width: 10),
                            // The forge: pulses once the purse has been filled.
                            Transform.scale(
                              scale: 1 + (_collected ? .06 * math.sin(_cta.value * math.pi * 2) : 0),
                              child: KButton(
                                label: _collected ? 'FORGE  ◆' : 'FORGE',
                                onTap: game.showArmory,
                                color: _collected ? 'green' : 'grey',
                                width: 150,
                              ),
                            ),
                            const SizedBox(width: 10),
                            KButton(label: trial != null ? 'BACK' : 'MAP', onTap: trial != null ? game.showDark : game.showMap, color: 'grey', width: 100),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              CoinShower(
                  amount: coins,
                  source: source,
                  target: target,
                  big: first,
                  delay: 1.1,
                  onCollected: (n) => setState(() => _shown = game.coinsBefore + n),
                  onDone: () {
                    if (!mounted) return;
                    setState(() => _collected = true);
                    _cta.repeat();
                  },
                ),
            ],
          );
        },
      );
    });
  }
}

/// A blade newly put up for sale by the stage just cleared.
class _UnveiledBlade extends StatelessWidget {
  const _UnveiledBlade({required this.sword});
  final Sword sword;

  @override
  Widget build(BuildContext context) {
    final tint = sword.weapon.trail;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: .5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: tint.withValues(alpha: .6), blurRadius: 18)],
            ),
            child: Image.asset('assets/images/swords/${sword.icon}.png', filterQuality: FilterQuality.none),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NEW ON THE RACK',
                  style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 4)),
              Text(sword.name,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 3)),
              Row(children: [
                const CoinIcon(size: 13),
                const SizedBox(width: 4),
                Text('${sword.price}',
                    style: const TextStyle(fontFamily: 'Kenney', color: kGoldPale, fontSize: 13)),
                const SizedBox(width: 8),
                Text(sword.weapon.special?.title ?? '',
                    style: TextStyle(color: tint, fontSize: 11, letterSpacing: 1)),
              ]),
            ],
          ),
        ],
      ),
    );
  }
}


/// One number on the victory card — lit when it earned you a star.
class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.label, required this.value, required this.hit});
  final String label, value;
  final bool hit;

  @override
  Widget build(BuildContext context) {
    final tint = hit ? _accent : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x33000000),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: .5)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontFamily: 'Kenney', fontSize: 20, color: tint)),
        Text(label,
            style: const TextStyle(
                fontFamily: 'KenneyNarrow', fontSize: 10, letterSpacing: 1.5, color: Colors.white54)),
      ]),
    );
  }
}


// ---------------------------------------------------------------------------

/// The way into the paid Dark section. Nothing behind it asks for a sign-in
/// until it is pressed.
class DarkDoor extends StatelessWidget {
  const DarkDoor({super.key, required this.onTap, this.pulse = 0, this.compact = false});
  final VoidCallback onTap;
  final double pulse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final glow = .5 + .5 * math.sin(pulse * math.pi * 2);
    return Springy(
      onTap: () {
        Sfx.play('click', volume: .6);
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: compact ? 10 : 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2A0F4A), Color(0xFF12071F)]),
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          border: Border.all(color: const Color(0xFFC77DFF), width: 2),
          boxShadow: [BoxShadow(color: const Color(0xFFC77DFF).withValues(alpha: .25 + .3 * glow), blurRadius: 16 + 14 * glow)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.nightlight_round, size: 16, color: Color(0xFFC77DFF)),
          const SizedBox(width: 8),
          Text(compact ? 'DARK' : 'THE DARK',
              style: const TextStyle(
                  fontFamily: 'Kenney',
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 4,
                  shadows: [Shadow(color: Color(0xFFC77DFF), blurRadius: 12)])),
          if (!compact) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFC77DFF), borderRadius: BorderRadius.circular(6)),
              child: const Text('PAID', style: TextStyle(color: _ink, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ],
        ]),
      ),
    );
  }
}
