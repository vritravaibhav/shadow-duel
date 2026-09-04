import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/combos.dart';
import '../game/sfx.dart';
import '../game/shadow_game.dart';
import '../game/sprites.dart';
import '../game/tutorial.dart';
import '../game/weapons.dart';
import 'screens.dart';

const _bg = Color(0xFF0B0913);
const _panel = Color(0xFF15122A);
const _accent = Color(0xFFFFD75A);

/// The dojo: every one of the 64 two-stick combos on one board, each with
/// its own animation preview, and the tutorial that teaches them.
class DojoScreen extends StatefulWidget {
  const DojoScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  State<DojoScreen> createState() => _DojoScreenState();
}

class _DojoScreenState extends State<DojoScreen> {
  int _tab = 0;
  Combo _selected = Combo.of(Dir.fwd, Dir.fwd);

  void _select(Combo c) {
    if (c == _selected) return;
    Sfx.play('click', volume: .4);
    setState(() => _selected = c);
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _IconButton(icon: 'icon_home', onTap: game.showMap),
                  const SizedBox(width: 14),
                  const Text(
                    'DOJO',
                    style: TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 6),
                  ),
                  const SizedBox(width: 22),
                  _Tab(label: 'COMBOS', on: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  const SizedBox(width: 6),
                  _Tab(label: 'TUTORIAL', on: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  const Spacer(),
                  const Text(
                    '8 × 8 = 64 COMBOS',
                    style: TextStyle(
                        fontFamily: 'KenneyNarrow', color: Colors.white38, fontSize: 12, letterSpacing: 2),
                  ),
                  const SizedBox(width: 14),
                  KButton(
                    label: 'SPAR',
                    onTap: () => game.startPractice(0),
                    color: 'yellow',
                    width: 110,
                    height: 40,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _tab == 0
                  ? _ComboBoard(game: game, selected: _selected, onSelect: _select)
                  : _TutorialList(game: game),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.play('click', volume: .5);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF2B3350) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? const Color(0xFF7DEBFF) : Colors.white24, width: 1.4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: on ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
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
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1F1B33),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.all(8),
        child: Image.asset('assets/images/ui/$icon.png', filterQuality: FilterQuality.none),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The 8 × 8 board (left stick down the side, right stick along the top),
/// coloured by what the pair does, next to the selected combo's card.
class _ComboBoard extends StatelessWidget {
  const _ComboBoard({required this.game, required this.selected, required this.onSelect});
  final ShadowGame game;
  final Combo selected;
  final void Function(Combo) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              children: [
                const _Legend(),
                const SizedBox(height: 6),
                Expanded(child: _Grid(selected: selected, onSelect: onSelect)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(flex: 9, child: _ComboCard(game: game, combo: selected)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const rules = {
      ComboKind.attack: 'both at the enemy',
      ComboKind.block: 'left away · right at them',
      ComboKind.stepBack: 'both away',
      ComboKind.advance: 'left at them · right away',
    };
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final k in ComboKind.values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: k.color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: k.color.withValues(alpha: .6)),
            ),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 9.5, letterSpacing: 1, color: Colors.white70),
                children: [
                  TextSpan(
                      text: '${k.title}  ',
                      style: TextStyle(color: k.color, fontWeight: FontWeight.w900)),
                  TextSpan(text: rules[k]),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.selected, required this.onSelect});
  final Combo selected;
  final void Function(Combo) onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const label = 26.0;
      final cell = math.min((c.maxHeight - label) / 8, (c.maxWidth - label) / 8);
      final w = label + cell * 8;
      final h = label + cell * 8;
      Widget glyph(Dir d, {bool left = false}) => SizedBox(
            width: left ? label : cell,
            height: left ? cell : label,
            child: Center(
              child: Text(
                d.glyph(),
                style: TextStyle(
                  fontSize: cell * .42,
                  color: left ? const Color(0xFF99E8FF) : const Color(0xFFFF8B7B),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Column(
            children: [
              Row(children: [
                SizedBox(
                  width: label,
                  height: label,
                  child: const Center(
                    child: Text('L\\R',
                        style: TextStyle(fontSize: 8, color: Colors.white38, letterSpacing: 0)),
                  ),
                ),
                for (final r in Dir.values) glyph(r),
              ]),
              for (final l in Dir.values)
                Row(children: [
                  glyph(l, left: true),
                  for (final r in Dir.values)
                    _Cell(combo: Combo.of(l, r), size: cell, selected: selected, onSelect: onSelect),
                ]),
            ],
          ),
        ),
      );
    });
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.combo, required this.size, required this.selected, required this.onSelect});
  final Combo combo;
  final double size;
  final Combo selected;
  final void Function(Combo) onSelect;

  @override
  Widget build(BuildContext context) {
    final on = combo == selected;
    final col = combo.kind.color;
    // The cell's footprint must be exactly [size]: the grid budgets 8 of them
    // per axis, so the gutter has to come out of the box, not add to it.
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => onSelect(combo),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: col.withValues(alpha: on ? .55 : (combo.isSmash ? .4 : .18)),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: on ? Colors.white : col.withValues(alpha: .35), width: on ? 2 : 1),
            boxShadow: on ? [BoxShadow(color: col.withValues(alpha: .6), blurRadius: 10)] : null,
          ),
          child: combo.isSmash
              ? Center(
                  child: Text('☠',
                      style: TextStyle(fontSize: size * .5, color: Colors.white, height: 1)),
                )
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The selected combo: its animation, the sticks to hold, and what it does.
class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.game, required this.combo});
  final ShadowGame game;
  final Combo combo;

  int _lessonFor(Combo c) => switch (c.kind) {
        ComboKind.attack => c.isSmash ? 8 : 1,
        ComboKind.block => c.parry ? 5 : 4,
        ComboKind.stepBack => 6,
        ComboKind.advance => 7,
      };

  @override
  Widget build(BuildContext context) {
    final col = combo.kind.color;
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: col.withValues(alpha: .7), width: 1.5),
        boxShadow: [BoxShadow(color: col.withValues(alpha: .18), blurRadius: 24)],
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  combo.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Kenney',
                    fontSize: 18,
                    letterSpacing: 2,
                    color: Colors.white,
                    shadows: [Shadow(color: Color(0x887DEBFF), blurRadius: 12)],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: col.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: col),
                ),
                child: Text(combo.kind.title,
                    style: TextStyle(
                        color: col, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: ComboPreview(game: game, combo: combo),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StickPair(combo: combo),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            combo.desc,
                            style: const TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _Facts(combo: combo, weapon: game.hero.weapon),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'spar to feel it: the dojo dummy never falls',
                  style: TextStyle(color: Colors.white.withValues(alpha: .35), fontSize: 10, letterSpacing: 1),
                ),
              ),
              KButton(
                label: 'TRY IT',
                onTap: () => game.startPractice(_lessonFor(combo)),
                color: 'blue',
                width: 120,
                height: 38,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "HOLD  LEFT ◥  +  RIGHT ►" with mini stick diagrams.
class _StickPair extends StatelessWidget {
  const _StickPair({required this.combo});
  final Combo combo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MiniStick(dir: combo.left, color: const Color(0xFF99E8FF), label: 'LEFT'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('+', style: TextStyle(color: Colors.white54, fontSize: 18, fontWeight: FontWeight.w900)),
        ),
        _MiniStick(dir: combo.right, color: const Color(0xFFFF8B7B), label: 'RIGHT'),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'enemy on the right  ►',
            style: TextStyle(color: Colors.white.withValues(alpha: .4), fontSize: 9, letterSpacing: 1),
          ),
        ),
      ],
    );
  }
}

