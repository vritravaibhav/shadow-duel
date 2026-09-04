import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/netplay.dart';
import '../game/shadow_game.dart';
import '../game/sprites.dart';
import '../ui/coins.dart';
import '../ui/screens.dart' show KButton;
import 'dark_roster.dart';
import 'dark_services.dart';
import 'rtc.dart';

const kDark = Color(0xFFC77DFF);
const kDarkDeep = Color(0xFF5A1E9E);
const _ink = Color(0xFF0B0913);

/// The Dark: a paid side of the arena with its own roster, AI trials and
/// live duels with voice and chat. Firebase wakes up here and nowhere else;
/// the sign-in card is the first thing behind the door.
class DarkScreen extends StatefulWidget {
  const DarkScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  State<DarkScreen> createState() => _DarkScreenState();
}

enum _Step { boot, unavailable, auth, paywall, hub }

class _DarkScreenState extends State<DarkScreen> with SingleTickerProviderStateMixin {
  _Step _step = _Step.boot;
  StreamSubscription? _authSub, _entSub;
  bool? _entitled;
  late final AnimationController _in =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Dark.ensureFirebase();
    if (!mounted) return;
    if (!Dark.ready) {
      setState(() => _step = _Step.unavailable);
      return;
    }
    _authSub = Dark.auth.authStateChanges().listen((u) {
      _entSub?.cancel();
      _entSub = null;
      if (u == null) {
        setState(() {
          _entitled = null;
          _step = _Step.auth;
        });
        return;
      }
      setState(() => _step = _Step.boot);
      _entSub = Dark.entitlement(u.uid).listen((ok) {
        if (!mounted) return;
        setState(() {
          _entitled = ok;
          _step = ok ? _Step.hub : _Step.paywall;
        });
      }, onError: (_) {
        if (mounted) setState(() => _step = _Step.paywall);
      });
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _entSub?.cancel();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/arena.png', fit: BoxFit.cover, color: const Color(0xCC08040F), colorBlendMode: BlendMode.multiply),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -.3), radius: 1.1, colors: [Color(0x553A0F6E), Color(0xEE05030A)]),
          ),
        ),
        AnimatedBuilder(
          animation: _in,
          builder: (context, child) => Opacity(
            opacity: Curves.easeOut.transform(_in.value),
            child: Transform.translate(offset: Offset(0, 30 * (1 - Curves.easeOutBack.transform(_in.value))), child: child),
          ),
          child: switch (_step) {
            _Step.boot => const Center(child: _Pulse('OPENING THE DOOR…')),
            _Step.unavailable => _Card(
                title: 'THE DARK IS SHUT',
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'Firebase could not start on this device.\n${Dark.initError ?? ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  KButton(label: 'BACK', onTap: game.showTitle, color: 'grey', width: 140, height: 44),
                ]),
              ),
            _Step.auth => _AuthCard(onBack: game.showTitle),
            _Step.paywall => _Paywall(onBack: game.showTitle, entitled: _entitled ?? false),
            _Step.hub => _Hub(game: game),
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _Pulse extends StatefulWidget {
  const _Pulse(this.text);
  final String text;
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Opacity(
          opacity: .5 + .5 * math.sin(_c.value * math.pi * 2).abs(),
          child: Text(widget.text,
              style: const TextStyle(fontFamily: 'Kenney', color: kDark, fontSize: 16, letterSpacing: 5)),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.width = 460, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
          decoration: BoxDecoration(
            color: const Color(0xF20E0817),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kDark, width: 2),
            boxShadow: const [BoxShadow(color: Color(0x66C77DFF), blurRadius: 36)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontFamily: 'Kenney',
                    fontSize: 30,
                    letterSpacing: 8,
                    color: Colors.white,
                    shadows: [Shadow(color: kDark, blurRadius: 18)],
                  )),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontFamily: 'KenneyNarrow', fontSize: 12, letterSpacing: 3, color: Colors.white54)),
                ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _field(String label, {IconData? icon}) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, letterSpacing: 2, fontSize: 12),
      prefixIcon: icon == null ? null : Icon(icon, color: kDark, size: 18),
      isDense: true,
      filled: true,
      fillColor: const Color(0x33000000),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kDark, width: 2)),
    );

