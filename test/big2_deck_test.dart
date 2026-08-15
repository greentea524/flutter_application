import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/big2_deck.dart';

void main() {
  group('Big2 createDeck', () {
    test('has 52 unique cards, 13 ranks x 4 suits', () {
      final deck = Big2Deck.createDeck();
      expect(deck.length, 52);
      expect(deck.map((c) => c.id).toSet().length, 52);
      for (final rank in Big2Rank.values) {
        expect(deck.where((c) => c.rank == rank).length, 4);
      }
      for (final suit in Big2Suit.values) {
        expect(deck.where((c) => c.suit == suit).length, 13);
      }
    });
  });

  group('Big 2 ordering', () {
    test('ranks 2 highest and 3 lowest', () {
      expect(
        Big2Card(Big2Rank.two, Big2Suit.diamond).value,
        greaterThan(Big2Card(Big2Rank.ace, Big2Suit.spade).value),
      );
      expect(
        Big2Card(Big2Rank.three, Big2Suit.spade).value,
        lessThan(Big2Card(Big2Rank.four, Big2Suit.diamond).value),
      );
    });

    test('breaks rank ties by suit: ♠ > ♥ > ♣ > ♦', () {
      final order = [Big2Suit.diamond, Big2Suit.club, Big2Suit.heart, Big2Suit.spade];
      for (int i = 1; i < order.length; i++) {
        expect(
          Big2Deck.compareCards(
            Big2Card(Big2Rank.nine, order[i]),
            Big2Card(Big2Rank.nine, order[i - 1]),
          ),
          greaterThan(0),
        );
      }
    });

    test('2♠ > 2♥ > A♠', () {
      final twoSpades = Big2Card(Big2Rank.two, Big2Suit.spade);
      final twoHearts = Big2Card(Big2Rank.two, Big2Suit.heart);
      final aceSpades = Big2Card(Big2Rank.ace, Big2Suit.spade);

      expect(twoSpades.value, greaterThan(twoHearts.value));
      expect(twoHearts.value, greaterThan(aceSpades.value));
    });

    test('sortHand sorts ascending with 3♦ lowest and 2♠ highest', () {
      final sorted = Big2Deck.sortHand(Big2Deck.createDeck());
      expect(sorted.first.id, '3D');
      expect(sorted.last.id, '2S');
    });

    test('sortHandBySuit groups ♦♣♥♠ with ranks ascending inside each suit', () {
      final sorted = Big2Deck.sortHandBySuit(Big2Deck.createDeck());
      expect(
        sorted.map((c) => c.suit.code).toList(),
        Big2Suit.values.expand((s) => List.filled(13, s.code)).toList(),
      );
      expect(sorted[0].id, '3D');
      expect(sorted[12].id, '2D');
      expect(sorted[13].id, '3C');
      expect(sorted[51].id, '2S');

      // Does not mutate the input
      final hand = [
        Big2Card(Big2Rank.two, Big2Suit.spade),
        Big2Card(Big2Rank.three, Big2Suit.spade),
        Big2Card(Big2Rank.four, Big2Suit.diamond),
      ];
      final copy = List<Big2Card>.from(hand);
      Big2Deck.sortHandBySuit(hand);
      expect(hand, equals(copy));
    });
  });

  group('Big 2 shuffle', () {
    test('keeps the same 52 cards and does not mutate the input', () {
      final deck = Big2Deck.createDeck();
      final before = deck.map((c) => c.id).toList();
      final shuffled = Big2Deck.shuffle(deck);

      expect(deck.map((c) => c.id).toList(), equals(before));
      expect(shuffled.length, 52);
      expect(shuffled.map((c) => c.id).toSet().length, 52);
    });

    test('is deterministic with a seeded Random', () {
      final rng1 = math.Random(12345);
      final rng2 = math.Random(12345);

      expect(
        Big2Deck.shuffle(Big2Deck.createDeck(), rng1).map((c) => c.id).toList(),
        equals(
          Big2Deck.shuffle(Big2Deck.createDeck(), rng2).map((c) => c.id).toList(),
        ),
      );
    });
  });

  group('Big 2 deal', () {
    test('deals 4 sorted hands of 13 covering the whole deck', () {
      final hands = Big2Deck.deal();
      expect(hands.length, Big2Deck.playerCount);

      final allCards = hands.expand((h) => h).toList();
      expect(allCards.length, 52);
      expect(allCards.map((c) => c.id).toSet().length, 52);

      for (final hand in hands) {
        expect(hand.length, Big2Deck.handSize);
        for (int i = 1; i < hand.length; i++) {
          expect(hand[i].value, greaterThan(hand[i - 1].value));
        }
      }
    });
  });

  group('Big 2 findStartingPlayer', () {
    test('finds the holder of 3♦ on every deal', () {
      for (int i = 0; i < 20; i++) {
        final hands = Big2Deck.deal();
        final idx = Big2Deck.findStartingPlayer(hands);
        expect(idx, greaterThanOrEqualTo(0));
        expect(idx, lessThan(4));
        expect(hands[idx].any((c) => c.id == '3D'), isTrue);
      }
    });

    test('returns -1 when 3♦ is absent', () {
      final hands = [
        [Big2Card(Big2Rank.two, Big2Suit.spade)],
        <Big2Card>[],
      ];
      expect(Big2Deck.findStartingPlayer(hands), -1);
    });
  });
}
