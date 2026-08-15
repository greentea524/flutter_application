import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/big2_deck.dart';
import 'package:flutter_application/big2_game.dart';

void main() {
  group('Big2GameState newGame', () {
    test('gives the 3♦ holder the lead with no trick on the table', () {
      final state = Big2GameState.newGame(math.Random(1));
      expect(state.trick, isNull);
      expect(state.winner, isNull);
      expect(state.comboBonuses, [0, 0, 0, 0]);
      expect(state.hands[state.turn].any((c) => c.id == '3D'), isTrue);
    });
  });

  group('Big2GameState playCards', () {
    test('moves cards out of hand onto trick and advances turn', () {
      final state = Big2GameState.newGame(math.Random(1));
      final opener = state.turn;
      final lowest = state.hands[opener][0];

      final next = state.playCards([lowest.id]);
      expect(next.hands[opener].length, 12);
      expect(next.hands[opener].any((c) => c.id == lowest.id), isFalse);
      expect(next.trick?.cards.first.id, lowest.id);
      expect(next.trick?.owner, opener);
      expect(next.turn, (opener + 1) % Big2Deck.playerCount);
    });

    test('rejects cards the player does not hold', () {
      final state = Big2GameState.newGame(math.Random(1));
      final notMine = state.hands[(state.turn + 1) % Big2Deck.playerCount][0];
      expect(state.playCards([notMine.id]), same(state));
    });

    test('declares a winner when a hand empties', () {
      var state = Big2GameState.newGame(math.Random(1));
      final opener = state.turn;

      // Play out opener hand with other players passing
      while (state.winner == null) {
        if (state.turn == opener) {
          state = state.playCards([state.hands[opener][0].id]);
        } else {
          state = state.passTurn();
        }
      }

      expect(state.winner, opener);
      expect(state.hands[opener].length, 0);
    });
  });

  group('Big2GameState passTurn', () {
    test('cannot pass when opening a trick', () {
      final state = Big2GameState.newGame(math.Random(1));
      expect(state.trick, isNull);
      expect(state.passTurn(), same(state));
    });

    test('clears the trick back to the owner after three consecutive passes', () {
      var state = Big2GameState.newGame(math.Random(1));
      final opener = state.turn;

      state = state.playCards([state.hands[opener][0].id]);
      state = state.passTurn(); // Pass 1
      state = state.passTurn(); // Pass 2
      expect(state.trick, isNotNull);

      state = state.passTurn(); // Pass 3
      expect(state.turn, opener);
      expect(state.trick, isNull); // Cleared trick for owner to lead fresh
    });
  });
}
