import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/big2_deck.dart';
import 'package:flutter_application/big2_scoring.dart';

List<Big2Card> hand(List<String> ids) => ids.map((id) => Big2Card.fromId(id)).toList();

void main() {
  group('Big2Scoring penaltyPoints', () {
    test('1-9 cards cost 1pt per card', () {
      expect(Big2Scoring.penaltyPoints(hand(['3D', '4D', '5D'])).points, 3);
      expect(Big2Scoring.penaltyPoints(hand(['3D', '4C', '5H', '6S', '8D', '9C', 'JH', 'QS', 'KD'])).points, 9);
    });

    test('10-12 cards cost 2pts per card', () {
      expect(Big2Scoring.penaltyPoints(hand(['3D', '4C', '5H', '6S', '8D', '9C', '10H', 'JS', 'QD', 'KC'])).points, 20);
    });

    test('13 cards (never played) cost 3pts per card (39 pts)', () {
      final thirteen = [
        '3D', '4C', '5H', '6S', '8D', '9C', '10H', 'JS', 'QD', 'KC', 'AH', '3S', '4H'
      ];
      expect(Big2Scoring.penaltyPoints(hand(thirteen)).points, 39);
    });

    test('doubles for unused 2s under house rules', () {
      expect(Big2Scoring.penaltyPoints(hand(['2S', '3D']), true).points, 4); // 2 cards * 1 * 2 = 4
      expect(Big2Scoring.penaltyPoints(hand(['2S', '3D']), false).points, 2); // house rules disabled
    });

    test('doubles for unused four-of-a-kind or straight flush', () {
      final quads = hand(['9D', '9C', '9H', '9S', '3D']);
      expect(Big2Scoring.penaltyPoints(quads, true).points, 10); // 5 * 1 * 2 = 10
    });
  });

  group('Big2Scoring scoreRound zero-sum deltas', () {
    test('winner nets positive sum of all loser penalties', () {
      final hands = [
        <Big2Card>[], // Player 0 (winner)
        hand(['3D', '4D']), // Player 1: 2 cards = 2 pts
        hand(['5D', '6D', '7D']), // Player 2: 3 cards = 3 pts
        hand(['8D', '9D', '10D', 'JD']), // Player 3: 4 cards = 4 pts
      ];

      final res = Big2Scoring.scoreRound(hands: hands, winner: 0, houseRules: false);
      expect(res.deltas[0], 9);
      expect(res.deltas[1], -2);
      expect(res.deltas[2], -3);
      expect(res.deltas[3], -4);
      expect(res.deltas.reduce((a, b) => a + b), 0); // Zero-sum
    });
  });
}