class _MiniStick extends StatelessWidget {
  const _MiniStick({required this.dir, required this.color, required this.label});
  final Dir dir;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(size: const Size(44, 44), painter: _StickPainter(dir, color)),
        const SizedBox(height: 2),
        Text('$label ${dir.glyph()}',
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
      ],
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter(this.dir, this.color);
  final Dir dir;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: .08));
    canvas.drawCircle(
        c, r, Paint()..color = Colors.white24..style = PaintingStyle.stroke..strokeWidth = 1);
    for (final d in Dir.values) {
      final a = math.atan2(-d.v.toDouble(), d.h.toDouble());
      final on = d == dir;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), a - .26, .52, false,
          Paint()
            ..color = on ? color : Colors.white24
            ..style = PaintingStyle.stroke
            ..strokeWidth = on ? 3.5 : 1.5
            ..strokeCap = StrokeCap.round);
    }
    final knob = c + dir.vector / dir.vector.distance * (r - 9);
    canvas.drawLine(c, knob, Paint()..color = color.withValues(alpha: .5)..strokeWidth = 2);
    canvas.drawCircle(knob, 7, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StickPainter old) => old.dir != dir || old.color != color;
}

/// Target, stroke and guard facts for the selected combo.
class _Facts extends StatelessWidget {
  const _Facts({required this.combo, required this.weapon});
  final Combo combo;
  final Weapon weapon;