// ---------------------------------------------------------------------------

/// Sign in, make an account, or walk in as a guest. Only here: the front
/// page never asks.
class _AuthCard extends StatefulWidget {
  const _AuthCard({required this.onBack});
  final VoidCallback onBack;
  @override
  State<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends State<_AuthCard> {
  final _email = TextEditingController(), _pass = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await f();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'THE DARK',
      subtitle: 'MEMBERS ONLY  ·  SIGN IN TO ENTER',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _field('EMAIL', icon: Icons.alternate_email),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: _field('PASSWORD', icon: Icons.key),
            onSubmitted: (_) => _run(() => Dark.signIn(_email.text, _pass.text)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8B7B), fontSize: 12)),
          ],
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            KButton(
                label: 'SIGN IN',
                onTap: _busy ? null : () => _run(() => Dark.signIn(_email.text, _pass.text)),
                color: 'yellow',
                width: 150,
                height: 46),
            const SizedBox(width: 10),
            KButton(
                label: 'NEW ACCOUNT',
                onTap: _busy ? null : () => _run(() => Dark.register(_email.text, _pass.text)),
                color: 'blue',
                width: 170,
                height: 46),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            KButton(label: 'ENTER AS GUEST', onTap: _busy ? null : () => _run(Dark.guest), color: 'grey', width: 190, height: 42),
            const SizedBox(width: 10),
            KButton(label: 'BACK', onTap: widget.onBack, color: 'grey', width: 110, height: 42),
          ]),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// The velvet rope. The entitlement is written server-side; this card only
/// asks the store and watches the document flip.
class _Paywall extends StatefulWidget {
  const _Paywall({required this.onBack, required this.entitled});
  final VoidCallback onBack;
  final bool entitled;
  @override
  State<_Paywall> createState() => _PaywallState();
}

class _PaywallState extends State<_Paywall> {
  String? _note;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final u = Dark.user;
    return _Card(
      title: 'THE DARK',
      subtitle: '18+  ·  A PAID ARENA',
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: const [
              _Perk(Icons.female, 'THE WOMEN OF THE ARENA'),
              _Perk(Icons.people_alt, 'LIVE DUELS'),
              _Perk(Icons.mic, 'VOICE + CHAT'),
              _Perk(Icons.local_fire_department, 'DARK TRIALS'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Four fighters you cannot meet on the road, AI trials against them, and live duels '
            'with another player: your own voice on the line, a chat box, a mute button.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          Springy(
            onTap: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final n = await DarkStore.purchase();
                    if (mounted) {
                      setState(() {
                        _busy = false;
                        _note = n;
                      });
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE2B8FF), kDark, kDarkDeep]),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white70, width: 2),
                boxShadow: const [BoxShadow(color: Color(0x88C77DFF), blurRadius: 26)],
              ),
              child: Text('UNLOCK THE DARK  ·  ${DarkStore.priceLabel}',
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 4)),
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            SelectableText(_note!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFD27D), fontSize: 11, fontFamily: 'monospace', height: 1.5)),
          ],
          const SizedBox(height: 12),
          Text(
            u == null ? '' : 'signed in as ${u.isAnonymous ? 'guest' : (u.email ?? u.uid)}  ·  uid ${u.uid}',
            style: const TextStyle(color: Colors.white38, fontSize: 10),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            KButton(label: 'SIGN OUT', onTap: Dark.signOut, color: 'grey', width: 130, height: 42),
            const SizedBox(width: 10),
            KButton(label: 'BACK', onTap: widget.onBack, color: 'grey', width: 110, height: 42),
          ]),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x33C77DFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x66C77DFF)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: kDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontFamily: 'KenneyNarrow', color: Colors.white, fontSize: 11, letterSpacing: 2)),
        ]),
      );
}

// ---------------------------------------------------------------------------

/// Inside: pick who you fight as, take a trial, or open a line to another
/// player.
class _Hub extends StatefulWidget {
  const _Hub({required this.game});
  final ShadowGame game;
  @override
  State<_Hub> createState() => _HubState();
}

class _HubState extends State<_Hub> {
  int _pick = 0;
  final _name = TextEditingController(text: 'SHADOW');
  final _code = TextEditingController();
  RtcSession? _session;
  String? _lobbyNote;

