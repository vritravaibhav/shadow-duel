import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/cards.dart';
import 'package:shadow_duel/game/weapons.dart';

void main() {
  test('card deck: a drawn blade runs out, rests, and comes back', () {
    final deck = CardDeck(Swords.unlockedAt(2)); // wakizashi, katana, nodachi
    expect(deck.cards.length, 3);
    expect(deck.weapon.id, 'wakizashi');

    // Switching keeps the old card's remaining time.
    deck.update(4);
    expect(deck.equip(1), isTrue);
    expect(deck.weapon.id, 'katana');
    expect(deck.cards[0].activeLeft, closeTo(10, 1e-9));

    // The katana's 12 s window runs out: it rests and the wakizashi is drawn.
    (Sword, Sword?)? spent;
    deck.onSpent = (s, n) => spent = (s, n);
    deck.update(12.5);
    expect(spent?.$1.id, 'katana');
    expect(spent?.$2?.id, 'wakizashi');
    expect(deck.equipped, 0);
    expect(deck.cards[1].ready, isFalse);
    expect(deck.cards[1].cooldown, closeTo(36, 1e-9));
    expect(deck.equip(1), isFalse);

    // After the recharge the katana is back with a full window.
    deck.update(36);
    expect(deck.cards[1].ready, isTrue);
    expect(deck.cards[1].activeLeft, 12);

    deck.unequip();
    expect(deck.weapon.id, 'fists');
  });

  test('sword unlock schedule', () {
    expect(Swords.unlockedAt(0).map((s) => s.id), ['wakizashi', 'katana']);
    expect(Swords.unlockedAt(16).length, 10);
  });

  test('auto-draw takes the freshest blade, never a sliver, else bare hands', () {
    final deck = CardDeck(Swords.unlockedAt(2));
    // Wakizashi almost spent, nodachi fresh: the nodachi is drawn, not slot 0.
    deck.cards[0].activeLeft = 0.5;
    deck.equip(1);
    deck.cards[1].activeLeft = 0.05;
    deck.update(0.1);
    expect(deck.weapon.id, 'nodachi');

    // With only slivers left, the fighter goes bare-handed instead of
    // chain-spending cards.
    for (final c in deck.cards) {
      c.activeLeft = 0.5;
    }
    deck.equip(2);
    deck.update(0.6);
    expect(deck.equipped, isNull);
    expect(deck.weapon.id, 'fists');
  });
}
