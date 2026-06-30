import 'dart:math';

import 'package:flutter_application/boxing_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initial state', () {
    test('starts as level 1 brawler at full HP vs Scrap Bot', () {
      final game = BoxingGame(random: Random(1));
      expect(game.level, 1);
      expect(game.selectedClass, 'brawler');
      expect(game.playerMaxHp, 120);
      expect(game.playerHp, 120);
      expect(game.fightNumber, 1);
      expect(game.currentEnemy.name, 'Scrap Bot');
      expect(game.cpuMaxHp, 100);
    });
  });

  group('boss cadence & enemy cycling', () {
    test('every 4th fight is the Titan Boss, others cycle the roster', () {
      final game = BoxingGame(random: Random(1));
      final names = <int, String>{};
      for (int fight = 1; fight <= 8; fight++) {
        game.fightNumber = fight;
        names[fight] = game.getEnemyForFight().name;
      }
      expect(names[4], 'Titan Boss');
      expect(names[8], 'Titan Boss');
      // Normal fights cycle Scrap Bot -> Street Bruiser -> Ninja Punk.
      expect(names[1], 'Scrap Bot');
      expect(names[2], 'Street Bruiser');
      expect(names[3], 'Ninja Punk');
      expect(names[5], 'Scrap Bot');
      expect(names[6], 'Street Bruiser');
      expect(names[7], 'Ninja Punk');
    });
  });

  group('cpu HP scaling', () {
    test('scales with level and enemy multiplier', () {
      final game = BoxingGame(random: Random(1));
      game.level = 3; // base becomes 100 + 20 = 120
      game.fightNumber = 1; // Scrap Bot, x1.0
      game.startRound(advance: false);
      expect(game.cpuMaxHp, 120);

      game.fightNumber = 4; // boss x1.7 -> floor(120 * 1.7) = 204
      game.startRound(advance: false);
      expect(game.cpuMaxHp, 204);
    });
  });

  group('combat math', () {
    test('player punch deals random damage plus attack bonus', () {
      final game = BoxingGame(random: Random(7));
      final beforeCpu = game.cpuHp;
      final outcome = game.playerPunch();
      final dealt = beforeCpu - game.cpuHp;
      // Brawler attack bonus is 2; damage roll is 8..20.
      expect(dealt, inInclusiveRange(kMinDamage + 2, kMaxDamage + 2));
      expect(outcome.playerDamage, dealt);
    });

    test('defeating the CPU awards XP and gold and ends the round', () {
      final game = BoxingGame(random: Random(3));
      game.cpuHp = 1;
      final outcome = game.playerPunch();
      expect(outcome.cpuDefeated, isTrue);
      expect(outcome.winner, 'Player');
      expect(game.isGameOver, isTrue);
      expect(game.xp, kXpPerWin); // 40, not enough to level
      expect(game.gold, kGoldPerWin); // 25
      expect(game.level, 1);
    });

    test('boss victory pays double rewards', () {
      final game = BoxingGame(random: Random(3));
      game.fightNumber = 4;
      game.startRound(advance: false);
      expect(game.currentEnemy.isBoss, isTrue);
      game.cpuHp = 1;
      game.playerPunch();
      expect(game.xp, kXpPerWin * 2); // 80
      expect(game.gold, kGoldPerWin * 2); // 50
    });

    test('enough XP triggers a level up with +10 max HP', () {
      final game = BoxingGame(random: Random(3));
      game.xp = 80; // +40 from win => 120 >= 100, levels up once
      game.cpuHp = 1;
      game.playerPunch();
      expect(game.level, 2);
      expect(game.xp, 20); // 120 - 100
      expect(game.playerMaxHp, 130);
      expect(game.playerHp, 130); // full heal on level up
    });
  });

  group('shop & classes', () {
    test('buy/use potion and buy gloves respect gold and HP guards', () {
      final game = BoxingGame(random: Random(1));
      expect(game.buyPotion(), isFalse); // no gold
      game.gold = 100;
      expect(game.buyPotion(), isTrue);
      expect(game.gold, 80);
      expect(game.potions, 1);

      expect(game.usePotion(), isFalse); // HP already full
      game.playerHp = 50;
      expect(game.usePotion(), isTrue);
      expect(game.playerHp, 80);
      expect(game.potions, 0);

      final atkBefore = game.playerAttackBonus;
      expect(game.buyGloves(), isTrue);
      expect(game.gold, 30);
      expect(game.playerAttackBonus, atkBefore + 2);
    });

    test('applying a class updates max HP and heals', () {
      final game = BoxingGame(random: Random(1));
      game.level = 2; // +10 to class base
      expect(game.applyClass('tank'), isTrue);
      expect(game.selectedClass, 'tank');
      expect(game.playerMaxHp, 145 + 10);
      expect(game.playerHp, 155);
      expect(game.applyClass('tank'), isFalse); // no-op when unchanged
    });
  });

  group('serialization', () {
    test('round-trips through toJson/applyJson', () {
      final game = BoxingGame(random: Random(1));
      game.level = 4;
      game.xp = 60;
      game.gold = 130;
      game.potions = 2;
      game.glovesBonus = 4;
      game.fightNumber = 6;
      game.selectedClass = 'speedster';
      game.startRound(advance: false);
      game.playerHp = 40;

      final json = game.toJson();
      final loaded = BoxingGame(random: Random(1))..applyJson(json);

      expect(loaded.level, 4);
      expect(loaded.xp, 60);
      expect(loaded.gold, 130);
      expect(loaded.potions, 2);
      expect(loaded.glovesBonus, 4);
      expect(loaded.fightNumber, 6);
      expect(loaded.selectedClass, 'speedster');
      expect(loaded.playerHp, 40);
      expect(loaded.currentEnemy.name, game.currentEnemy.name);
    });

    test('corrupt fields fall back to safe defaults', () {
      final game = BoxingGame(random: Random(1));
      game.applyJson(<String, dynamic>{
        'selectedClass': 'wizard',
        'level': -5,
        'xp': 'oops',
        'gold': null,
        'fightNumber': 0,
      });
      expect(game.selectedClass, 'brawler');
      expect(game.level, 1);
      expect(game.xp, 0);
      expect(game.gold, 0);
      expect(game.fightNumber, 1);
    });
  });
}