  @override
  Widget build(BuildContext context) {
    final facts = <(String, String)>[];
    switch (combo.kind) {
      case ComboKind.attack:
        final m = moveFor(combo, weapon, 1, .4, .7, smash: combo.isSmash);
        facts.add(('TARGET', combo.zoneName.toUpperCase()));
        facts.add(('STROKE', combo.aerial ? 'LEAP' : (combo.leg ? 'LEG' : 'BLADE')));
        facts.add(('DAMAGE', m.dmg.round().toString()));
        if (combo.lunges) facts.add(('MOVES', 'LUNGES IN'));
        if (m.kup > 200) facts.add(('TRIPS', 'YES'));
        if (combo.isSmash) facts.add(('GUARD', 'IGNORED'));
      case ComboKind.block:
        facts.add(('COVERS', combo.guardName.toUpperCase()));
        facts.add(('TAKES', combo.parry ? 'NOTHING' : '25%'));
        if (combo.parry) facts.add(('ENEMY', 'STAGGERS'));
      case ComboKind.stepBack:
        facts.add(('MOVES', 'AWAY'));
        facts.add(('COVERS', combo.guardName.toUpperCase()));
      case ComboKind.advance:
        facts.add(('MOVES', combo.left.toward ? 'IN' : 'HOLDS'));
        facts.add(('COVERS', combo.guardName.toUpperCase()));
    }
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final (k, v) in facts)
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'KenneyNarrow', fontSize: 10, letterSpacing: 1),
              children: [
                TextSpan(text: '$k  ', style: const TextStyle(color: Colors.white38)),
                TextSpan(text: v, style: const TextStyle(color: _accent)),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Plays the combo's clip with the real hero sprites, exactly as the fighter
/// does in battle: enter, two cycles, exit, pause, again.
class ComboPreview extends StatefulWidget {
  const ComboPreview({super.key, required this.game, required this.combo});
  final ShadowGame game;
  final Combo combo;

  @override
  State<ComboPreview> createState() => _ComboPreviewState();
}

class _ComboPreviewState extends State<ComboPreview> with SingleTickerProviderStateMixin {
  late final ComboPlayer _player = ComboPlayer(widget.game.sprites, widget.game.hero.charKey);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _x = 0, _pause = 0, _t = 0;
  int _stage = 0;

  @override
  void initState() {
    super.initState();
    _restart();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(ComboPreview old) {
    super.didUpdateWidget(old);
    if (old.combo != widget.combo) _restart();
  }

  void _restart() {
    _player.start(widget.combo);
    _x = 0;
    _pause = 0;
    _stage = 0;
    _t = 0;
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > .1) dt = .1;
    _t += dt;
    if (_pause > 0) {
      _pause -= dt;
      if (_pause <= 0) _restart();
      setState(() {});
      return;
    }
    final ev = _player.advance(dt);
    if (_stage == 0 && ev == ComboEvent.cycle) _stage = 1;
    if (_player.stage == ComboStage.loop && _player.cycles >= 2 && !_player.released) {
      _player.release(now: _player.combo!.kind != ComboKind.attack);
    }
    if (ev == ComboEvent.finished || !_player.active) {
      _pause = .5;
    }
    _x += _player.dxRate * dt;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PreviewPainter(
        player: _player,
        x: _x,
        t: _t,
        color: widget.combo.kind.color,
        idle: widget.game.sprites.anim(widget.game.hero.charKey, 'idle'),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter({required this.player, required this.x, required this.t, required this.color, required this.idle});
  final ComboPlayer player;
  final double x, t;
  final Color color;
  final BakedAnim idle;

  @override
  void paint(Canvas canvas, Size size) {
    // Floor.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0E0C1C));
    final floorY = size.height * .82;
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, size.width, size.height - floorY),
      Paint()..color = color.withValues(alpha: .08),
    );
    canvas.drawLine(Offset(0, floorY), Offset(size.width, floorY),
        Paint()..color = color.withValues(alpha: .35)..strokeWidth = 1);
    // Body: one game unit is scaled so a 150-unit fighter fills the box.
    final s = size.height * .58 / 150;
    final feet = Offset(size.width * .38 + x * s, floorY);
    final shW = 48 * s * math.max(.4, 1 - player.hop / 260);
    canvas.drawOval(
      Rect.fromCenter(center: feet, width: shW, height: shW * .3),
      Paint()..color = Colors.black.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    final sample = player.active ? player.sample() : null;
    final ba = sample?.anim ?? idle;
    final fi = sample?.frame ?? idle.frameAt(t / idle.duration);
    canvas.save();
    canvas.translate(feet.dx, feet.dy - (sample?.hop ?? 0) * s);
    canvas.scale((ba.flip ? -1 : 1) * s, s);
    if (sample != null) {
      canvas.scale(1 + (1 - sample.squash) * .5, sample.squash);
      canvas.skew(-sample.lean, 0);
    }
    ba.frames[fi].render(
      canvas,
      position: Vector2(-ba.ax / ba.scale, -ba.ay / ba.scale),
      size: Vector2(ba.fw / ba.scale, ba.fh / ba.scale),
      overridePaint: Paint()..filterQuality = ba.pixel ? FilterQuality.none : FilterQuality.medium,
    );
    canvas.restore();
    // Stage read-out.
    final stage = player.active ? player.stage.name.toUpperCase() : 'READY';
    final tp = TextPainter(
      text: TextSpan(
        text: player.active && player.stage == ComboStage.loop ? '$stage ${player.cycles + 1}' : stage,
        style: TextStyle(color: color.withValues(alpha: .8), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width - tp.width - 8, 6));
    if (player.clip?.dedicated == true) {
      final dp = TextPainter(
        text: const TextSpan(
          text: 'HAND-MADE',
          style: TextStyle(color: _accent, fontSize: 8, letterSpacing: 2, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dp.paint(canvas, const Offset(8, 6));
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => true;
}

// ---------------------------------------------------------------------------

/// The tutorial: the four rules, then every lesson with a practice button.
class _TutorialList extends StatelessWidget {
  const _TutorialList({required this.game});
  final ShadowGame game;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('THE FOUR RULES',
                  style: TextStyle(
                      fontFamily: 'Kenney', color: Colors.white, fontSize: 14, letterSpacing: 3)),
              const SizedBox(height: 6),
              const Text(
                'Hold both sticks. Where the LEFT stick points shapes your body: its height is the target '
                '(▲ head, ► body, ▼ legs) and toward or away is footwork. The RIGHT stick is the blade: '
                '▲ leaps, ► cuts, ▼ kicks. Keep holding and the move repeats; change the sticks and the '
                'fighter flows into the next one.',
                style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final (k, text) in const [
                    (ComboKind.attack, 'BOTH sticks at the enemy'),
                    (ComboKind.block, 'LEFT away, RIGHT at the enemy at the blow\'s height'),
                    (ComboKind.stepBack, 'BOTH sticks away'),
                    (ComboKind.advance, 'LEFT at the enemy, RIGHT away'),
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: k.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: k.color.withValues(alpha: .7)),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 10.5, color: Colors.white70, letterSpacing: .5),
                          children: [
                            TextSpan(
                                text: '${k.title}   ',
                                style: TextStyle(color: k.color, fontWeight: FontWeight.w900, letterSpacing: 2)),
                            TextSpan(text: text),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < Lesson.all.length; i++) _LessonRow(game: game, index: i),
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.game, required this.index});
  final ShadowGame game;
  final int index;

  @override
  Widget build(BuildContext context) {
    final lesson = Lesson.all[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: .15),
              border: Border.all(color: _accent),
            ),
            child: Text('${index + 1}',
                style: const TextStyle(fontFamily: 'Kenney', color: _accent, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lesson.title,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 3)),
                const SizedBox(height: 2),
                Text(lesson.text, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (lesson.left != null) _MiniStick(dir: lesson.left!, color: const Color(0xFF99E8FF), label: 'LEFT'),
          if (lesson.left != null && lesson.right != null) const SizedBox(width: 6),
          if (lesson.right != null) _MiniStick(dir: lesson.right!, color: const Color(0xFFFF8B7B), label: 'RIGHT'),
          const SizedBox(width: 12),
          KButton(
            label: 'PRACTICE',
            onTap: () => game.startPractice(index),
            color: 'blue',
            width: 130,
            height: 38,
          ),
        ],
      ),
    );
  }
}
