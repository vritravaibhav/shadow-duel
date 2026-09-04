import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/arts.dart';
import '../game/sfx.dart';
import '../game/shadow_game.dart';
import '../game/weapons.dart';

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
    return GestureDetector(
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

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
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
          child: Stack(
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
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'SHADOW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 16,
                      height: 1,
                      shadows: [Shadow(color: Color(0xFF7DEBFF), blurRadius: 30)],
                    ),
                  ),
                  const Text(
                    'DUEL',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 64,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 16,
                      height: 1,
                      shadows: [Shadow(color: Color(0xFFFF8A3D), blurRadius: 30)],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'AN ENDLESS ROAD OF DUELS  ·  14 WARRIORS  ·  10 BLADES',
                    style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 3),
                  ),
                  const SizedBox(height: 44),
                  FadeTransition(
                    opacity: Tween(begin: .35, end: 1.0).animate(_pulse),
                    child: Text(
                      ready ? 'TAP TO START' : 'LOADING…',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 7,
                      ),
                    ),
                  ),
                ],
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
                  const SizedBox(width: 18),
                  KButton(label: 'DOJO', onTap: game.showDojo, color: 'blue', width: 120, height: 44),
                  const SizedBox(width: 10),
                  KButton(label: 'ARMORY', onTap: game.showArmory, color: 'yellow', width: 140, height: 44),
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
                              Positioned(
                                bottom: -8,
                                left: -10,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: _ink,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: sword.weapon.trail, width: 2),
                                    boxShadow: [BoxShadow(color: sword.weapon.trail.withValues(alpha: .5), blurRadius: 10)],
                                  ),
                                  child: Image.asset('assets/images/swords/${sword.icon}.png',
                                      width: 26, height: 26, filterQuality: FilterQuality.none),
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