  @override
  void initState() {
    super.initState();
    Dark.loadProfile().then((p) {
      if (!mounted || p == null) return;
      setState(() {
        if (p.$1.isNotEmpty) _name.text = p.$1;
        final i = DarkRoster.all.indexWhere((f) => f.charKey == p.$2);
        if (i >= 0) _pick = i;
      });
    });
    final s = RtcSession.current;
    if (s != null && s.state.value != RtcState.closed) {
      _session = s;
      s.state.addListener(_onSessionState);
    }
  }

  @override
  void dispose() {
    _session?.state.removeListener(_onSessionState);
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  void _onSessionState() {
    if (mounted) setState(() {});
  }

  Seat _seat() {
    final me = DarkRoster.all[_pick];
    final name = _name.text.trim().isEmpty ? 'SHADOW' : _name.text.trim().toUpperCase();
    Dark.saveProfile(name, me.charKey);
    return Seat(Dark.user!.uid, name, me.charKey);
  }

  void _wire(RtcSession s) {
    _session = s;
    s.state.addListener(_onSessionState);
    s.onReady = (s) {
      final peer = s.peer!;
      widget.game.startNetDuel(NetDuel(s),
          myName: s.me.name, myChar: s.me.char, theirName: peer.name, theirChar: peer.char);
    };
    setState(() => _lobbyNote = null);
  }

  Future<void> _host() async {
    try {
      _wire(await RtcSession.host(_seat()));
    } catch (e) {
      setState(() => _lobbyNote = 'could not open a room: $e');
    }
  }

  Future<void> _join() async {
    if (_code.text.trim().length < 4) {
      setState(() => _lobbyNote = 'enter the 4-letter room code');
      return;
    }
    try {
      _wire(await RtcSession.join(_code.text, _seat()));
    } catch (e) {
      setState(() => _lobbyNote = 'could not join: $e');
    }
  }

  void _cancel() {
    final s = _session;
    s?.state.removeListener(_onSessionState);
    s?.close();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final me = DarkRoster.all[_pick];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Column(
          children: [
            Row(children: [
              KButton(label: '◄', onTap: game.showTitle, color: 'grey', width: 54, height: 40),
              const SizedBox(width: 14),
              const Text('THE DARK',
                  style: TextStyle(
                      fontFamily: 'Kenney',
                      fontSize: 26,
                      letterSpacing: 8,
                      color: Colors.white,
                      shadows: [Shadow(color: kDark, blurRadius: 18)])),
              const Spacer(),
              PurseChip(value: game.progress.coins, compact: true, onTap: game.showArmory),
              const SizedBox(width: 10),
              KButton(label: 'SIGN OUT', onTap: Dark.signOut, color: 'grey', width: 120, height: 40),
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Who you fight as.
                  Expanded(
                    flex: 5,
                    child: _Panel(
                      title: 'FIGHT AS',
                      child: Column(children: [
                        Expanded(
                          child: Row(children: [
                            Expanded(
                              child: _FighterView(sprites: game.sprites, charKey: me.charKey, key: ValueKey(me.charKey)),
                            ),
                            SizedBox(
                              width: 150,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < DarkRoster.all.length; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3),
                                      child: Springy(
                                        onTap: () => setState(() => _pick = i),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: i == _pick ? const Color(0x55C77DFF) : const Color(0x22000000),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: i == _pick ? kDark : Colors.white12, width: i == _pick ? 2 : 1),
                                          ),
                                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(DarkRoster.all[i].name,
                                                style: TextStyle(
                                                    fontFamily: 'Kenney',
                                                    fontSize: 13,
                                                    letterSpacing: 3,
                                                    color: i == _pick ? Colors.white : Colors.white70)),
                                            Text(DarkRoster.all[i].title,
                                                style: const TextStyle(fontSize: 9, color: Colors.white38, letterSpacing: 1)),
                                          ]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ]),
                        ),
                        TextField(
                          controller: _name,
                          maxLength: 12,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white, fontFamily: 'Kenney', letterSpacing: 3),
                          decoration: _field('YOUR NAME', icon: Icons.badge).copyWith(counterText: ''),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Trials against the roster.
                  Expanded(
                    flex: 3,
                    child: _Panel(
                      title: 'DARK TRIALS',
                      child: ListView(
                        children: [
                          for (var i = 0; i < DarkRoster.all.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _TrialRow(
                                index: i,
                                fighter: DarkRoster.all[i],
                                onTap: () => game.startDarkTrial(
                                  StageCfg(100 + i, DarkRoster.all[i].name, DarkRoster.all[i].charKey,
                                      DarkRoster.all[i].hp, DarkRoster.all[i].dmg, DarkRoster.all[i].agg, DarkRoster.all[i].speed),
                                  i,
                                  heroName: _seat().name,
                                  heroChar: me.charKey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Live duels.
                  Expanded(
                    flex: 3,
                    child: _Panel(
                      title: 'LIVE DUEL',
                      child: _session == null ? _lobbyIdle() : _lobbyLive(_session!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lobbyIdle() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Host a room and read the code to a friend, or type theirs.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 11, height: 1.4)),
        const SizedBox(height: 14),
        KButton(label: 'HOST A DUEL', onTap: _host, color: 'yellow', width: 200, height: 46),
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          maxLength: 4,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontFamily: 'Kenney', fontSize: 22, letterSpacing: 10),
          decoration: _field('ROOM CODE').copyWith(counterText: ''),
          onSubmitted: (_) => _join(),
        ),
        const SizedBox(height: 8),
        KButton(label: 'JOIN', onTap: _join, color: 'blue', width: 160, height: 44),
        if (_lobbyNote != null) ...[
          const SizedBox(height: 10),
          Text(_lobbyNote!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8B7B), fontSize: 11)),
        ],
        const SizedBox(height: 8),
        const Text('voice opens with the duel  ·  mute any time',
            style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
      ],
    );
  }

  Widget _lobbyLive(RtcSession s) {
    final st = s.state.value;
    final label = switch (st) {
      RtcState.waiting => 'WAITING FOR A CHALLENGER',
      RtcState.connecting => 'CROSSING BLADES…',
      RtcState.connected => 'CONNECTED',
      RtcState.failed => 'THE LINE DROPPED',
      RtcState.closed => 'CLOSED',
      RtcState.idle => '…',
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (s.isHost) ...[
          const Text('ROOM CODE', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 4),
          SelectableText(s.code,
              style: const TextStyle(
                  fontFamily: 'Kenney',
                  fontSize: 44,
                  letterSpacing: 14,
                  color: Colors.white,
                  shadows: [Shadow(color: kDark, blurRadius: 20)])),
          const SizedBox(height: 10),
        ],
        if (st == RtcState.failed)
          Text(label, style: const TextStyle(fontFamily: 'KenneyNarrow', color: Color(0xFFFF8B7B), fontSize: 12, letterSpacing: 3))
        else
          _Pulse(label),
        if (s.peer != null) ...[
          const SizedBox(height: 8),
          Text('${s.peer!.name}  ·  ${DarkRoster.byKey(s.peer!.char).name}',
              style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2)),
        ],
        const SizedBox(height: 16),
        KButton(label: st == RtcState.failed ? 'BACK' : 'CANCEL', onTap: _cancel, color: 'grey', width: 140, height: 42),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xCC0E0817),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x66C77DFF), width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontFamily: 'Kenney', color: kDark, fontSize: 13, letterSpacing: 5)),
          const SizedBox(height: 8),
          Expanded(child: child),
        ]),
      );
}

class _TrialRow extends StatelessWidget {
  const _TrialRow({required this.index, required this.fighter, required this.onTap});
  final int index;
  final DarkFighter fighter;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Springy(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Color.lerp(const Color(0x33C77DFF), const Color(0x66FF3D7D), index / 3)!, const Color(0x22000000)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(children: [
            Text('${index + 1}', style: const TextStyle(fontFamily: 'Kenney', color: kDark, fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fighter.name, style: const TextStyle(fontFamily: 'Kenney', color: Colors.white, fontSize: 14, letterSpacing: 3)),
                Text(fighter.title, style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
              ]),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const CoinIcon(size: 14),
              const SizedBox(width: 4),
              Text('${8 + 4 * index}', style: const TextStyle(fontFamily: 'Kenney', color: kGoldPale, fontSize: 12)),
            ]),
          ]),
        ),
      );
}

/// A fighter idling on a dark floor, drawn from her pack.
class _FighterView extends StatefulWidget {
  const _FighterView({super.key, required this.sprites, required this.charKey});
  final SpriteLibrary sprites;
  final String charKey;
  @override
  State<_FighterView> createState() => _FighterViewState();
}

class _FighterViewState extends State<_FighterView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      _t += (e - _last).inMicroseconds / 1e6;
      _last = e;
      setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _FighterPainter(widget.sprites.animOr(widget.charKey, 'idle'), _t),
        child: const SizedBox.expand(),
      );
}

