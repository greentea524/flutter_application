// Big 2 (大老二) Combination Classification and Comparison — #12
import 'dart:math' as math;
import 'big2_deck.dart';

enum Big2HandType {
  single('Single', 0, 0),
  pair('Pair', 0, 0),
  triple('Triple', 0, 0),
  straight('Straight', 1, 3),
  flush('Flush', 2, 3),
  fullHouse('Full House', 3, 6),
  fourOfAKind('Four of a Kind', 4, 9),
  straightFlush('Straight Flush', 5, 12);

  final String label;
  final int fiveCardRank;
  final int bonus;

  const Big2HandType(this.label, this.fiveCardRank, this.bonus);
}

class Big2Combination {
  final Big2HandType type;
  final int size;
  final int value;
  final List<Big2Card> cards;

  const Big2Combination({
    required this.type,
    required this.size,
    required this.value,
    required this.cards,
  });

  @override
  String toString() => '${type.label} ($size cards, value: $value)';
}

class Big2Rules {
  /// Sequence values for Straight calculations (A=14 normally, or 1 in A-low wheel)
  static const Map<Big2Rank, int> seqValues = {
    Big2Rank.two: 2,
    Big2Rank.three: 3,
    Big2Rank.four: 4,
    Big2Rank.five: 5,
    Big2Rank.six: 6,
    Big2Rank.seven: 7,
    Big2Rank.eight: 8,
    Big2Rank.nine: 9,
    Big2Rank.ten: 10,
    Big2Rank.jack: 11,
    Big2Rank.queen: 12,
    Big2Rank.king: 13,
    Big2Rank.ace: 14,
  };

  /// Straight valuation (sequence high-card value * 4 + suit index), or null if not a sequence.
  static int? _straightValue(List<Big2Card> cards) {
    if (cards.length != 5) return null;

    int? tryRun(bool aceLow) {
      final seq = cards.map((c) {
        final int v = (c.rank == Big2Rank.ace && aceLow) ? 1 : seqValues[c.rank]!;
        return (card: c, v: v);
      }).toList();

      seq.sort((a, b) => a.v.compareTo(b.v));

      for (int i = 1; i < seq.length; i++) {
        if (seq[i].v != seq[i - 1].v + 1) return null;
      }

      final high = seq.last;
      return high.v * Big2Suit.values.length + high.card.suit.index;
    }

    return tryRun(false) ?? tryRun(true);
  }

  /// Classifies a proposed play into a Big2Combination or returns null if invalid.
  static Big2Combination? classifyHand(List<Big2Card>? cards) {
    if (cards == null || cards.isEmpty) return null;

    // Check for duplicate card IDs
    final ids = cards.map((c) => c.id).toSet();
    if (ids.length != cards.length) return null;

    // 1. Single
    if (cards.length == 1) {
      return Big2Combination(
        type: Big2HandType.single,
        size: 1,
        value: cards[0].value,
        cards: cards,
      );
    }

    // 2. Pair or Triple
    if (cards.length == 2 || cards.length == 3) {
      final firstRank = cards[0].rank;
      if (!cards.every((c) => c.rank == firstRank)) return null;

      final type = cards.length == 2 ? Big2HandType.pair : Big2HandType.triple;
      final int bestSuit = cards.map((c) => c.suit.index).reduce(math.max);
      final int value = firstRank.rankIndex * Big2Suit.values.length + bestSuit;

      return Big2Combination(
        type: type,
        size: cards.length,
        value: value,
        cards: cards,
      );
    }

    // 5-Card combinations
    if (cards.length != 5) return null;

    final bool isFlush = cards.every((c) => c.suit == cards[0].suit);
    final int? straight = _straightValue(cards);

    // 8. Straight Flush
    if (isFlush && straight != null) {
      return Big2Combination(
        type: Big2HandType.straightFlush,
        size: 5,
        value: straight,
        cards: cards,
      );
    }

    // Count rank frequencies
    final Map<Big2Rank, int> counts = {};
    for (final c in cards) {
      counts[c.rank] = (counts[c.rank] ?? 0) + 1;
    }
    final byCount = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 7. Four of a Kind (Quads + 1 kicker)
    if (byCount[0].value == 4) {
      return Big2Combination(
        type: Big2HandType.fourOfAKind,
        size: 5,
        value: byCount[0].key.rankIndex,
        cards: cards,
      );
    }

    // 6. Full House (Triple + Pair)
    if (byCount[0].value == 3 && byCount[1].value == 2) {
      return Big2Combination(
        type: Big2HandType.fullHouse,
        size: 5,
        value: byCount[0].key.rankIndex,
        cards: cards,
      );
    }

    // 5. Flush
    if (isFlush) {
      final int bestRank = cards.map((c) => c.rank.rankIndex).reduce(math.max);
      final int value = cards[0].suit.index * Big2Rank.values.length + bestRank;
      return Big2Combination(
        type: Big2HandType.flush,
        size: 5,
        value: value,
        cards: cards,
      );
    }

    // 4. Straight
    if (straight != null) {
      return Big2Combination(
        type: Big2HandType.straight,
        size: 5,
        value: straight,
        cards: cards,
      );
    }

    return null;
  }

  /// True if `played` cards legally beat `current` trick.
  /// Any valid hand beats an empty/null trick.
  static bool canBeat(List<Big2Card> played, List<Big2Card>? current) {
    final p = classifyHand(played);
    if (p == null) return false;
    if (current == null || current.isEmpty) return true;

    final c = classifyHand(current);
    if (c == null || p.size != c.size) return false;

    // Cross-type comparison for 5-card hands
    if (p.size == 5 && p.type != c.type) {
      return p.type.fiveCardRank > c.type.fiveCardRank;
    }

    if (p.type != c.type) return false;
    return p.value > c.value;
  }

  /// True if player is allowed to pass (must have an active trick to pass).
  static bool canPass(List<Big2Card>? currentTrick) {
    return currentTrick != null && currentTrick.isNotEmpty;
  }

  /// True if the played combination is absolutely unbeatable by any valid hand in the game.
  static bool isUnbeatable(List<Big2Card>? cards) {
    if (cards == null || cards.isEmpty) return false;
    final c = classifyHand(cards);
    if (c == null) return false;

    if (c.type == Big2HandType.single) {
      return cards[0].rank == Big2Rank.two && cards[0].suit == Big2Suit.spade;
    }
    if (c.type == Big2HandType.pair) {
      return cards[0].rank == Big2Rank.two &&
          cards.any((card) => card.suit == Big2Suit.spade);
    }
    if (c.type == Big2HandType.triple) {
      return cards[0].rank == Big2Rank.two;
    }
    return false;
  }
}