class _ArmoryScreenState extends State<ArmoryScreen> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final highest = game.progress.highestCleared;
    final sword = Swords.all[_selected];
    final owned = sword.unlockLevel <= highest;
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
          // A wash of the selected blade's colour.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.35, 0.1),
                  radius: 1.1,
                  colors: [tint.withValues(alpha: owned ? .22 : .06), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _ArmoryHeader(game: game, highest: highest),
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
                          itemBuilder: (context, i) => _RackSlot(
                            sword: Swords.all[i],
                            index: i,
                            owned: Swords.all[i].unlockLevel <= highest,
                            selected: i == _selected,
                            onTap: () {
                              Sfx.play('card', volume: .7);
                              setState(() => _selected = i);
                            },
                          ),
                        ),
                      ),
                      // The blade under the light.
                      Expanded(
                        child: _BladeDetail(sword: sword, owned: owned),
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
  const _ArmoryHeader({required this.game, required this.highest});
  final ShadowGame game;
  final int highest;

  @override
  Widget build(BuildContext context) {
    final owned = Swords.unlockedAt(highest).length;
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
          const Spacer(),
          _Counter(icon: Icons.star_rounded, value: '${game.progress.totalStars}', tint: _accent),
          const SizedBox(width: 14),
          _Counter(
              icon: Icons.shield_moon_outlined,
              value: '$owned/${Swords.all.length}',
              tint: const Color(0xFF7DEBFF)),
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
    required this.index,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final Sword sword;
  final int index;
  final bool owned, selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = sword.weapon.trail;
    return GestureDetector(
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
                    opacity: owned ? 1 : .3,
                    child: Image.asset('assets/images/swords/${sword.icon}.png',
                        filterQuality: FilterQuality.none),
                  ),
                  if (!owned)
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
                      color: owned ? Colors.white : Colors.white38,
                    ),
                  ),
                  Text(
                    owned ? 'MK ${index + 1}' : 'STAGE ${sword.unlockLevel}',
                    style: TextStyle(
                        fontFamily: 'KenneyNarrow',
                        fontSize: 10,
                        letterSpacing: 1.5,
                        color: owned ? tint : Colors.white30),
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
  const _BladeDetail({required this.sword, required this.owned});
  final Sword sword;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final w = sword.weapon;
    final tint = w.trail;
    final (artV, artW) = Arts.of(sword.id);
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
                        owned ? 'IN YOUR DECK' : 'LOCKED  ·  CLEAR STAGE ${sword.unlockLevel}',
                        style: TextStyle(
                            fontFamily: 'KenneyNarrow',
                            fontSize: 11,
                            letterSpacing: 2,
                            color: owned ? tint : Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _StatBar(label: 'STRENGTH', value: w.strength, max: 2.0, tint: tint),
          _StatBar(label: 'POWER', value: w.power, max: 2.4, tint: tint),
          _StatBar(label: 'SPEED', value: w.speed, max: 1.4, tint: tint),
          _StatBar(label: 'REACH', value: w.range.toDouble(), max: 50, tint: tint),
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
  const _StatBar({required this.label, required this.value, required this.max, required this.tint});
  final String label;
  final double value, max;
  final Color tint;

  static const _pips = 12;

  @override
  Widget build(BuildContext context) {
    final filled = (value / max * _pips).clamp(0, _pips).round();
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
                color: i < filled ? tint.withValues(alpha: .85) : Colors.white10,
                borderRadius: BorderRadius.circular(2),
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
        ],
      ),
    );
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
    final cfg = game.stageCfg(game.stage);
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
            Text(game.practising ? 'DOJO  ·  SPARRING' : 'STAGE ${game.stage}  ·  ${cfg.name}',
                style: const TextStyle(
                    fontFamily: 'KenneyNarrow',
                    fontSize: 12,
                    letterSpacing: 3,
                    color: Colors.white54)),
            const SizedBox(height: 20),
            KButton(label: 'RESUME', onTap: game.resumeFight, color: 'blue', width: 230),
            const SizedBox(height: 10),
            KButton(label: game.practising ? 'BACK TO DOJO' : 'QUIT TO MAP',
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

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  Widget build(BuildContext context) {
    final win = game.lastWin;
    final cfg = game.stageCfg(game.stage);
    final unlocked = game.lastUnlocked;
    return Container(
      color: const Color(0x99000000),
      alignment: Alignment.center,
      child: Container(
        width: 480,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
        decoration: BoxDecoration(
          color: const Color(0xF0100D1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: win ? _accent : const Color(0xFFFF6B6B), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              win ? 'VICTORY' : 'DEFEAT',
              style: TextStyle(
                color: win ? _accent : const Color(0xFFFF8B7B),
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 10,
              ),
            ),
            Text(
              'STAGE ${game.stage}  ·  ${cfg.name}',
              style: const TextStyle(
                  fontFamily: 'KenneyNarrow', color: Colors.white70, fontSize: 13, letterSpacing: 3),
            ),
            if (win) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Icon(
                        i < game.lastStars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: i < game.lastStars ? 44 : 36,
                        color: i < game.lastStars ? _accent : Colors.white24,
                        shadows: i < game.lastStars
                            ? const [Shadow(color: _accent, blurRadius: 18)]
                            : null,
                      ),
                    ),
                ],
              ),
              if (game.lastNewStars)
                const Text('NEW BEST',
                    style: TextStyle(
                        fontFamily: 'Kenney', color: _accent, fontSize: 12, letterSpacing: 4)),
              const SizedBox(height: 10),
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
            if (unlocked != null) ...[
              const SizedBox(height: 18),
              const Text('NEW BLADE CLAIMED',
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 4)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: unlocked.weapon.trail.withValues(alpha: .6), blurRadius: 18)],
                    ),
                    child: Image.asset('assets/images/swords/${unlocked.icon}.png',
                        filterQuality: FilterQuality.none),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unlocked.name,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3)),
                        Text('${unlocked.weapon.special?.title}: ${unlocked.weapon.special?.description}',
                            maxLines: 2,
                            style: TextStyle(color: unlocked.weapon.trail, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KButton(
                  label: win ? 'NEXT STAGE' : 'RETRY',
                  onTap: win ? game.nextStage : game.retryStage,
                  color: win ? 'yellow' : 'red',
                  width: 170,
                ),
                const SizedBox(width: 14),
                KButton(label: 'MAP', onTap: game.showMap, color: 'grey', width: 120),
              ],
            ),
          ],
        ),
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