class _FighterPainter extends CustomPainter {
  _FighterPainter(this.anim, this.t);
  final BakedAnim anim;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final floorY = size.height * .86;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width / 2, floorY), width: size.width * .5, height: 18),
      Paint()..color = kDark.withValues(alpha: .18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    final s = size.height * .7 / 150;
    final fi = anim.frameAt(t / anim.duration);
    canvas.save();
    canvas.translate(size.width / 2, floorY);
    canvas.scale((anim.flip ? -1 : 1) * s, s);
    anim.frames[fi].render(
      canvas,
      position: Vector2(-anim.ax / anim.scale, -anim.ay / anim.scale),
      size: Vector2(anim.fw / anim.scale, anim.fh / anim.scale),
      overridePaint: Paint()..filterQuality = anim.pixel ? FilterQuality.none : FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FighterPainter old) => old.t != t || old.anim != anim;
}

// ---------------------------------------------------------------------------

/// Over the fight: the line to the other player. Mic, a chat drawer and a
/// way out. Sits on the right edge under the health bars, clear of the
/// sticks.
class DarkChatBar extends StatefulWidget {
  const DarkChatBar({super.key, required this.game});
  final ShadowGame game;
  @override
  State<DarkChatBar> createState() => _DarkChatBarState();
}

class _DarkChatBarState extends State<DarkChatBar> {
  bool _open = false;
  final _text = TextEditingController();
  final _scroll = ScrollController();
  int _seen = 0;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send(RtcSession s) {
    s.sendChat(_text.text);
    _text.clear();
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = RtcSession.current;
    if (s == null) return const SizedBox.shrink();
    return Positioned(
      right: 10,
      top: 64,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            ValueListenableBuilder<RtcState>(
              valueListenable: s.state,
              builder: (context, st, _) => st == RtcState.failed || st == RtcState.closed
                  ? _pill(Icons.link_off, 'LINE DROPPED', const Color(0xFFFF6B6B), () => widget.game.leaveNetDuel())
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<bool>(
              valueListenable: s.peerMuted,
              builder: (context, pm, _) => pm ? _pill(Icons.volume_off, 'THEY MUTED', Colors.white38, null) : const SizedBox.shrink(),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<bool>(
              valueListenable: s.voiceOn,
              builder: (context, on, _) => ValueListenableBuilder<bool>(
                valueListenable: s.muted,
                builder: (context, m, _) => _pill(
                  !on ? Icons.mic_off : (m ? Icons.mic_off : Icons.mic),
                  !on ? 'NO MIC' : (m ? 'MUTED' : 'LIVE'),
                  !on ? Colors.white38 : (m ? const Color(0xFFFF8B7B) : const Color(0xFF7DFFB3)),
                  on ? s.toggleMute : null,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<List<ChatMessage>>(
              valueListenable: s.chat,
              builder: (context, msgs, _) {
                final unread = _open ? 0 : msgs.length - _seen;
                if (_open) _seen = msgs.length;
                return _pill(
                  Icons.chat_bubble,
                  unread > 0 ? 'CHAT  $unread' : 'CHAT',
                  unread > 0 ? kDark : Colors.white70,
                  () => setState(() {
                    _open = !_open;
                    _seen = msgs.length;
                  }),
                );
              },
            ),
          ]),
          if (_open) ...[
            const SizedBox(height: 6),
            Container(
              width: 300,
              height: 190,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xDD0B0913),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x88C77DFF)),
              ),
              child: Column(children: [
                Expanded(
                  child: ValueListenableBuilder<List<ChatMessage>>(
                    valueListenable: s.chat,
                    builder: (context, msgs, _) => ListView.builder(
                      controller: _scroll,
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        return Align(
                          alignment: m.system ? Alignment.center : (m.mine ? Alignment.centerRight : Alignment.centerLeft),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: m.system ? Colors.transparent : (m.mine ? const Color(0x55C77DFF) : const Color(0x33FFFFFF)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(m.text,
                                style: TextStyle(
                                    color: m.system ? Colors.white38 : Colors.white,
                                    fontSize: m.system ? 10 : 12,
                                    fontStyle: m.system ? FontStyle.italic : FontStyle.normal)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 140,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: _field('say something').copyWith(counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onSubmitted: (_) => _send(s),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: kDark, size: 18), onPressed: () => _send(s)),
                ]),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color, VoidCallback? onTap) => Springy(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xAA0B0913),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: .6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontFamily: 'KenneyNarrow', color: color, fontSize: 11, letterSpacing: 2)),
          ]),
        ),
      );
}

// ---------------------------------------------------------------------------

/// After a live duel: who took it, and a rematch if the host wants one.
class DarkResultScreen extends StatelessWidget {
  const DarkResultScreen({super.key, required this.game});
  final ShadowGame game;

