import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/big2_deck.dart';
import 'package:flutter_application/big2_rules.dart';

List<Big2Card> hand(List<String> ids) => ids.map((id) => Big2Card.fromId(id)).toList();

void main() {
  group('Big2 classifyHand — all 8 types', () {
    test('classifies singles, pairs, and triples', () {
      expect(
        Big2Rules.classifyHand(hand(['7H']))?.type,
        Big2HandType.single,
      );
      expect(
        Big2Rules.classifyHand(hand(['7H', '7D']))?.type,
        Big2HandType.pair,
      );
      expect(
        Big2Rules.classifyHand(hand(['7H', '7D', '7S']))?.type,
        Big2HandType.triple,
      );
    });

    test('classifies straights (mixed suits, 5 consecutive)', () {
      expect(
        Big2Rules.classifyHand(hand(['5D', '6C', '7H', '8S', '9D']))?.type,
        Big2HandType.straight,
      );
    });

    test('classifies flushes (same suit, non-consecutive)', () {
      expect(
        Big2Rules.classifyHand(hand(['3H', '6H', '9H', 'JH', 'KH']))?.type,
        Big2HandType.flush,
      );
    });

    test('classifies full houses and four of a kind', () {
      expect(
        Big2Rules.classifyHand(hand(['9D', '9C', '9H', '4S', '4D']))?.type,
        Big2HandType.fullHouse,
      );
      expect(
        Big2Rules.classifyHand(hand(['9D', '9C', '9H', '9S', '4D']))?.type,
        Big2HandType.fourOfAKind,
      );
    });

    test('classifies straight flushes', () {
      expect(
        Big2Rules.classifyHand(hand(['5H', '6H', '7H', '8H', '9H']))?.type,
        Big2HandType.straightFlush,
      );
    });
  });

  group('Big2 classifyHand — straight edge rules', () {
    test('allows the A-low wheel (5-4-3-2-A)', () {
      expect(
        Big2Rules.classifyHand(hand(['5D', '4C', '3H', '2S', 'AD']))?.type,
        Big2HandType.straight,
      );
    });

    test('treats 10-J-Q-K-A as the highest straight', () {
      final top = hand(['10D', 'JC', 'QH', 'KS', 'AD']);
      expect(Big2Rules.classifyHand(top)?.type, Big2HandType.straight);
      final nextBest = hand(['9D', '10C', 'JH', 'QS', 'KD']);
      expect(Big2Rules.canBeat(top, nextBest), isTrue);
    });

    test('rejects straights that wrap through 2 (J-Q-K-A-2, Q-K-A-2-3)', () {
      expect(
        Big2Rules.classifyHand(hand(['JD', 'QC', 'KH', 'AS', '2D'])),
        isNull,
      );
      expect(
        Big2Rules.classifyHand(hand(['QD', 'KC', 'AH', '2S', '3D'])),
        isNull,
      );
    });

    test('ranks the wheel below a 6-high straight (A plays low)', () {
      final wheel = hand(['5D', '4C', '3H', '2S', 'AD']);
      final sixHigh = hand(['2D', '3C', '4H', '5S', '6D']);
      expect(Big2Rules.canBeat(sixHigh, wheel), isTrue);
      expect(Big2Rules.canBeat(wheel, sixHigh), isFalse);
    });
  });

  group('Big2 classifyHand — invalid combinations', () {
    test('rejects empty, mismatched pairs, and bad sizes', () {
      expect(Big2Rules.classifyHand([]), isNull);
      expect(Big2Rules.classifyHand(null), isNull);
      expect(Big2Rules.classifyHand(hand(['7H', '8H'])), isNull);
      expect(Big2Rules.classifyHand(hand(['7H', '7D', '8S'])), isNull);
      expect(Big2Rules.classifyHand(hand(['3H', '6H', '9H'])), isNull);
      expect(Big2Rules.classifyHand(hand(['7H', '7D', '7S', '7C'])), isNull);
    });

    test('rejects 5 cards that form nothing', () {
      expect(
        Big2Rules.classifyHand(hand(['3D', '5C', '8H', 'JS', 'KD'])),
        isNull,
      );
    });

    test('rejects duplicate cards', () {
      expect(
        Big2Rules.classifyHand(hand(['7H', '7H'])),
        isNull,
      );
    });
  });

  group('Big2 canBeat — like-for-like comparisons', () {
    test('singles: rank first, suit breaks ties (2♠ > 2♥ > A♠)', () {
      expect(Big2Rules.canBeat(hand(['2S']), hand(['2H'])), isTrue);
      expect(Big2Rules.canBeat(hand(['2H']), hand(['AS'])), isTrue);
      expect(Big2Rules.canBeat(hand(['AS']), hand(['2H'])), isFalse);
    });

    test('pairs: higher rank wins; same rank decided by best suit', () {
      expect(Big2Rules.canBeat(hand(['9D', '9C']), hand(['8S', '8H'])), isTrue);
      expect(Big2Rules.canBeat(hand(['9S', '9D']), hand(['9H', '9C'])), isTrue);
      expect(Big2Rules.canBeat(hand(['9H', '9C']), hand(['9S', '9D'])), isFalse);
    });

    test('straights: highest card, then its suit', () {
      final nineHighSpade = hand(['5D', '6C', '7H', '8S', '9S']);
      final nineHighHeart = hand(['5C', '6D', '7S', '8H', '9H']);
      expect(Big2Rules.canBeat(nineHighSpade, nineHighHeart), isTrue);
      expect(Big2Rules.canBeat(nineHighHeart, nineHighSpade), isFalse);
    });

    test('flushes: suit first, then highest card', () {
      final clubFlushHigh = hand(['4C', '7C', '9C', 'JC', 'AC']);
      final diamondFlushHigher = hand(['5D', '8D', '10D', 'QD', '2D']);
      expect(Big2Rules.canBeat(clubFlushHigh, diamondFlushHigher), isTrue);
      final clubFlushLow = hand(['3C', '5C', '8C', '10C', 'QC']);
      expect(Big2Rules.canBeat(clubFlushHigh, clubFlushLow), isTrue);
    });

    test('full houses and quads: by the triple/quad rank', () {
      expect(
        Big2Rules.canBeat(
          hand(['10D', '10C', '10H', '3S', '3D']),
          hand(['9D', '9C', '9H', 'AS', 'AD']),
        ),
        isTrue,
      );
      expect(
        Big2Rules.canBeat(
          hand(['5D', '5C', '5H', '5S', '3D']),
          hand(['4D', '4C', '4H', '4S', '2D']),
        ),
        isTrue,
      );
    });
  });

  group('Big2 canBeat — cross-type and cross-size rules', () {
    test('only same card counts compete', () {
      expect(Big2Rules.canBeat(hand(['2S']), hand(['3D', '3C'])), isFalse);
      expect(Big2Rules.canBeat(hand(['2S', '2H']), hand(['3D'])), isFalse);
      expect(
        Big2Rules.canBeat(
          hand(['2S', '2H', '2D']),
          hand(['5D', '6C', '7H', '8S', '9D']),
        ),
        isFalse,
      );
    });

    test('5-card type hierarchy: straight < flush < full house < quads < straight flush', () {
      final straight = hand(['5D', '6C', '7H', '8S', '9D']);
      final flush = hand(['3H', '6H', '9H', 'JH', 'KH']);
      final fullHouse = hand(['4D', '4C', '4H', '3S', '3D']);
      final quads = hand(['3D', '3C', '3H', '3S', '4D']);
      final straightFlush = hand(['3H', '4H', '5H', '6H', '7H']);

      expect(Big2Rules.canBeat(flush, straight), isTrue);
      expect(Big2Rules.canBeat(fullHouse, flush), isTrue);
      expect(Big2Rules.canBeat(quads, fullHouse), isTrue);
      expect(Big2Rules.canBeat(straightFlush, quads), isTrue);

      expect(Big2Rules.canBeat(straight, flush), isFalse);
      expect(Big2Rules.canBeat(flush, fullHouse), isFalse);
    });

    test('an invalid play never beats anything', () {
      expect(Big2Rules.canBeat(hand(['7H', '8H']), hand(['3D', '3C'])), isFalse);
      expect(Big2Rules.canBeat([], hand(['3D'])), isFalse);
    });

    test('any valid combination may open an empty trick', () {
      expect(Big2Rules.canBeat(hand(['3D']), null), isTrue);
      expect(Big2Rules.canBeat(hand(['3D']), []), isTrue);
      expect(Big2Rules.canBeat(hand(['7H', '8H']), null), isFalse);
    });
  });

  group('Big2 canPass & isUnbeatable', () {
    test('allows passing only when there is a trick to beat', () {
      expect(Big2Rules.canPass(hand(['3D'])), isTrue);
      expect(Big2Rules.canPass(hand(['5D', '6C', '7H', '8S', '9D'])), isTrue);
      expect(Big2Rules.canPass(null), isFalse);
      expect(Big2Rules.canPass([]), isFalse);
    });

    test('identifies unbeatable single (2♠), pair (contains 2♠), and triple of 2s', () {
      expect(Big2Rules.isUnbeatable(hand(['2S'])), isTrue);
      expect(Big2Rules.isUnbeatable(hand(['2H'])), isFalse);

      expect(Big2Rules.isUnbeatable(hand(['2S', '2D'])), isTrue);
      expect(Big2Rules.isUnbeatable(hand(['2H', '2C'])), isFalse);

      expect(Big2Rules.isUnbeatable(hand(['2D', '2C', '2H'])), isTrue);
      expect(Big2Rules.isUnbeatable(hand(['AD', 'AC', 'AH'])), isFalse);
    });
  });
}
