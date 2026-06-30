import 'dart:math';

import 'package:flutter/material.dart';

/// Pure-Dart game model for the Boxing RPG, ported from
/// `greentea524.github.io/game/js-boxing/script.js`.
///
/// This layer holds no Flutter widget / BuildContext dependencies so the
/// combat math can be unit tested in isolation.

// ---- Constants (ported from script.js) ----
const int kBaseCpuHp = 100;
const int kMinDamage = 8;
const int kMaxDamage = 20;
const int kXpPerWin = 40;
const int kGoldPerWin = 25;
const int kPotionCost = 20;
const int kGlovesCost = 50;
const int kPotionHeal = 30;
const int kBossFightInterval = 4;

/// A selectable fighter class.
class BoxingClass {
  const BoxingClass({
    required this.key,
    required this.label,
    required this.maxHp,
    required this.attackBonus,
  });

  final String key;
  final String label;
  final int maxHp;
  final int attackBonus;
}

const Map<String, BoxingClass> kClasses = {
  'brawler': BoxingClass(
    key: 'brawler',
    label: 'Brawler',
    maxHp: 120,
    attackBonus: 2,
  ),
  'speedster': BoxingClass(
    key: 'speedster',
    label: 'Speedster',
    maxHp: 95,
    attackBonus: 4,
  ),
  'tank': BoxingClass(key: 'tank', label: 'Tank', maxHp: 145, attackBonus: 0),
};

/// A CPU opponent definition.
class BoxingEnemy {
  const BoxingEnemy({
    required this.name,
    required this.tag,
    required this.hpMultiplier,
    required this.damageBonus,
    required this.color,
    required this.gloveColor,
    required this.isBoss,
  });

  final String name;
  final String tag;
  final double hpMultiplier;
  final int damageBonus;
  final Color color;
  final Color gloveColor;
  final bool isBoss;
}

const List<BoxingEnemy> kCpuFighters = [
  BoxingEnemy(
    name: 'Scrap Bot',
    tag: 'BOT',
    hpMultiplier: 1,
    damageBonus: 0,
    color: Color(0xFFF85149),
    gloveColor: Color(0xFFEF4444),
    isBoss: false,
  ),
  BoxingEnemy(
    name: 'Street Bruiser',
    tag: 'BRU',
    hpMultiplier: 1.1,
    damageBonus: 1,
    color: Color(0xFFFF7B72),
    gloveColor: Color(0xFFB94B4B),
    isBoss: false,
  ),
  BoxingEnemy(
    name: 'Ninja Punk',
    tag: 'NIN',
    hpMultiplier: 0.95,
    damageBonus: 3,
    color: Color(0xFFA371F7),
    gloveColor: Color(0xFF7C4DCE),
    isBoss: false,
  ),
];

const BoxingEnemy kBossFighter = BoxingEnemy(
  name: 'Titan Boss',
  tag: 'BOSS',
  hpMultiplier: 1.7,
  damageBonus: 5,
  color: Color(0xFFFFA657),
  gloveColor: Color(0xFFF5A623),
  isBoss: true,
);

/// Result of a single exchange (player punch + possible CPU counter), used by
/// the UI layer to sequence punch / recoil animations.
class PunchOutcome {
  const PunchOutcome({
    required this.playerDamage,
    required this.cpuDefeated,
    required this.cpuDamage,
    required this.playerDefeated,
    required this.winner,
  });

  final int playerDamage;
  final bool cpuDefeated;
  final int cpuDamage;
  final bool playerDefeated;

  /// 'Player', the enemy name, or null if the fight continues.
  final String? winner;
}

/// Holds all mutable game state and the combat rules.
class BoxingGame {
  BoxingGame({Random? random}) : _random = random ?? Random() {
    resetProgress();
  }

  final Random _random;

  String selectedClass = 'brawler';
  int level = 1;
  int xp = 0;
  int gold = 0;
  int potions = 0;
  int glovesBonus = 0;
  int fightNumber = 1;
  bool autoFightEnabled = false;
  int playerMaxHp = 120;
  int cpuMaxHp = kBaseCpuHp;
  int playerHp = 120;
  int cpuHp = kBaseCpuHp;
  bool isGameOver = false;
  int bestFight = 1;
  String statusText = 'Land the first punch!';

  late BoxingEnemy currentEnemy = kCpuFighters[0];

  /// Combat log, newest-first (mirrors the JS `prepend`).
  final List<String> log = [];

  static const int _maxLogLength = 60;

  // ---- Derived values ----
  BoxingClass get currentClass => kClasses[selectedClass]!;

  int get xpToNextLevel => level * 100;

  int get playerAttackBonus => currentClass.attackBonus + glovesBonus;

