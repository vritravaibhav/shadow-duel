import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/cards.dart';
import 'package:shadow_duel/game/weapons.dart';

void main() {
  test('card deck: switching, wear, shatter, recharge', () {
    final deck = CardDeck(Swords.unlockedAt(2)); // wakizashi, katana, nodachi
    expect(deck.cards.length, 3);
    expect(deck.weapon.id, 'wakizashi');

    // Switching puts the old card on half recharge.
    expect(deck.equip(1), isTrue);
    expect(deck.weapon.id, 'katana');
    expect(deck.cards[0].cooldown, closeTo(3, 1e-9));
    expect(deck.equip(0), isFalse);
    deck.update(3);
    expect(deck.cards[0].ready, isTrue);

    // Wearing the katana down shatters it and auto-draws the first ready card.
    (Sword, Sword?)? shattered;
    deck.onShatter = (b, n) => shattered = (b, n);
    deck.wear(60);
    expect(deck.cards[1].durabilityFrac, closeTo(0.4, 1e-9));
    deck.wear(50);
    expect(shattered?.$1.id, 'katana');
    expect(shattered?.$2?.id, 'wakizashi');
    expect(deck.equipped, 0);
    expect(deck.cards[1].cooldown, closeTo(8, 1e-9));

    // A recharged card comes back at full durability.
    deck.update(8);
    expect(deck.cards[1].ready, isTrue);
    expect(deck.cards[1].durability, 100);

    deck.unequip();
    expect(deck.weapon.id, 'fists');
  });

  test('sword unlock schedule', () {
    expect(Swords.unlockedAt(0).map((s) => s.id), ['wakizashi', 'katana']);
    expect(Swords.unlockedAt(16).length, 10);
  });
}
