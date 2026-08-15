// Big 2 (大老二) Game Loop & Table State Machine — #13
import 'dart:math' as math;
import 'big2_deck.dart';
import 'big2_rules.dart';

class Big2Trick {
  final List<Big2Card> cards;
  final int owner;

  const Big2Trick({required this.cards, required this.owner});

  @override
  String toString() => 'Trick by Player $owner: ${cards.map((c) => c.id).join(", ")}';
}

class Big2GameState {
  final List<List<Big2Card>> hands;
  final int turn;
  final Big2Trick? trick;
  final int? winner;
  final List<int> comboBonuses;

  const Big2GameState({
    required this.hands,
    required this.turn,
    required this.trick,
    required this.winner,
    required this.comboBonuses,
  });

  /// Initializes a fresh game: 4 hands dealt, 3♦ holder leads, empty trick.
  factory Big2GameState.newGame([math.Random? random]) {
    final hands = Big2Deck.deal(random);
    final startingTurn = Big2Deck.findStartingPlayer(hands);
    return Big2GameState(
      hands: hands,
      turn: startingTurn >= 0 ? startingTurn : 0,
      trick: null,
      winner: null,
      comboBonuses: List.filled(Big2Deck.playerCount, 0),
    );
  }

  /// Advances to next player. If next player is the trick owner, everyone passed
  /// and the trick clears for the owner to lead fresh.
  Big2GameState _advanceTurn() {
    final nextTurn = (turn + 1) % Big2Deck.playerCount;
    if (trick != null && nextTurn == trick!.owner) {
      return Big2GameState(
        hands: hands,
        turn: nextTurn,
        trick: null,
        winner: winner,
        comboBonuses: comboBonuses,
      );
    }
    return Big2GameState(
      hands: hands,
      turn: nextTurn,
      trick: trick,
      winner: winner,
      comboBonuses: comboBonuses,
    );
  }

  /// Plays cards for current turn player. Returns new state or same state if play is illegal.
  Big2GameState playCards(List<String> cardIds) {
    if (winner != null) return this;
    final currentHand = hands[turn];
    final idsSet = cardIds.toSet();

    final playedCards = currentHand.where((c) => idsSet.contains(c.id)).toList();
    if (playedCards.length != idsSet.length) return this;
    if (!Big2Rules.canBeat(playedCards, trick?.cards)) return this;

    final classified = Big2Rules.classifyHand(playedCards);
    final int bonus = classified != null ? classified.type.bonus : 0;

    final nextBonuses = List<int>.from(comboBonuses);
    if (bonus > 0) {
      nextBonuses[turn] += bonus;
    }

    final nextHand = currentHand.where((c) => !idsSet.contains(c.id)).toList();
    final nextHands = List<List<Big2Card>>.from(hands);
    nextHands[turn] = nextHand;

    final isWinner = nextHand.isEmpty;
    final playedState = Big2GameState(
      hands: nextHands,
      turn: turn,
      trick: Big2Trick(cards: playedCards, owner: turn),
      winner: isWinner ? turn : null,
      comboBonuses: nextBonuses,
    );

    return isWinner ? playedState : playedState._advanceTurn();
  }

  /// Current turn player passes. Returns same state if opening trick.
  Big2GameState passTurn() {
    if (winner != null) return this;
    if (!Big2Rules.canPass(trick?.cards)) return this;
    return _advanceTurn();
  }
}
