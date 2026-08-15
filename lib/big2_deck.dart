// Big 2 (大老二) Deck Engine — #11
import 'dart:math' as math;

enum Big2Suit {
  diamond('D', '♦', 'Diamonds', true),
  club('C', '♣', 'Clubs', false),
  heart('H', '♥', 'Hearts', true),
  spade('S', '♠', 'Spades', false);

  final String code;
  final String symbol;
  final String name;
  final bool isRed;

  const Big2Suit(this.code, this.symbol, this.name, this.isRed);

  static Big2Suit fromCode(String code) {
    return Big2Suit.values.firstWhere((s) => s.code == code);
  }
}

enum Big2Rank {
  three('3', 0),
  four('4', 1),
  five('5', 2),
  six('6', 3),
  seven('7', 4),
  eight('8', 5),
  nine('9', 6),
  ten('10', 7),
  jack('J', 8),
  queen('Q', 9),
  king('K', 10),
  ace('A', 11),
  two('2', 12);

  final String label;
  final int rankIndex;

  const Big2Rank(this.label, this.rankIndex);

  static Big2Rank fromLabel(String label) {
    return Big2Rank.values.firstWhere((r) => r.label == label);
  }
}

class Big2Card implements Comparable<Big2Card> {
  final Big2Rank rank;
  final Big2Suit suit;

  const Big2Card(this.rank, this.suit);

  factory Big2Card.fromId(String id) {
    final rankPart = id.substring(0, id.length - 1);
    final suitPart = id.substring(id.length - 1);
    return Big2Card(Big2Rank.fromLabel(rankPart), Big2Suit.fromCode(suitPart));
  }

  String get id => '${rank.label}${suit.code}';

  int get value => rank.rankIndex * 4 + suit.index;

  bool get isThreeOfDiamonds => rank == Big2Rank.three && suit == Big2Suit.diamond;

  @override
  int compareTo(Big2Card other) {
    return value.compareTo(other.value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Big2Card && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$id (${rank.label}${suit.symbol})';
}

class Big2Deck {
  static const int playerCount = 4;
  static const int handSize = 13;

  /// Creates a standard 52-card deck sorted ascending: 3♦ to 2♠
  static List<Big2Card> createDeck() {
    final List<Big2Card> deck = [];
    for (final rank in Big2Rank.values) {
      for (final suit in Big2Suit.values) {
        deck.add(Big2Card(rank, suit));
      }
    }
    return deck;
  }

  /// Total value of a card in Big 2 rules
  static int cardValue(Big2Card card) => card.value;

  /// Card comparator in ascending Big 2 order (Rank dominant, then Suit ♦ < ♣ < ♥ < ♠)
  static int compareCards(Big2Card a, Big2Card b) => a.value.compareTo(b.value);

  /// Sorts hand ascending by Big 2 rank/suit order (3♦ lowest, 2♠ highest)
  static List<Big2Card> sortHand(List<Big2Card> hand) {
    final copy = List<Big2Card>.from(hand);
    copy.sort(compareCards);
    return copy;
  }

  /// Sorts hand grouped by suit first (♦, ♣, ♥, ♠), with ascending ranks within each suit
  static List<Big2Card> sortHandBySuit(List<Big2Card> hand) {
    final copy = List<Big2Card>.from(hand);
    copy.sort((a, b) {
      final suitDiff = a.suit.index.compareTo(b.suit.index);
      if (suitDiff != 0) return suitDiff;
      return a.rank.rankIndex.compareTo(b.rank.rankIndex);
    });
    return copy;
  }

  /// Shuffles a deck using Fisher-Yates algorithm. Accepts an optional RNG.
  static List<Big2Card> shuffle(List<Big2Card> deck, [math.Random? random]) {
    final rng = random ?? math.Random();
    final out = List<Big2Card>.from(deck);
    for (int i = out.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = out[i];
      out[i] = out[j];
      out[j] = temp;
    }
    return out;
  }

  /// Shuffles and deals full 52-card deck round-robin into 4 hands of 13, pre-sorted ascending
  static List<List<Big2Card>> deal([math.Random? random]) {
    final shuffled = shuffle(createDeck(), random);
    final List<List<Big2Card>> hands = List.generate(playerCount, (_) => []);
    for (int i = 0; i < shuffled.length; i++) {
      hands[i % playerCount].add(shuffled[i]);
    }
    return hands.map((h) => sortHand(h)).toList();
  }

  /// Finds the player index (0..3) holding 3♦ to lead the first trick. Returns -1 if not found.
  static int findStartingPlayer(List<List<Big2Card>> hands) {
    for (int i = 0; i < hands.length; i++) {
      if (hands[i].any((c) => c.isThreeOfDiamonds)) {
        return i;
      }
    }
    return -1;
  }
}
