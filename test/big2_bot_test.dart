import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/big2_deck.dart';
import 'package:flutter_application/big2_rules.dart';
import 'package:flutter_application/big2_bot.dart';
import 'package:flutter_application/big2_game.dart';

List<Big2Card> hand(List<String> ids) => ids.map((id) => Big2Card.fromId(id)).toList();

void main() {
  group('Big2Bot chooseBotMove — opening', () {
    test('leads the lowest single', () {
      final move = Big2Bot.chooseBotMove(hand(['KD', '5C', '9H', '3S']), null);
      expect(move.type, Big2BotMoveType.play);
      expect(move.cardIds, ['3S']);
    });

    test('leads the pair when the lowest card has a partner', () {
      final move = Big2Bot.chooseBotMove(hand(['KD', '3C', '9H', '3D']), null);
      expect(move.type, Big2BotMoveType.play);
      final sortedIds = List<String>.from(move.cardIds)..sort();
      expect(sortedIds, ['3C', '3D']);
    });
  });

  group('Big2Bot chooseBotMove — beating a trick', () {
    test('plays the lowest single that beats', () {
      final move = Big2Bot.chooseBotMove(
        hand(['2S', '9H', 'JC', '5D']),
        hand(['8C']),
      );
      expect(move.type, Big2BotMoveType.play);
      expect(move.cardIds, ['9H']);
    });

    test('plays the lowest pair that beats', () {
      final move = Big2Bot.chooseBotMove(
        hand(['9H', '9C', 'KD', 'KS', '4D']),
        hand(['8S', '8H']),
      );
      expect(move.type, Big2BotMoveType.play);
      final sortedIds = List<String>.from(move.cardIds)..sort();
      expect(sortedIds, ['9C', '9H']);
    });

    test('finds a 5-card answer, preferring the weakest type', () {
      final move = Big2Bot.chooseBotMove(
        hand(['5D', '6H', '7H', '8H', '9H', '5H', '2H']),
        hand(['4D', '5C', '6S', '7H', '8C']),
      );
      expect(move.type, Big2BotMoveType.play);
      final played = (List<String>.from(move.cardIds)..sort()).join(',');
      final expected = (['5D', '6H', '7H', '8H', '9H']..sort()).join(',');
      expect(played, expected);
    });

    test('passes when nothing beats the trick', () {
      expect(
        Big2Bot.chooseBotMove(hand(['3C', '4D', '5H']), hand(['2S'])).isPass,
        isTrue,
      );
      expect(
        Big2Bot.chooseBotMove(hand(['4C', '4D', '9H']), hand(['KS', 'KH'])).isPass,
        isTrue,
      );
    });

    test('never returns an illegal play over 200 random simulations', () {
      final random = math.Random(7);
      for (int i = 0; i < 200; i++) {
        final state = Big2GameState.newGame(random);
        final botHand = state.hands[1];
        final trickCard = [state.hands[2][random.nextInt(13)]];
        final move = Big2Bot.chooseBotMove(botHand, trickCard);
        if (move.isPlay) {
          final cards = botHand.where((c) => move.cardIds.contains(c.id)).toList();
          expect(cards.length, move.cardIds.length);
          expect(Big2Rules.canBeat(cards, trickCard), isTrue);
        }
      }
    });
  });

  group('Big2Bot chooseBotMove — endgame aggression', () {
    test('plays its strongest valid single when down to 2 cards', () {
      final move = Big2Bot.chooseBotMove(hand(['9H', '2S']), hand(['8C']));
      expect(move.type, Big2BotMoveType.play);
      expect(move.cardIds, ['2S']);
    });
  });

  group('Full bot-vs-bot games', () {
    test('always reach a winner without stalling across 30 seeded games', () {
      for (int seed = 1; seed <= 30; seed++) {
        var state = Big2GameState.newGame(math.Random(seed));
        int steps = 0;
        while (state.winner == null) {
          final move = Big2Bot.chooseBotMove(state.hands[state.turn], state.trick?.cards);
          final next = move.isPlay ? state.playCards(move.cardIds) : state.passTurn();
          expect(next, isNot(same(state)));
          state = next;
          steps++;
          expect(steps, lessThan(500));
        }
        expect(state.winner, isNotNull);
        expect(state.hands[state.winner!].length, 0);
      }
    });
  });
}