  bool get isBossFight => fightNumber % kBossFightInterval == 0;

  int getRandomDamage() =>
      kMinDamage + _random.nextInt(kMaxDamage - kMinDamage + 1);

  /// Picks the enemy for the current `fightNumber`: a boss on every
  /// `kBossFightInterval`-th fight, otherwise cycling the normal roster.
  BoxingEnemy getEnemyForFight() {
    if (isBossFight) {
      return kBossFighter;
    }
    final int normalFightIndex =
        fightNumber - 1 - ((fightNumber - 1) ~/ kBossFightInterval);
    return kCpuFighters[normalFightIndex % kCpuFighters.length];
  }

  void addLog(String message) {
    log.insert(0, message);
    if (log.length > _maxLogLength) {
      log.removeRange(_maxLogLength, log.length);
    }
  }

  // ---- Lifecycle ----
  void resetProgress() {
    selectedClass = 'brawler';
    level = 1;
    xp = 0;
    gold = 0;
    potions = 0;
    glovesBonus = 0;
    fightNumber = 1;
    autoFightEnabled = false;
    playerMaxHp = currentClass.maxHp;
    playerHp = playerMaxHp;
    currentEnemy = getEnemyForFight();
    cpuMaxHp = (kBaseCpuHp * currentEnemy.hpMultiplier).floor();
    cpuHp = cpuMaxHp;
    isGameOver = false;
    bestFight = 1;
    statusText = 'Land the first punch!';
    log.clear();
  }

  /// Sets up a fresh round. Pass [advance] true for the "Next" button.
  void startRound({required bool advance}) {
    if (advance) {
      if (!isGameOver) {
        return;
      }
      fightNumber += 1;
    }

    currentEnemy = getEnemyForFight();
    cpuMaxHp = ((kBaseCpuHp + (level - 1) * 10) * currentEnemy.hpMultiplier)
        .floor();
    playerHp = playerMaxHp;
    cpuHp = cpuMaxHp;
    isGameOver = false;
    log.clear();

    statusText = currentEnemy.isBoss
        ? 'Boss fight! ${currentEnemy.name} enters the ring.'
        : '${currentEnemy.name} steps into the ring.';
    if (fightNumber > bestFight) {
      bestFight = fightNumber;
    }
  }

  // ---- Combat ----
  PunchOutcome playerPunch() {
    final int playerDamage = getRandomDamage() + playerAttackBonus;
    cpuHp = max(0, cpuHp - playerDamage);
    addLog('Player punches ${currentEnemy.name} for $playerDamage damage.');

    if (cpuHp == 0) {
      _endGame('Player');
      return PunchOutcome(
        playerDamage: playerDamage,
        cpuDefeated: true,
        cpuDamage: 0,
        playerDefeated: false,
        winner: 'Player',
      );
    }

    final int cpuDamage =
        getRandomDamage() + (level ~/ 2) + currentEnemy.damageBonus;
    playerHp = max(0, playerHp - cpuDamage);
    addLog('${currentEnemy.name} hits back for $cpuDamage damage.');

    if (playerHp == 0) {
      _endGame(currentEnemy.name);
      return PunchOutcome(
        playerDamage: playerDamage,
        cpuDefeated: false,
        cpuDamage: cpuDamage,
        playerDefeated: true,
        winner: currentEnemy.name,
      );
    }

    statusText = currentEnemy.isBoss
        ? 'Boss fight in progress!'
        : 'Fight in progress!';
    return PunchOutcome(
      playerDamage: playerDamage,
      cpuDefeated: false,
      cpuDamage: cpuDamage,
      playerDefeated: false,
      winner: null,
    );
  }

  void _endGame(String winner) {
    isGameOver = true;
    if (winner == 'Player') {
      _awardVictoryRewards();
    }
    statusText = '$winner wins! Press Next for next round.';
  }

  void _awardVictoryRewards() {
    final int rewardMultiplier = currentEnemy.isBoss ? 2 : 1;
    final int xpGain = kXpPerWin * rewardMultiplier;
    final int goldGain = kGoldPerWin * rewardMultiplier;
    xp += xpGain;
    gold += goldGain;
    addLog('Rewards: +$xpGain XP, +$goldGain gold.');
    while (xp >= xpToNextLevel) {
      xp -= xpToNextLevel;
      level += 1;
      playerMaxHp += 10;
      playerHp = playerMaxHp;
      addLog('Level up! You are now level $level. Max HP +10.');
    }
  }

  // ---- Shop & classes ----
  bool usePotion() {
    if (potions <= 0) {
      statusText = 'No potions left.';
      return false;
    }
    if (playerHp == playerMaxHp) {
      statusText = 'HP is already full.';
      return false;
    }
    potions -= 1;
    playerHp = min(playerMaxHp, playerHp + kPotionHeal);
    addLog('Used potion and healed $kPotionHeal HP.');
    statusText = 'Potion used.';
    return true;
  }

