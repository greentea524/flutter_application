// Big 2 (大老二) End-of-Round Scoring Engine — #15
import 'big2_deck.dart';
import 'big2_rules.dart';

class Big2HandPenalty {
  final int cardsLeft;
  final int base;
  final bool doubledByTwos;
  final bool doubledByStrong;
  final int points;

  const Big2HandPenalty({
    required this.cardsLeft,
    required this.base,
    required this.doubledByTwos,
    required this.doubledByStrong,
    required this.points,
  });
}

class Big2RoundResult {
  final List<Big2HandPenalty> breakdown;
  final int winnerGain;
  final List<int> comboBonuses;
  final List<int> comboDeltas;
  final List<int> deltas;

  const Big2RoundResult({
    required this.breakdown,
    required this.winnerGain,
    required this.comboBonuses,
    required this.comboDeltas,
    required this.deltas,
  });
}

class Big2Scoring {
  static bool hasFourOfAKind(List<Big2Card> hand) {
    final Map<Big2Rank, int> counts = {};
    for (final c in hand) {
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    return counts.values.any((n) => n == 4);
  }

  static bool hasStraightFlush(List<Big2Card> hand) {
    final Map<Big2Suit, Set<int>> bySuit = {};
    for (final c in hand) {
      bySuit.putIfAbsent(c.suit, () => <int>{});
      final seq = Big2Rules.seqValues[c.rank]!;
      bySuit[c.suit]!.add(seq);
      if (c.rank == Big2Rank.ace) {
        bySuit[c.suit]!.add(1); // Ace-low wheel
      }
    }

    for (final seqs in bySuit.values) {
      for (int v = 1; v + 4 <= 14; v++) {
        if ([0, 1, 2, 3, 4].every((d) => seqs.contains(v + d))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Penalty points for one losing hand
  static Big2HandPenalty penaltyPoints(List<Big2Card> hand, [bool houseRules = true]) {
    final int cardsLeft = hand.length;
    final int perCard = cardsLeft == 13 ? 3 : (cardsLeft >= 10 ? 2 : 1);
    final int base = cardsLeft * perCard;
    final bool doubledByTwos = houseRules && hand.any((c) => c.rank == Big2Rank.two);
    final bool doubledByStrong =
        houseRules && (hasFourOfAKind(hand) || hasStraightFlush(hand));

    int points = base;
    if (doubledByTwos) points *= 2;
    if (doubledByStrong) points *= 2;

    return Big2HandPenalty(
      cardsLeft: cardsLeft,
      base: base,
      doubledByTwos: doubledByTwos,
      doubledByStrong: doubledByStrong,
      points: points,
    );
  }

  /// Scores a finished round across all 4 hands with zero-sum penalty and combo distributions
  static Big2RoundResult scoreRound({
    required List<List<Big2Card>> hands,
    required int winner,
    bool houseRules = true,
    List<int> comboBonuses = const [0, 0, 0, 0],
    bool comboBonusesEnabled = true,
  }) {
    final List<Big2HandPenalty> breakdown = [];
    for (int i = 0; i < hands.length; i++) {
      if (i == winner) {
        breakdown.add(const Big2HandPenalty(
          cardsLeft: 0,
          base: 0,
          doubledByTwos: false,
          doubledByStrong: false,
          points: 0,
        ));
      } else {
        breakdown.add(penaltyPoints(hands[i], houseRules));
      }
    }

    final rawBonuses = List<int>.from(comboBonuses);
    final int totalBonuses = rawBonuses.reduce((a, b) => a + b);

    final List<int> comboDeltas = (comboBonusesEnabled && totalBonuses > 0)
        ? rawBonuses.map((b) {
            final othersBonusSum = totalBonuses - b;
            return (b - othersBonusSum / 3.0).round();
          }).toList()
        : List.filled(Big2Deck.playerCount, 0);

    final int winnerGain = breakdown.map((b) => b.points).reduce((a, b) => a + b);
    final List<int> penaltyDeltas = List.generate(
      Big2Deck.playerCount,
      (i) => i == winner ? winnerGain : -breakdown[i].points,
    );

    final List<int> deltas = List.generate(
      Big2Deck.playerCount,
      (i) => penaltyDeltas[i] + comboDeltas[i],
    );

    return Big2RoundResult(
      breakdown: breakdown,
      winnerGain: winnerGain,
      comboBonuses: comboBonusesEnabled ? rawBonuses : List.filled(Big2Deck.playerCount, 0),
      comboDeltas: comboDeltas,
      deltas: deltas,
    );
  }
}
