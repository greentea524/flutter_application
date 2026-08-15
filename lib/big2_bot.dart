// Big 2 (大老二) Bot AI Logic — #13
import 'big2_deck.dart';
import 'big2_rules.dart';

enum Big2BotMoveType { play, pass }

class Big2BotMove {
  final Big2BotMoveType type;
  final List<String> cardIds;
  final List<Big2Card> cards;

  Big2BotMove.play(this.cards)
      : type = Big2BotMoveType.play,
        cardIds = cards.map((c) => c.id).toList();

  const Big2BotMove.pass()
      : type = Big2BotMoveType.pass,
        cardIds = const [],
        cards = const [];

  bool get isPlay => type == Big2BotMoveType.play;
  bool get isPass => type == Big2BotMoveType.pass;

  @override
  String toString() => isPlay ? 'Play: ${cardIds.join(",")}' : 'Pass';
}

class Big2Bot {
  /// Generates all subsets of size `k` from `cards` (n <= 13, k <= 5 -> at most 1287)
  static List<List<Big2Card>> getCombinations(List<Big2Card> cards, int k) {
    final List<List<Big2Card>> result = [];

    void helper(int start, List<Big2Card> picked) {
      if (picked.length == k) {
        result.add(List<Big2Card>.from(picked));
        return;
      }
      for (int i = start; i <= cards.length - (k - picked.length); i++) {
        picked.add(cards[i]);
        helper(i + 1, picked);
        picked.removeLast();
      }
    }

    helper(0, []);
    return result;
  }

  /// Calculates strength value to order combinations weakest to strongest
  static int strength(Big2Combination cls) {
    return cls.size == 5 ? cls.type.fiveCardRank * 10000 + cls.value : cls.value;
  }

  /// Finds all legal combinations of `size` cards in `hand` that beat `trickCards`
  static List<({List<Big2Card> cards, Big2Combination cls})> beatingCandidates(
    List<Big2Card> hand,
    List<Big2Card>? trickCards,
    int size,
  ) {
    final List<({List<Big2Card> cards, Big2Combination cls})> out = [];
    final combos = getCombinations(hand, size);

    for (final cards in combos) {
      final cls = Big2Rules.classifyHand(cards);
      if (cls != null && Big2Rules.canBeat(cards, trickCards)) {
        out.add((cards: cards, cls: cls));
      }
    }
    return out;
  }

  /// Decides the bot's move for its hand against current trick (null/empty = opening).
  static Big2BotMove chooseBotMove(List<Big2Card> hand, List<Big2Card>? trickCards) {
    if (hand.isEmpty) return const Big2BotMove.pass();

    // 1. Opening a fresh trick: lead lowest card (or its pair if available)
    if (trickCards == null || trickCards.isEmpty) {
      final sorted = Big2Deck.sortHand(hand);
      final lowest = sorted[0];
      final partners = sorted.where((c) => c.rank == lowest.rank).toList();
      final lead = partners.length >= 2 ? partners.sublist(0, 2) : [lowest];
      return Big2BotMove.play(lead);
    }

    // 2. Beating an active trick
    final candidates = beatingCandidates(hand, trickCards, trickCards.length);
    if (candidates.isEmpty) return const Big2BotMove.pass();

    candidates.sort((a, b) => strength(a.cls).compareTo(strength(b.cls)));

    // Endgame aggression: with 1-2 cards left, play strongest candidate to win
    final pick = hand.length <= 2 ? candidates.last : candidates.first;
    return Big2BotMove.play(pick.cards);
  }
}
