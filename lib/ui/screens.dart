import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/arts.dart';
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
      onTap: onTap,
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
                  Text(
                    'BEST  ${game.progress.highestCleared}',
                    style: const TextStyle(color: _accent, fontSize: 14, letterSpacing: 3),
                  ),
                  const SizedBox(width: 18),
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
                          color: unlocked ? Colors.white70 : Colors.white30,
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
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

class ArmoryScreen extends StatelessWidget {
  const ArmoryScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  Widget build(BuildContext context) {
    final highest = game.progress.highestCleared;
    return Material(
      color: _bg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  _IconButton(icon: 'icon_return', onTap: game.showMap),
                  const SizedBox(width: 14),
                  const Text(
                    'ARMORY',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 6),
                  ),
                  const Spacer(),
                  Text(
                    '${Swords.unlockedAt(highest).length} / ${Swords.all.length} BLADES',
                    style: const TextStyle(color: _accent, fontSize: 13, letterSpacing: 3),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: Swords.all.length,
                itemBuilder: (context, i) => _SwordRow(sword: Swords.all[i], highest: highest),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwordRow extends StatelessWidget {
  const _SwordRow({required this.sword, required this.highest});
  final Sword sword;
  final int highest;

  @override
  Widget build(BuildContext context) {
    final w = sword.weapon;
    final owned = sword.unlockLevel <= highest;
    final tint = w.trail;
    Widget chip(String label) => Container(
          margin: const EdgeInsets.only(right: 6, top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
        );
    return Opacity(
      opacity: owned ? 1 : .55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF15121F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: owned ? tint.withValues(alpha: .7) : Colors.white12, width: 1.5),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(12),
                boxShadow: owned ? [BoxShadow(color: tint.withValues(alpha: .35), blurRadius: 16)] : null,
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset('assets/images/swords/${sword.icon}.png', filterQuality: FilterQuality.none),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(sword.name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 3)),
                      const Spacer(),
                      Text(
                        owned ? 'OWNED' : 'CLEAR STAGE ${sword.unlockLevel}',
                        style: TextStyle(
                            color: owned ? _accent : Colors.white54, fontSize: 11, letterSpacing: 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${w.special?.title.toUpperCase()}  —  ${w.special?.description}',
                    style: TextStyle(color: tint, fontSize: 12),
                  ),
                  Wrap(
                    children: [
                      chip('STRENGTH ×${w.strength.toStringAsFixed(2)}'),
                      chip('POWER ×${w.power.toStringAsFixed(1)}'),
                      chip('SPEED ×${w.speed.toStringAsFixed(2)}'),
                      chip('RECHARGE ${sword.recharge.toStringAsFixed(0)}s'),
                      chip('DURABILITY ${sword.durability.toStringAsFixed(0)}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ArtLine(art: Arts.of(sword.id).$1, tint: tint),
                  const SizedBox(height: 4),
                  _ArtLine(art: Arts.of(sword.id).$2, tint: tint),
                ],
              ),
            ),
          ],
        ),
      ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: tint, width: 1.5),
            boxShadow: [BoxShadow(color: tint.withValues(alpha: .35), blurRadius: 8)],
          ),
          child: Text(art.glyph,
              style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.w900, height: 1)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.35),
              children: [
                TextSpan(
                    text: 'DRAW ${art.glyph}  ',
                    style: TextStyle(color: tint, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                TextSpan(
                    text: art.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                TextSpan(text: '  —  ${art.description}'),
                TextSpan(
                    text: '   ${art.cooldown.toStringAsFixed(0)}s',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
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
              style: const TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 3),
            ),
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
