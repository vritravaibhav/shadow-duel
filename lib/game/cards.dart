import 'dart:math' as math;

import 'weapons.dart';

/// One sword card's battle state.
class CardState {
  CardState(this.sword) : durability = sword.durability;

  final Sword sword;
  double durability;
  double cooldown = 0;

  bool get ready => cooldown <= 0 && durability > 0;
  double get durabilityFrac => (durability / sword.durability).clamp(0.0, 1.0);
  double get cooldownFrac => sword.recharge <= 0 ? 0 : (cooldown / sword.recharge).clamp(0.0, 1.0);
}

/// The Clash-style card bar: every owned sword is a card. Swinging wears the
/// equipped blade; a shattered blade recharges for its full recharge time, a
/// voluntarily swapped-out blade for half. With no card ready you fight bare-handed.
class CardDeck {
  CardDeck(List<Sword> swords) : cards = [for (final s in swords) CardState(s)] {
    equipped = cards.isEmpty ? null : 0;
  }

  final List<CardState> cards;
  int? equipped;

  /// Set by the owner; fired when the equipped blade shatters.
  void Function(Sword broken, Sword? next)? onShatter;

  Weapon get weapon => equipped == null ? Weapon.fists : cards[equipped!].sword.weapon;
  CardState? get current => equipped == null ? null : cards[equipped!];

  static const wearPerMove = {
    MoveKind.punch: 4.0,
    MoveKind.kick: 0.0,
    MoveKind.slash: 6.0,
    MoveKind.heavy: 9.0,
  };
  static const wearBlocked = 10.0;

  void update(double dt) {
    for (final c in cards) {
      if (c.cooldown > 0) {
        c.cooldown = math.max(0, c.cooldown - dt);
        if (c.cooldown == 0) c.durability = c.sword.durability;
      }
    }
  }

  /// Tap a card: equips it if ready. Returns false when nothing changed.
  bool equip(int index) {
    if (index < 0 || index >= cards.length || index == equipped) return false;
    if (!cards[index].ready) return false;
    final prev = current;
    if (prev != null) prev.cooldown = prev.sword.recharge * 0.5;
    equipped = index;
    return true;
  }

  /// Unequip to bare hands (the card recharges as after a switch).
  void unequip() {
    final prev = current;
    if (prev != null) prev.cooldown = prev.sword.recharge * 0.5;
    equipped = null;
  }

  void wear(double amount) {
    final c = current;
    if (c == null || amount <= 0) return;
    c.durability -= amount;
    if (c.durability > 0) return;
    c.durability = 0;
    c.cooldown = c.sword.recharge;
    equipped = null;
    final next = _firstReady();
    if (next != null) equipped = next;
    onShatter?.call(c.sword, next == null ? null : cards[next].sword);
  }

  int? _firstReady() {
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].ready) return i;
    }
    return null;
  }

  void reset() {
    for (final c in cards) {
      c.durability = c.sword.durability;
      c.cooldown = 0;
    }
    equipped = cards.isEmpty ? null : 0;
  }
}