  @override
  Widget build(BuildContext context) {
    final s = RtcSession.current;
    final won = game.darkWon;
    final host = s?.isHost ?? false;
    return Stack(fit: StackFit.expand, children: [
      Container(color: const Color(0xAA000000)),
      _Card(
        title: won ? 'YOU TOOK IT' : 'THEY TOOK IT',
        subtitle: s?.peer == null ? 'DARK DUEL' : 'DARK DUEL  ·  vs ${s!.peer!.name}',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(won ? Icons.emoji_events : Icons.healing, size: 54, color: won ? kGold : const Color(0xFFFF8B7B)),
          const SizedBox(height: 10),
          if (s != null)
            ValueListenableBuilder<RtcState>(
              valueListenable: s.state,
              builder: (context, st, _) {
                final live = st == RtcState.connected;
                return Column(children: [
                  Text(
                    !live
                        ? 'the line dropped'
                        : host
                            ? 'call the rematch, or leave'
                            : 'waiting on the host for a rematch',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (host)
                      KButton(label: 'REMATCH', onTap: live ? game.rematchNetDuel : null, color: 'yellow', width: 160, height: 46),
                    if (host) const SizedBox(width: 10),
                    KButton(label: 'LEAVE', onTap: game.leaveNetDuel, color: 'grey', width: 130, height: 46),
                  ]),
                ]);
              },
            )
          else
            KButton(label: 'LEAVE', onTap: game.leaveNetDuel, color: 'grey', width: 130, height: 46),
          const SizedBox(height: 8),
          if (s != null) _MiniChat(session: s),
        ]),
      ),
    ]);
  }
}

/// A one-line chat for the result card: the last thing said and a field.
class _MiniChat extends StatefulWidget {
  const _MiniChat({required this.session});
  final RtcSession session;
  @override
  State<_MiniChat> createState() => _MiniChatState();
}

class _MiniChatState extends State<_MiniChat> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return Column(children: [
      ValueListenableBuilder<List<ChatMessage>>(
        valueListenable: s.chat,
        builder: (context, msgs, _) {
          final last = msgs.lastWhere((m) => !m.system, orElse: () => ChatMessage('', mine: false, system: true));
          return Text(
            last.text.isEmpty ? '' : '${last.mine ? 'you' : s.peer?.name ?? 'them'}: ${last.text}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          );
        },
      ),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _text,
            maxLength: 140,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            decoration: _field('say something').copyWith(counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            onSubmitted: (_) {
              s.sendChat(_text.text);
              _text.clear();
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: s.muted,
          builder: (context, m, _) => IconButton(
            icon: Icon(m ? Icons.mic_off : Icons.mic, color: m ? const Color(0xFFFF8B7B) : const Color(0xFF7DFFB3), size: 18),
            onPressed: s.voiceOn.value ? s.toggleMute : null,
          ),
        ),
      ]),
    ]);
  }
}