  bool buyPotion() {
    if (gold < kPotionCost) {
      statusText = 'Not enough gold for potion.';
      return false;
    }
    gold -= kPotionCost;
    potions += 1;
    addLog('Bought 1 potion.');
    statusText = 'Potion purchased.';
    return true;
  }

  bool buyGloves() {
    if (gold < kGlovesCost) {
      statusText = 'Not enough gold for gloves.';
      return false;
    }
    gold -= kGlovesCost;
    glovesBonus += 2;
    addLog('Bought gloves upgrade. Attack +2.');
    statusText = 'Gloves upgraded.';
    return true;
  }

  bool applyClass(String nextClass) {
    if (nextClass == selectedClass || !kClasses.containsKey(nextClass)) {
      return false;
    }
    selectedClass = nextClass;
    playerMaxHp = currentClass.maxHp + (level - 1) * 10;
    playerHp = playerMaxHp;
    addLog('Class changed to ${currentClass.label}. HP fully restored.');
    statusText = '${currentClass.label} selected.';
    return true;
  }

  // ---- Player glove tint tiers (ported from setPlayerGloveBonus) ----
  Color get playerGloveColor {
    if (glovesBonus >= 6) {
      return const Color(0xFFFFD86B);
    }
    if (glovesBonus >= 4) {
      return const Color(0xFFFF7B8A);
    }
    if (glovesBonus >= 2) {
      return const Color(0xFFFF5F73);
    }
    return const Color(0xFFE5536C);
  }

  static const Color playerBodyColor = Color(0xFF3FB950);

  // ---- Serialization ----
  Map<String, dynamic> toJson() => {
    'selectedClass': selectedClass,
    'level': level,
    'xp': xp,
    'gold': gold,
    'potions': potions,
    'glovesBonus': glovesBonus,
    'fightNumber': fightNumber,
    'autoFightEnabled': autoFightEnabled,
    'playerHp': playerHp,
    'cpuHp': cpuHp,
    'cpuMaxHp': cpuMaxHp,
    'isGameOver': isGameOver,
    'bestFight': bestFight,
    'statusText': statusText,
  };

  /// Applies a decoded save map with the same defensive validation as the JS
  /// `loadProgress`. Invalid fields fall back to sane defaults.
  void applyJson(Map<String, dynamic> data) {
    selectedClass = kClasses.containsKey(data['selectedClass'])
        ? data['selectedClass'] as String
        : 'brawler';
    level = _posInt(data['level'], 1);
    xp = _nonNegInt(data['xp'], 0);
    gold = _nonNegInt(data['gold'], 0);
    potions = _nonNegInt(data['potions'], 0);
    glovesBonus = _nonNegInt(data['glovesBonus'], 0);
    fightNumber = _posInt(data['fightNumber'], 1);
    autoFightEnabled = data['autoFightEnabled'] == true;
    playerMaxHp = currentClass.maxHp + (level - 1) * 10;
    currentEnemy = getEnemyForFight();

    final num? rawCpuMax = data['cpuMaxHp'] is num ? data['cpuMaxHp'] as num : null;
    cpuMaxHp = (rawCpuMax != null && rawCpuMax > 0)
        ? rawCpuMax.floor()
        : ((kBaseCpuHp + (level - 1) * 10) * currentEnemy.hpMultiplier).floor();

    final num? rawPlayerHp = data['playerHp'] is num ? data['playerHp'] as num : null;
    playerHp = (rawPlayerHp != null && rawPlayerHp >= 0)
        ? min(playerMaxHp, rawPlayerHp.floor())
        : playerMaxHp;

    final num? rawCpuHp = data['cpuHp'] is num ? data['cpuHp'] as num : null;
    cpuHp = (rawCpuHp != null && rawCpuHp >= 0)
        ? min(cpuMaxHp, rawCpuHp.floor())
        : cpuMaxHp;

    isGameOver = data['isGameOver'] == true;
    final String? status = data['statusText'] is String
        ? data['statusText'] as String
        : null;
    statusText = (status != null && status.isNotEmpty) ? status : 'Save loaded.';
    bestFight = _posInt(data['bestFight'], fightNumber);
    if (bestFight < fightNumber) {
      bestFight = fightNumber;
    }
  }

  static int _posInt(dynamic value, int fallback) {
    if (value is num && value.isFinite && value > 0) {
      return value.floor();
    }
    return fallback;
  }

  static int _nonNegInt(dynamic value, int fallback) {
    if (value is num && value.isFinite && value >= 0) {
      return value.floor();
    }
    return fallback;
  }
}
