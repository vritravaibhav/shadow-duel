import 'dart:math' as math;

import 'arts.dart';
import 'weapons.dart';

/// One sword card's battle state.
class CardState {
  CardState(this.sword) : activeLeft = sword.active;

  final Sword sword;

  /// Seconds of use left before the blade must rest.
  double activeLeft;

  /// Seconds until the card can be drawn again (0 = ready).
  double cooldown = 0;
  double cdV = 0, cdW = 0;

  bool get ready => cooldown <= 0 && activeLeft > 0;
  double get activeFrac => (activeLeft / sword.active).clamp(0.0, 1.0);
  double get cooldownFrac => sword.recharge <= 0 ? 0 : (cooldown / sword.recharge).clamp(0.0, 1.0);
}

/// The card bar: every owned sword is a card. A drawn blade can be used for
/// a short window; when that runs out it is spent and rests for a long
/// recharge, and the next ready card is drawn — or you fight bare-handed.
/// Putting a card away keeps its remaining time.
class CardDeck {
  CardDeck(List<Sword> swords) : cards = [for (final s in swords) CardState(s)] {
    equipped = cards.isEmpty ? null : 0;
  }

  final List<CardState> cards;
  int? equipped;
  double fistsCdV = 0, fistsCdW = 0;

  /// After any art, every art locks briefly so card-switching can't chain
  /// a whole deck of arts into one burst.
  double artLock = 0;
  static const artLockSeconds = 4.0;

  /// Fired when the drawn blade's time runs out.
  void Function(Sword spent, Sword? next)? onSpent;

  Weapon get weapon => equipped == null ? Weapon.fists : cards[equipped!].sword.weapon;
  CardState? get current => equipped == null ? null : cards[equipped!];

  void update(double dt) {
    for (final c in cards) {
      if (c.cooldown > 0) {
        c.cooldown = math.max(0, c.cooldown - dt);
        if (c.cooldown == 0) c.activeLeft = c.sword.active;
      }
      c.cdV = math.max(0, c.cdV - dt);
      c.cdW = math.max(0, c.cdW - dt);
    }
    fistsCdV = math.max(0, fistsCdV - dt);
    fistsCdW = math.max(0, fistsCdW - dt);
    artLock = math.max(0, artLock - dt);

    final c = current;
    if (c != null) {
      c.activeLeft = math.max(0, c.activeLeft - dt);
      if (c.activeLeft <= 0) _spend(c);
    }
  }

  void _spend(CardState c) {
    c.cooldown = c.sword.recharge;
    equipped = null;
    final next = _firstReady();
    if (next != null) equipped = next;
    onSpent?.call(c.sword, next == null ? null : cards[next].sword);
  }

  /// Remaining cooldown of the equipped blade's art for [g].
  double artCooldown(ArtGesture g) {
    final c = current;
    final own = c == null
        ? (g == ArtGesture.v ? fistsCdV : fistsCdW)
        : (g == ArtGesture.v ? c.cdV : c.cdW);
    return math.max(own, artLock);
  }

  void startArt(ArtGesture g, double seconds) {
    artLock = artLockSeconds;
    final c = current;
    if (c == null) {
      if (g == ArtGesture.v) {
        fistsCdV = seconds;
      } else {
        fistsCdW = seconds;
      }
    } else if (g == ArtGesture.v) {
      c.cdV = seconds;
    } else {
      c.cdW = seconds;
    }
  }

  /// Tap a card: draws it if ready. Returns false when nothing changed.
  bool equip(int index) {
    if (index < 0 || index >= cards.length || index == equipped) return false;
    if (!cards[index].ready) return false;
    equipped = index;
    return true;
  }

  /// Put the blade away and fight bare-handed (its remaining time is kept).
  void unequip() {
    equipped = null;
  }

  int? _firstReady() {
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].ready) return i;
    }
    return null;
  }

  void reset() {
    for (final c in cards) {
      c.activeLeft = c.sword.active;
      c.cooldown = 0;
      c.cdV = 0;
      c.cdW = 0;
    }
    fistsCdV = 0;
    fistsCdW = 0;
    artLock = 0;
    equipped = cards.isEmpty ? null : 0;
  }
}
