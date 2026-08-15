import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:localstorage/localstorage.dart';

class ShipConfig {
  final String id;
  final String name;
  final String role;
  final String description;
  final int maxHp;
  final double speed;
  final int baseWeaponLevel;
  final Color primaryColor;
  final Color accentColor;
  final IconData icon;

  const ShipConfig({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.maxHp,
    required this.speed,
    required this.baseWeaponLevel,
    required this.primaryColor,
    required this.accentColor,
    required this.icon,
  });
}

const List<ShipConfig> kShipConfigs = [
  ShipConfig(
    id: 'fighter',
    name: 'F-22 Starfighter',
    role: 'Balanced Strike Craft',
    description: 'Balanced speed, agility, and single-beam plasma blasters.',
    maxHp: 100,
    speed: 5.0,
    baseWeaponLevel: 1,
    primaryColor: Color(0xFF00F2FE),
    accentColor: Color(0xFFFF3333),
    icon: Icons.flight,
  ),
  ShipConfig(
    id: 'cruiser',
    name: 'Dreadnought Cruiser',
    role: 'Heavy Armored Gunship',
    description: 'Massive hull durability with factory-installed dual heavy cannons.',
    maxHp: 180,
    speed: 3.2,
    baseWeaponLevel: 2,
    primaryColor: Color(0xFFFF8800),
    accentColor: Color(0xFFFFCC00),
    icon: Icons.shield,
  ),
  ShipConfig(
    id: 'interceptor',
    name: 'Phantom Interceptor',
    role: 'Rapid High-Speed Scout',
    description: 'Extreme maneuvering speed with razor-sharp forward delta wings.',
    maxHp: 60,
    speed: 7.5,
    baseWeaponLevel: 1,
    primaryColor: Color(0xFF00FF88),
    accentColor: Color(0xFF00BFFF),
    icon: Icons.bolt,
  ),
];

class AlienInvasionScreen extends StatefulWidget {
  const AlienInvasionScreen({super.key});

  @override
  State<AlienInvasionScreen> createState() => _AlienInvasionScreenState();
}

class _AlienInvasionScreenState extends State<AlienInvasionScreen>
    with SingleTickerProviderStateMixin {
  static const String _highScoreKey = 'alien_invasion_highscore';
  static const String _bestWaveKey = 'alien_invasion_best_wave';

  late Ticker _ticker;
  final math.Random _random = math.Random();
  final FocusNode _focusNode = FocusNode();

  // Menu and ship selection
  bool inMenu = true;
  String selectedShipId = 'fighter';

  // Game configuration & constants
  static const double logicalWidth = 800.0;
  static const double bulletSpeed = 7.0;
  static const double bulletWidth = 4.0;
  static const double bulletHeight = 10.0;
  static const double alienWidth = 30.0;
  static const double alienHeight = 20.0;
  static const double alienSpeed = 1.0;
  static const double powerUpSize = 16.0;
  static const double powerUpSpeed = 2.0;
  static const double powerUpDropChance = 0.15;
  static const double coinRadius = 7.0;
  static const double coinSpeed = 2.5;
  static const double coinDropChance = 0.35;
  static const int coinValue = 25;
  static const int particleCount = 20;
  static const int particleLifetime = 30;
  static const int comboWindowFrames = 90;
  static const int comboStepHits = 3;
  static const int maxComboMultiplier = 6;

  // Game state variables
  late GamePlayer player;
  final List<GameBullet> bullets = [];
  final List<GameAlien> aliens = [];
  final List<GameBoss> bosses = [];
  final List<GameSpawnling> spawnlings = [];
  final List<GameInkShot> inkShots = [];
  final List<GameParticle> particles = [];
  final List<GamePowerUp> powerUps = [];
  final List<GameCoin> coins = [];
  final List<GameScorePopup> scorePopups = [];
  final List<GameStar> stars = [];
  final List<GamePlanet> planets = [];

  int score = 0;
  int highScore = 0;
  int bestWave = 0;
  int scoreFlashFrames = 0;
  int comboCount = 0;
  int comboTimerFrames = 0;
  int weaponLevel = 1;
  int waveNumber = 1;
  int bulletsShot = 0;
  int hits = 0;
  int coinsCollected = 0;

  bool gameOver = false;
  bool canShoot = true;
  bool isLoopRunning = false;
  bool leftPressed = false;
  bool rightPressed = false;
  bool spacePressed = false;
  bool shootPressed = false;

  // Visual effects
  double shakeIntensity = 0.0;
  double flashOpacity = 0.0;

  // Time accumulator for fixed 60FPS game loop
  double _lag = 0.0;
  Duration _lastTime = Duration.zero;

  Future<void> _playClickSound() async {
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> _playAlertSound() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _resetGame();
    _ticker = createTicker(_onTick);
    _ticker.start();
    isLoopRunning = true;

    // Focus the node for keyboard inputs
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _loadHighScore() {
    try {
      final String? scoreStr = localStorage.getItem(_highScoreKey);
      final String? waveStr = localStorage.getItem(_bestWaveKey);
      if (scoreStr != null) {
        highScore = int.tryParse(scoreStr) ?? 0;
      }
      if (waveStr != null) {
        bestWave = int.tryParse(waveStr) ?? 0;
      }
    } catch (_) {}
  }

  void _saveHighScore() {
    var shouldSave = false;

    if (score > highScore) {
      highScore = score;
      shouldSave = true;
    }

    if (waveNumber > bestWave) {
      bestWave = waveNumber;
      shouldSave = true;
    }

    if (shouldSave) {
      try {
        localStorage.setItem(_highScoreKey, highScore.toString());
        localStorage.setItem(_bestWaveKey, bestWave.toString());
      } catch (_) {}
    }
  }

  void _initBackground() {
    stars.clear();
    planets.clear();

    // Create background stars
    for (int i = 0; i < 60; i++) {
      stars.add(GameStar(
        x: _random.nextDouble() * logicalWidth,
        y: _random.nextDouble() * 900.0,
        speed: _random.nextDouble() * 1.5 + 0.5,
        radius: _random.nextDouble() * 1.2 + 0.8,
        color: Colors.white.withValues(alpha: _random.nextDouble() * 0.5 + 0.3),
      ));
    }
    
    // Create planets
    planets.add(GamePlanet(
      x: logicalWidth * 0.8,
      y: 100.0,
      radius: 40.0,
      speed: 0.2,
      color1: const Color(0xFF8B3A3A),
      color2: const Color(0xFF2E0854),
    ));
    planets.add(GamePlanet(
      x: logicalWidth * 0.15,
      y: 400.0,
      radius: 80.0,
      speed: 0.1,
      color1: const Color(0xFF20B2AA),
      color2: const Color(0xFF000080),
      hasRings: true,
    ));
  }

  void _resetGame() {
    final config = kShipConfigs.firstWhere(
      (c) => c.id == selectedShipId,
      orElse: () => kShipConfigs[0],
    );

    final double pWidth = config.id == 'cruiser'
        ? 52.0
        : (config.id == 'interceptor' ? 36.0 : 40.0);
    final double pHeight = config.id == 'cruiser' ? 24.0 : 20.0;

    player = GamePlayer()
      ..width = pWidth
      ..height = pHeight
      ..speed = config.speed
      ..hp = config.maxHp
      ..maxHp = config.maxHp
      ..shipType = config.id
      ..x = logicalWidth / 2 - pWidth / 2;

    bullets.clear();
    aliens.clear();
    bosses.clear();
    spawnlings.clear();
    inkShots.clear();
    particles.clear();
    powerUps.clear();
    coins.clear();
    scorePopups.clear();
    _initBackground();

    score = 0;
    bulletsShot = 0;
    hits = 0;
    coinsCollected = 0;
    weaponLevel = config.baseWeaponLevel;
    waveNumber = 1;
    comboCount = 0;
    comboTimerFrames = 0;
    gameOver = false;
    canShoot = true;
    shootPressed = false;
    alienDirection = 1;
    shakeIntensity = 0.0;
    flashOpacity = 0.0;
    _lag = 0.0;
    _lastTime = Duration.zero;

    _adjustPlayerY();
    _createAliens();
  }

  void _damagePlayer(int amount) {
    if (gameOver || inMenu) return;
    player.hp = (player.hp - amount).clamp(0, player.maxHp);
    shakeIntensity = 8.0;
    flashOpacity = 0.4;
    _playAlertSound();
    HapticFeedback.heavyImpact();

    if (player.hp <= 0) {
      _endGame();
    }
  }

  double alienDirection = 1.0;

  double get _logicalHeight {
    // Determine dynamic logical height based on aspect ratio
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 768;
    return isMobile ? 900.0 : 600.0;
  }

  void _adjustPlayerY() {
    // Post frame or widget build to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        player.y = _logicalHeight - player.height - 12;
      });
    });
  }

  void _createAliens() {
    aliens.clear();
    spawnlings.clear();
    inkShots.clear();
    const double sidePadding = 30.0;
    const double gap = 20.0;
    const double step = alienWidth + gap;
    final int columns = ((logicalWidth - sidePadding * 2 + gap) / step).floor();

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < columns; col++) {
        aliens.add(
          GameAlien(
            sidePadding + col * step,
            sidePadding + row * (alienHeight + gap),
          ),
        );
      }
    }

    _createBoss();
  }

  void _createBoss() {
    bosses.clear();
    spawnlings.clear();
    inkShots.clear();

    const bossTypes = [
      BossType.octopus,
      BossType.mothership,
      BossType.lasercore,
      BossType.hive,
    ];
    final type = bossTypes[(waveNumber - 1) % bossTypes.length];
    bosses.add(_makeBoss(type, id: 'w$waveNumber-boss'));
  }

  GameBoss _makeBoss(
    BossType type, {
    required String id,
    double? x,
    double? y,
    int? hp,
    int gen = 0,
    double dir = 1.0,
    double sizeMul = 1.0,
  }) {
    final int bossHue = _random.nextInt(360);
    final double hpMulti = 1.0 + (waveNumber - 1) * 0.2;
    final double speedMulti = 1.0 + (waveNumber - 1) * 0.1;
    final double attackRateMulti = 1.0 + (waveNumber - 1) * 0.1;

    double baseWidth;
    double baseHeight;
    int baseHp;
    double baseSpeed;
    int baseSpawnT;

    switch (type) {
      case BossType.octopus:
        baseWidth = 90.0;
        baseHeight = 30.0;
        baseHp = 12;
        baseSpeed = 1.5;
        baseSpawnT = 170;
        break;
      case BossType.mothership:
        baseWidth = 130.0;
        baseHeight = 34.0;
        baseHp = 28;
        baseSpeed = 0.8;
        baseSpawnT = 150;
        break;
      case BossType.lasercore:
        baseWidth = 70.0;
        baseHeight = 46.0;
        baseHp = 16;
        baseSpeed = 1.2;
        baseSpawnT = 150;
        break;
      case BossType.hive:
        baseWidth = 84.0;
        baseHeight = 42.0;
        baseHp = 12;
        baseSpeed = 1.2;
        baseSpawnT = 150;
        break;
    }

    final double width = baseWidth * sizeMul;
    final double height = baseHeight * sizeMul;
    final int scaledHp = hp ?? math.max(1, (baseHp * hpMulti).floor());
    final double scaledSpeed = baseSpeed * speedMulti;

    return GameBoss(
      id: id,
      type: type,
      x: x ?? (logicalWidth / 2 - width / 2),
      y: y ?? 8.0,
      width: width,
      height: height,
      hp: scaledHp,
      maxHp: scaledHp,
      speed: scaledSpeed,
      dir: dir,
      gen: gen,
      phase: 'move',
      phaseT: math.max(10, (150 / attackRateMulti).floor()),
      spawnT: math.max(10, (baseSpawnT / attackRateMulti).floor()),
      wobbleT: _random.nextDouble() * math.pi * 2,
      bodyColor: HSVColor.fromAHSV(
        1.0,
        bossHue.toDouble(),
        0.65,
        0.38,
      ).toColor(),
      highlightColor: HSVColor.fromAHSV(
        1.0,
        bossHue.toDouble(),
        0.70,
        0.62,
      ).toColor(),
      tentacleColor: HSVColor.fromAHSV(
        1.0,
        bossHue.toDouble(),
        0.72,
        0.32,
      ).toColor(),
    );
  }

  void _spawnKamikaze(GameBoss boss) {
    spawnlings.add(
      GameSpawnling(
        x: boss.x + boss.width / 2 - 9.0,
        y: boss.y + boss.height,
        width: 18.0,
        height: 16.0,
        vy: 2.2,
      ),
    );
  }

  void _spawnInk(GameBoss boss) {
    final double cx = boss.x + boss.width / 2;
    final double targetX = player.x + player.width / 2;
    final double dx = ((targetX - cx) / 80.0).clamp(-1.5, 1.5);
    inkShots.add(
      GameInkShot(
        x: cx,
        y: boss.y + boss.height * 0.7,
        r: 8.0,
        vx: dx,
        vy: 2.1,
      ),
    );
  }

  void _killBoss(int index) {
    if (index >= bosses.length) return;
    final boss = bosses[index];
    final double cx = boss.x + boss.width / 2;
    final double cy = boss.y + boss.height / 2;

    _playAlertSound();
    _createFireworks(cx, cy);
    _createFireworks(cx + 10, cy);
    flashOpacity = 0.6;
    HapticFeedback.vibrate();

    int scoreBonus;
    switch (boss.type) {
      case BossType.octopus:
        scoreBonus = 120;
        break;
      case BossType.mothership:
        scoreBonus = 250;
        break;
      case BossType.lasercore:
        scoreBonus = 180;
        break;
      case BossType.hive:
        const hiveGenScores = [60, 40, 25];
        scoreBonus = hiveGenScores[boss.gen.clamp(0, 2)];
        break;
    }

    _addScore(scoreBonus, cx, cy, const Color(0xFF7AF58F));
    bosses.removeAt(index);

    // Swarm Hive split behavior
    if (boss.type == BossType.hive && boss.gen < 2) {
      final int nextGen = boss.gen + 1;
      final int childHp = math.max(1, (boss.maxHp / 2).round());
      final double sizeMul = math.pow(0.65, nextGen).toDouble();
      final double childW = 84.0 * sizeMul;

      int childIdx = 0;
      for (final dir in [-1.0, 1.0]) {
        final child = _makeBoss(
          BossType.hive,
          id: '${boss.id}.${childIdx++}',
          gen: nextGen,
          hp: childHp,
          dir: dir,
          sizeMul: sizeMul,
          x: (cx + dir * boss.width * 0.35 - childW / 2).clamp(
            0.0,
            logicalWidth - childW,
          ),
          y: boss.y + boss.height * 0.15,
        );
        bosses.add(child);
        _createFireworks(child.x + child.width / 2, child.y + child.height / 2);
      }

      scorePopups.add(
        GameScorePopup(
          x: cx,
          y: cy - 14,
          text: 'SPLIT!',
          life: 40,
          color: const Color(0xFF8AFF8A),
        ),
      );
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }
    double elapsedMs = (elapsed - _lastTime).inMicroseconds / 1000.0;
    _lastTime = elapsed;

    // Cap excessive delta times (e.g. background tab resuming) to prevent freezing
    if (elapsedMs > 100.0) elapsedMs = 16.67;

    _lag += elapsedMs;
    const double msPerFrame = 1000.0 / 60.0;

    while (_lag >= msPerFrame) {
      _updateBackground();
      if (!gameOver && !inMenu) {
        _updateGame();
      }
      _lag -= msPerFrame;
    }

    // Dampen visual effects
    if (shakeIntensity > 0.05) {
      shakeIntensity *= 0.9;
    } else {
      shakeIntensity = 0.0;
    }

    if (flashOpacity > 0.02) {
      flashOpacity *= 0.85;
    } else {
      flashOpacity = 0.0;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _updateBackground() {
    final currentHeight = _logicalHeight;
    for (final star in stars) {
      star.y += star.speed;
      if (star.y > currentHeight) {
        star.y = 0;
        star.x = _random.nextDouble() * logicalWidth;
      }
    }
    for (final planet in planets) {
      planet.y += planet.speed;
      if (planet.y - planet.radius > currentHeight) {
        planet.y = -planet.radius * 2;
        planet.x = _random.nextDouble() * logicalWidth;
      }
    }
  }

  void _updateGame() {
    final currentHeight = _logicalHeight;

    // Combo timer decrement
    if (comboTimerFrames > 0) {
      comboTimerFrames--;
      if (comboTimerFrames == 0) comboCount = 0;
    }

    // Player keyboard movement
    if (leftPressed && player.x > 0) {
      player.x -= player.speed;
    }
    if (rightPressed && player.x < logicalWidth - player.width) {
      player.x += player.speed;
    }

    // Auto-fire or key-held fire
    if ((spacePressed || shootPressed) && canShoot) {
      _shootBullet();
    }

    // Update bullets
    for (int i = bullets.length - 1; i >= 0; i--) {
      bullets[i].y -= bulletSpeed;
      if (bullets[i].y < 0) {
        bullets.removeAt(i);
      }
    }

    // Update aliens movement
    bool hitEdge = false;

    for (int i = aliens.length - 1; i >= 0; i--) {
      final alien = aliens[i];
      alien.x += alienSpeed * alienDirection;
      if (alien.x + alien.width > logicalWidth || alien.x < 0) {
        hitEdge = true;
      }
      if (alien.y + alien.height > currentHeight - player.height - 20) {
        _damagePlayer(20);
        _createFireworks(alien.x, alien.y);
        aliens.removeAt(i);
      }
    }

    if (hitEdge) {
      alienDirection *= -1;
      for (final alien in aliens) {
        alien.y += 20;
      }
    }

    // Update Bosses
    for (int bIdx = bosses.length - 1; bIdx >= 0; bIdx--) {
      if (bIdx >= bosses.length) continue;
      final boss = bosses[bIdx];
      bool moving = true;

      if (boss.type == BossType.lasercore) {
        boss.phaseT--;
        if (boss.phaseT <= 0) {
          final double attackRateMulti = 1.0 + (waveNumber - 1) * 0.1;
          if (boss.phase == 'move') {
            boss.phase = 'charging';
            boss.phaseT = math.max(10, (70 / attackRateMulti).floor());
          } else if (boss.phase == 'charging') {
            boss.phase = 'firing';
            boss.phaseT = math.max(10, (50 / attackRateMulti).floor());
            _playAlertSound();
            HapticFeedback.mediumImpact();
          } else {
            boss.phase = 'move';
            boss.phaseT = math.max(10, (150 / attackRateMulti).floor());
          }
        }
        moving = boss.phase == 'move';

        // Damage player if caught in beam
        if (boss.phase == 'firing') {
          final double cx = boss.x + boss.width / 2;
          final double halfW = boss.width * 0.45;
          final double beamLeft = cx - halfW;
          final double beamRight = cx + halfW;
          final double beamTop = boss.y + boss.height;

          if (player.x < beamRight &&
              player.x + player.width > beamLeft &&
              player.y + player.height > beamTop) {
            _damagePlayer(2);
          }
        }
      } else if (boss.type == BossType.mothership) {
        boss.spawnT--;
        if (boss.spawnT <= 0 && spawnlings.length < 4) {
          final double attackRateMulti = 1.0 + (waveNumber - 1) * 0.1;
          boss.spawnT = math.max(10, (150 / attackRateMulti).floor());
          _spawnKamikaze(boss);
        }
      } else if (boss.type == BossType.octopus) {
        boss.spawnT--;
        if (boss.spawnT <= 0) {
          final double attackRateMulti = 1.0 + (waveNumber - 1) * 0.1;
          boss.spawnT = math.max(10, (170 / attackRateMulti).floor());
          _spawnInk(boss);
        }
      } else if (boss.type == BossType.hive) {
        boss.wobbleT += 0.08 + boss.gen * 0.03;
      }

      if (moving) {
        final double speed = boss.type == BossType.hive
            ? [1.2, 2.0, 2.8][boss.gen.clamp(0, 2)]
            : boss.speed;
        boss.x += alienSpeed * speed * boss.dir;
        if (boss.x + boss.width > logicalWidth) {
          boss.x = logicalWidth - boss.width;
          boss.dir = -1.0;
        } else if (boss.x < 0) {
          boss.x = 0;
          boss.dir = 1.0;
        }
      }

      if (boss.y + boss.height > currentHeight - player.height - 20) {
        _damagePlayer(40);
        boss.y = 10.0;
      }
    }

    // Update Spawnlings (Kamikaze daggers)
    for (int i = spawnlings.length - 1; i >= 0; i--) {
      final s = spawnlings[i];
      s.y += s.vy;
      if (s.x < player.x + player.width &&
          s.x + s.width > player.x &&
          s.y < player.y + player.height &&
          s.y + s.height > player.y) {
        _damagePlayer(15);
        _createFireworks(s.x, s.y);
        spawnlings.removeAt(i);
      } else if (s.y > currentHeight) {
        spawnlings.removeAt(i);
      }
    }

    // Update Ink Shots
    for (int i = inkShots.length - 1; i >= 0; i--) {
      final ink = inkShots[i];
      ink.x += ink.vx;
      ink.y += ink.vy;
      ink.wobbleT += 0.1;
      if (ink.x - ink.r < player.x + player.width &&
          ink.x + ink.r > player.x &&
          ink.y - ink.r < player.y + player.height &&
          ink.y + ink.r > player.y) {
        _damagePlayer(10);
        _createFireworks(ink.x, ink.y);
        inkShots.removeAt(i);
      } else if (ink.y - ink.r > currentHeight || ink.x < 0 || ink.x > logicalWidth) {
        inkShots.removeAt(i);
      }
    }

    // Collision detection: Bullets vs Aliens, Bosses, Spawnlings, InkShots
    for (int bIndex = bullets.length - 1; bIndex >= 0; bIndex--) {
      if (bIndex >= bullets.length) continue;
      final bullet = bullets[bIndex];
      bool bulletConsumed = false;

      // 1. Bullets vs Spawnlings
      for (int sIdx = spawnlings.length - 1; sIdx >= 0; sIdx--) {
        final s = spawnlings[sIdx];
        if (bullet.x < s.x + s.width &&
            bullet.x + bulletWidth > s.x &&
            bullet.y < s.y + s.height &&
            bullet.y + bulletHeight > s.y) {
          _playClickSound();
          _createFireworks(s.x, s.y);
          spawnlings.removeAt(sIdx);
          bullets.removeAt(bIndex);
          hits++;
          _addScore(15, s.x, s.y, const Color(0xFFFFB46B));
          bulletConsumed = true;
          break;
        }
      }
      if (bulletConsumed || bIndex >= bullets.length) continue;

      // 2. Bullets vs InkShots
      for (int inkIdx = inkShots.length - 1; inkIdx >= 0; inkIdx--) {
        final ink = inkShots[inkIdx];
        if (bullet.x < ink.x + ink.r &&
            bullet.x + bulletWidth > ink.x - ink.r &&
            bullet.y < ink.y + ink.r &&
            bullet.y + bulletHeight > ink.y - ink.r) {
          _playClickSound();
          _createFireworks(ink.x, ink.y);
          inkShots.removeAt(inkIdx);
          bullets.removeAt(bIndex);
          hits++;
          _addScore(10, ink.x, ink.y, const Color(0xFFBA8FFF));
          bulletConsumed = true;
          break;
        }
      }
      if (bulletConsumed || bIndex >= bullets.length) continue;

      // 3. Bullets vs Aliens
      for (int aIndex = aliens.length - 1; aIndex >= 0; aIndex--) {
        final alien = aliens[aIndex];
        if (bullet.x < alien.x + alien.width &&
            bullet.x + bulletWidth > alien.x &&
            bullet.y < alien.y + alien.height &&
            bullet.y + bulletHeight > alien.y) {
          _playClickSound();
          _createFireworks(alien.x, alien.y);
          HapticFeedback.lightImpact();

          // Drop logic
          if (weaponLevel < 3 && _random.nextDouble() < powerUpDropChance) {
            powerUps.add(
              GamePowerUp(
                alien.x + alien.width / 2 - powerUpSize / 2,
                alien.y + alien.height / 2 - powerUpSize / 2,
              ),
            );
          } else if (weaponLevel == 3 &&
              _random.nextDouble() < coinDropChance) {
            coins.add(
              GameCoin(alien.x + alien.width / 2, alien.y + alien.height / 2),
            );
          }

          aliens.removeAt(aIndex);
          bullets.removeAt(bIndex);
          _addScore(
            10,
            alien.x + alien.width / 2,
            alien.y + alien.height / 2,
            const Color(0xFFFFD54A),
          );
          hits++;
          bulletConsumed = true;
          break;
        }
      }

      if (bulletConsumed || bIndex >= bullets.length) continue;

      // 4. Bullets vs Bosses
      for (int boIdx = bosses.length - 1; boIdx >= 0; boIdx--) {
        final b = bosses[boIdx];
        if (bullet.x < b.x + b.width &&
            bullet.x + bulletWidth > b.x &&
            bullet.y < b.y + b.height &&
            bullet.y + bulletHeight > b.y) {
          _playClickSound();
          b.hp--;
          bullets.removeAt(bIndex);
          hits++;
          HapticFeedback.mediumImpact();
          _addScore(5, bullet.x, bullet.y, const Color(0xFF9BE7FF));

          if (b.hp <= 0) {
            _killBoss(boIdx);
          }
          break;
        }
      }
    }

    // Update PowerUps
    for (int i = powerUps.length - 1; i >= 0; i--) {
      final p = powerUps[i];
      p.y += powerUpSpeed;

      final bool collected =
          p.x < player.x + player.width &&
          p.x + powerUpSize > player.x &&
          p.y < player.y + player.height &&
          p.y + powerUpSize > player.y;

      if (collected) {
        _playAlertSound();
        _applyWeaponUpgrade();
        HapticFeedback.vibrate();
        if (powerUps.isEmpty) {
          break;
        }
        powerUps.removeAt(i);
      } else if (p.y > currentHeight) {
        powerUps.removeAt(i);
      }
    }

    // Update Coins
    for (int i = coins.length - 1; i >= 0; i--) {
      final c = coins[i];
      c.y += coinSpeed;

      final bool collected =
          c.x + coinRadius > player.x &&
          c.x - coinRadius < player.x + player.width &&
          c.y + coinRadius > player.y &&
          c.y - coinRadius < player.y + player.height;

      if (collected) {
        _playClickSound();
        _addScore(
          coinValue,
          c.x,
          c.y,
          const Color(0xFFFFE066),
          countsForCombo: false,
        );
        coinsCollected++;
        HapticFeedback.mediumImpact();
        coins.removeAt(i);
      } else if (c.y - coinRadius > currentHeight) {
        coins.removeAt(i);
      }
    }

    // Update Particles
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.vy += 0.1;
      p.life--;

      if (p.life <= 0) {
        particles.removeAt(i);
      }
    }

    // Update Score Popups
    for (int i = scorePopups.length - 1; i >= 0; i--) {
      final p = scorePopups[i];
      p.y -= 0.85;
      p.life--;

      if (p.life <= 0) {
        scorePopups.removeAt(i);
      }
    }

    // Start next wave if both aliens and bosses are cleared
    if (aliens.isEmpty && bosses.isEmpty) {
      waveNumber++;
      _createAliens();
    }
  }

  void _shootBullet() {
    final int bulletsPerShot = weaponLevel;
    if (bullets.length <= 6 - bulletsPerShot) {
      if (weaponLevel == 3) {
        bullets.add(
          GameBullet(
            player.x + player.width * 0.2 - bulletWidth / 2,
            player.y - bulletHeight,
          ),
        );
        bullets.add(
          GameBullet(
            player.x + player.width / 2 - bulletWidth / 2,
            player.y - bulletHeight,
          ),
        );
        bullets.add(
          GameBullet(
            player.x + player.width * 0.8 - bulletWidth / 2,
            player.y - bulletHeight,
          ),
        );
      } else if (weaponLevel == 2) {
        bullets.add(
          GameBullet(
            player.x + player.width * 0.25 - bulletWidth / 2,
            player.y - bulletHeight,
          ),
        );
        bullets.add(
          GameBullet(
            player.x + player.width * 0.75 - bulletWidth / 2,
            player.y - bulletHeight,
          ),
        );
      } else {
        bullets.add(
          GameBullet(
            player.x + player.width / 2 - bulletWidth / 2,
            player.y - bulletHeight,
          ),
        );
      }

      bulletsShot += bulletsPerShot;
      canShoot = false;
      _playClickSound();
      HapticFeedback.selectionClick();

      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {
            canShoot = true;
          });
        }
      });
    }
  }

  void _applyWeaponUpgrade() {
    weaponLevel = (weaponLevel + 1).clamp(1, 3);
    if (weaponLevel == 3) {
      powerUps.clear();
    }
  }

  int _getComboMultiplier(int streak) {
    return (1 + ((streak - 1).clamp(0, 999) ~/ comboStepHits)).clamp(
      1,
      maxComboMultiplier,
    );
  }

  void _addScore(
    int points,
    double x,
    double y,
    Color color, {
    bool countsForCombo = true,
  }) {
    if (countsForCombo) {
      comboCount = comboTimerFrames > 0 ? comboCount + 1 : 1;
      comboTimerFrames = comboWindowFrames;
    }

    final int multiplier = countsForCombo ? _getComboMultiplier(comboCount) : 1;
    final int finalPoints = points * multiplier;

    score += finalPoints;
    scoreFlashFrames = (10 + multiplier * 3).clamp(0, 26);

    scorePopups.add(
      GameScorePopup(
        x: x,
        y: y,
        text: multiplier > 1 ? '+$finalPoints x$multiplier' : '+$finalPoints',
        life: 32,
        color: color,
      ),
    );
  }

  void _createFireworks(double x, double y) {
    for (int i = 0; i < particleCount; i++) {
      final double angle = _random.nextDouble() * math.pi * 2;
      final double speed = _random.nextDouble() * 3.0 + 1.0;
      particles.add(
        GameParticle(
          x: x + alienWidth / 2,
          y: y + alienHeight / 2,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          life: particleLifetime.toDouble(),
          color: HSVColor.fromAHSV(
            1.0,
            _random.nextInt(360).toDouble(),
            1.0,
            0.9,
          ).toColor(),
        ),
      );
    }
  }

  void _endGame() {
    gameOver = true;
    flashOpacity = 0.8;
    _playAlertSound();
    HapticFeedback.vibrate();
    _saveHighScore();
  }

  void _handleKeyEvent(KeyEvent event) {
    final bool isDown = event is KeyDownEvent || event is KeyRepeatEvent;

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      leftPressed = isDown;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      rightPressed = isDown;
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      spacePressed = isDown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;
    final currentHeight = _logicalHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: EdgeInsets.fromLTRB(
                16.0,
                MediaQuery.of(context).padding.top + 8.0,
                16.0,
                8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'INVASION',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      if (!inMenu)
                        TextButton.icon(
                          icon: const Icon(Icons.rocket_launch, size: 16, color: Color(0xFF00F2FE)),
                          label: const Text('Hangar', style: TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold)),
                          onPressed: () => setState(() => inMenu = true),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (inMenu) {
                            setState(() => inMenu = false);
                          }
                          _resetGame();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Restart',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Canvas Game Area
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 800.0 / currentHeight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF1F1F1F)),
                      color: const Color(0xFF020204),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: MouseRegion(
                      onHover: (event) {
                        if (gameOver || inMenu) return;
                        // Map local position to logical coordinates
                        final RenderBox renderBox =
                            context.findRenderObject() as RenderBox;
                        final double widthRatio =
                            logicalWidth / renderBox.size.width;
                        final double mouseX =
                            event.localPosition.dx * widthRatio;
                        setState(() {
                          player.x = (mouseX - player.width / 2).clamp(
                            0.0,
                            logicalWidth - player.width,
                          );
                        });
                      },
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size.infinite,
                            painter: GamePainter(
                              player: player,
                              bullets: bullets,
                              aliens: aliens,
                              bosses: bosses,
                              spawnlings: spawnlings,
                              inkShots: inkShots,
                              particles: particles,
                              powerUps: powerUps,
                              coins: coins,
                              scorePopups: scorePopups,
                              stars: stars,
                              planets: planets,
                              score: score,
                              comboCount: comboCount,
                              comboTimerFrames: comboTimerFrames,
                              comboWindowFrames: comboWindowFrames,
                              multiplier: _getComboMultiplier(comboCount),
                              scoreFlashFrames: scoreFlashFrames,
                              bulletsShot: bulletsShot,
                              hits: hits,
                              coinsCollected: coinsCollected,
                              waveNumber: waveNumber,
                              weaponLevel: weaponLevel,
                              shakeIntensity: shakeIntensity,
                              flashOpacity: flashOpacity,
                              logicalHeight: currentHeight,
                              gameOver: gameOver,
                              highScore: highScore,
                            ),
                          ),

                          // Hangar Ship Selector Overlay
                          if (inMenu)
                            _buildHangarOverlay(isMobile),

                          // Game instructions or Game Over modal overlay
                          if (gameOver && !inMenu)
                            Container(
                              color: Colors.black87,
                              width: double.infinity,
                              height: double.infinity,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'GAME OVER!',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.redAccent,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Final Score: $score',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'High Score: ${math.max(score, highScore)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFFFFD54A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Hit Rate: ${bulletsShot > 0 ? ((hits / bulletsShot) * 100).toStringAsFixed(1) : "0"}%',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            inMenu = true;
                                            gameOver = false;
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFF00F2FE)),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text('CHANGE SHIP'),
                                      ),
                                      const SizedBox(width: 16),
                                      ElevatedButton(
                                        onPressed: () {
                                          _resetGame();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7B2CBF),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        child: const Text(
                                          'PLAY AGAIN',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Touch Controls for Mobile/Tablet
            if (isMobile)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Movement Controls
                      Row(
                        children: [
                          _buildTouchButton(
                            icon: Icons.arrow_back,
                            onDown: () => setState(() => leftPressed = true),
                            onUp: () => setState(() => leftPressed = false),
                          ),
                          const SizedBox(width: 16),
                          _buildTouchButton(
                            icon: Icons.arrow_forward,
                            onDown: () => setState(() => rightPressed = true),
                            onUp: () => setState(() => rightPressed = false),
                          ),
                        ],
                      ),

                      // Fire Button (Supports Hold to Shoot)
                      _buildTouchButton(
                        icon: Icons.gps_fixed,
                        color: shootPressed
                            ? Colors.redAccent.withValues(alpha: 0.75)
                            : Colors.redAccent.withValues(alpha: 0.4),
                        onDown: () {
                          setState(() => shootPressed = true);
                          if (!gameOver && canShoot && !inMenu) {
                            _shootBullet();
                          }
                        },
                        onUp: () {
                          setState(() => shootPressed = false);
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Controls: Left/Right Arrows or Mouse Hover to Move | Spacebar or Click to Shoot',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouchButton({
    required IconData icon,
    required VoidCallback onDown,
    required VoidCallback onUp,
    Color? color,
  }) {
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  Widget _buildHangarOverlay(bool isMobile) {
    final selectedConfig = kShipConfigs.firstWhere(
      (c) => c.id == selectedShipId,
      orElse: () => kShipConfigs[0],
    );

    return Container(
      color: Colors.black.withValues(alpha: 0.88),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                  ).createShader(bounds),
                  child: const Text(
                    'STARFLEET HANGAR',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'SELECT YOUR COMBAT VESSEL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Color(0xFF9E8FFF),
                  ),
                ),
                const SizedBox(height: 20),

                // Ship Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool useRow = constraints.maxWidth > 550;
                    final cardWidgets = kShipConfigs.map((ship) {
                      final bool isSelected = ship.id == selectedShipId;
                      final cardBody = GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedShipId = ship.id;
                            _playClickSound();
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(6.0),
                          padding: const EdgeInsets.all(14.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ship.primaryColor.withValues(alpha: 0.15)
                                : const Color(0xFF141724).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? ship.primaryColor
                                  : Colors.white12,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: ship.primaryColor.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(
                                    ship.icon,
                                    color: isSelected ? ship.primaryColor : Colors.white70,
                                    size: 26,
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ship.primaryColor,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ship.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : Colors.white70,
                                ),
                              ),
                              Text(
                                ship.role,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: ship.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildStatBar('HULL', ship.maxHp / 180.0, '${ship.maxHp} HP', ship.primaryColor),
                              const SizedBox(height: 6),
                              _buildStatBar('SPEED', ship.speed / 7.5, '${ship.speed.toStringAsFixed(1)}x', ship.primaryColor),
                              const SizedBox(height: 6),
                              _buildStatBar('FIREPOWER', ship.baseWeaponLevel / 3.0, 'LVL ${ship.baseWeaponLevel}', ship.primaryColor),
                            ],
                          ),
                        ),
                      );

                      return useRow ? Expanded(child: cardBody) : cardBody;
                    }).toList();

                    return useRow
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: cardWidgets,
                          )
                        : Column(
                            children: cardWidgets,
                          );
                  },
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: selectedConfig.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedConfig.description,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.rocket_launch, size: 20),
                  label: const Text(
                    'LAUNCH MISSION',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      inMenu = false;
                    });
                    _resetGame();
                    _playAlertSound();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFF7B2CBF).withValues(alpha: 0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBar(String label, double ratio, String valueText, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white60,
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// Game Objects
class GamePlayer {
  double x = 0;
  double y = 0;
  double width = 40;
  double height = 20;
  double speed = 5;
  int hp = 100;
  int maxHp = 100;
  String shipType = 'fighter';
}

class GameBullet {
  double x;
  double y;
  GameBullet(this.x, this.y);
}

class GameAlien {
  double x;
  double y;
  double width = 30.0;
  double height = 20.0;
  GameAlien(this.x, this.y);
}

enum BossType { octopus, mothership, lasercore, hive }

const Map<BossType, String> kBossNames = {
  BossType.octopus: 'Octo Commander',
  BossType.mothership: 'The Mothership',
  BossType.lasercore: 'The Laser Core',
  BossType.hive: 'The Swarm Hive',
};

class GameBoss {
  final String id;
  final BossType type;
  double x;
  double y;
  double width;
  double height;
  int hp;
  int maxHp;
  double speed;
  double dir; // 1.0 or -1.0
  int gen; // for hive splits (0, 1, 2)
  String phase; // for lasercore: 'move', 'charging', 'firing'
  int phaseT;
  int spawnT;
  double wobbleT;
  Color bodyColor;
  Color highlightColor;
  Color tentacleColor;

  GameBoss({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.hp,
    required this.maxHp,
    required this.speed,
    this.dir = 1.0,
    this.gen = 0,
    this.phase = 'move',
    this.phaseT = 150,
    this.spawnT = 170,
    this.wobbleT = 0.0,
    required this.bodyColor,
    required this.highlightColor,
    required this.tentacleColor,
  });
}

class GameSpawnling {
  double x;
  double y;
  double width;
  double height;
  double vx;
  double vy;
  GameSpawnling({
    required this.x,
    required this.y,
    this.width = 18.0,
    this.height = 16.0,
    this.vx = 0.0,
    this.vy = 2.2,
  });
}

class GameInkShot {
  double x;
  double y;
  double r;
  double vx;
  double vy;
  double wobbleT;
  GameInkShot({
    required this.x,
    required this.y,
    this.r = 8.0,
    this.vx = 0.0,
    this.vy = 2.1,
    this.wobbleT = 0.0,
  });
}

class GameParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  Color color;
  GameParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
  });
}

class GamePowerUp {
  double x;
  double y;
  double width = 16.0;
  double height = 16.0;
  GamePowerUp(this.x, this.y);
}

class GameCoin {
  double x;
  double y;
  double radius = 7.0;
  GameCoin(this.x, this.y);
}

class GameScorePopup {
  double x;
  double y;
  String text;
  double life;
  Color color;
  GameScorePopup({
    required this.x,
    required this.y,
    required this.text,
    required this.life,
    required this.color,
  });
}

class GameStar {
  double x;
  double y;
  double speed;
  double radius;
  Color color;
  GameStar({required this.x, required this.y, required this.speed, required this.radius, required this.color});
}

class GamePlanet {
  double x;
  double y;
  double radius;
  double speed;
  Color color1;
  Color color2;
  bool hasRings;
  GamePlanet({required this.x, required this.y, required this.radius, required this.speed, required this.color1, required this.color2, this.hasRings = false});
}

// Canvas Painter
class GamePainter extends CustomPainter {
  final GamePlayer player;
  final List<GameBullet> bullets;
  final List<GameAlien> aliens;
  final List<GameBoss> bosses;
  final List<GameSpawnling> spawnlings;
  final List<GameInkShot> inkShots;
  final List<GameParticle> particles;
  final List<GamePowerUp> powerUps;
  final List<GameCoin> coins;
  final List<GameScorePopup> scorePopups;
  final List<GameStar> stars;
  final List<GamePlanet> planets;

  final int score;
  final int comboCount;
  final int comboTimerFrames;
  final int comboWindowFrames;
  final int multiplier;
  final int scoreFlashFrames;
  final int bulletsShot;
  final int hits;
  final int coinsCollected;
  final int waveNumber;
  final int weaponLevel;

  final double shakeIntensity;
  final double flashOpacity;
  final double logicalHeight;
  final bool gameOver;
  final int highScore;

  final math.Random _random = math.Random();

  GamePainter({
    required this.player,
    required this.bullets,
    required this.aliens,
    required this.bosses,
    required this.spawnlings,
    required this.inkShots,
    required this.particles,
    required this.powerUps,
    required this.coins,
    required this.scorePopups,
    required this.stars,
    required this.planets,
    required this.score,
    required this.comboCount,
    required this.comboTimerFrames,
    required this.comboWindowFrames,
    required this.multiplier,
    required this.scoreFlashFrames,
    required this.bulletsShot,
    required this.hits,
    required this.coinsCollected,
    required this.waveNumber,
    required this.weaponLevel,
    required this.shakeIntensity,
    required this.flashOpacity,
    required this.logicalHeight,
    required this.gameOver,
    required this.highScore,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Rescale coordinates to fit the actual screen dimensions
    final double scaleX = size.width / 800.0;
    final double scaleY = size.height / logicalHeight;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    // Apply Screen Shake if active
    if (shakeIntensity > 0.0) {
      final double dx = (_random.nextDouble() - 0.5) * shakeIntensity * 4.0;
      final double dy = (_random.nextDouble() - 0.5) * shakeIntensity * 4.0;
      canvas.translate(dx, dy);
    }

    // 2. Draw Background (Stars and Planets)
    for (final star in stars) {
      final paint = Paint()
        ..color = star.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(star.x, star.y), star.radius, paint);
    }
    
    for (final planet in planets) {
      if (planet.hasRings) {
        final ringPaint = Paint()
          ..color = planet.color1.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0;
        canvas.drawOval(Rect.fromCenter(center: Offset(planet.x, planet.y), width: planet.radius * 3.5, height: planet.radius * 0.8), ringPaint);
      }
      
      final planetPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(planet.x - planet.radius * 0.3, planet.y - planet.radius * 0.3),
          planet.radius * 1.5,
          [planet.color1, planet.color2],
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(planet.x, planet.y), planet.radius, planetPaint);
    }

    // 3. Draw Player Ship (Custom vector art per ship type)
    final double px = player.x;
    final double py = player.y;
    final double pw = player.width;
    final double ph = player.height;
    
    final flameFlicker = _random.nextDouble() * 5.0;

    if (player.shipType == 'cruiser') {
      // DREADNOUGHT CRUISER (Heavy armor, dual heavy thrusters, orange glowing core)
      final flamePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(px + pw / 2, py + ph),
          Offset(px + pw / 2, py + ph + 12 + flameFlicker),
          [Colors.orangeAccent, Colors.red.withValues(alpha: 0.0)],
        );
      // Dual engines
      canvas.drawPath(
        Path()
          ..moveTo(px + pw * 0.22, py + ph - 2)
          ..lineTo(px + pw * 0.32, py + ph + 10 + flameFlicker)
          ..lineTo(px + pw * 0.42, py + ph - 2)
          ..close(),
        flamePaint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(px + pw * 0.58, py + ph - 2)
          ..lineTo(px + pw * 0.68, py + ph + 10 + flameFlicker)
          ..lineTo(px + pw * 0.78, py + ph - 2)
          ..close(),
        flamePaint,
      );

      final hullPaint = Paint()..color = const Color(0xFF4A4E69);
      final armorPaint = Paint()..color = const Color(0xFF22223B);
      final accentPaint = Paint()..color = const Color(0xFFFF8800);
      final corePaint = Paint()..color = const Color(0xFFFFCC00);

      // Heavy armor hull
      final hullPath = Path()
        ..moveTo(px + pw / 2, py)
        ..lineTo(px + pw * 0.85, py + ph * 0.4)
        ..lineTo(px + pw, py + ph)
        ..lineTo(px + pw * 0.65, py + ph)
        ..lineTo(px + pw / 2, py + ph * 0.8)
        ..lineTo(px + pw * 0.35, py + ph)
        ..lineTo(px, py + ph)
        ..lineTo(px + pw * 0.15, py + ph * 0.4)
        ..close();
      canvas.drawPath(hullPath, hullPaint);

      // Side armor plates
      canvas.drawRect(Rect.fromLTWH(px + pw * 0.05, py + ph * 0.2, 4, ph * 0.7), accentPaint);
      canvas.drawRect(Rect.fromLTWH(px + pw * 0.95 - 4, py + ph * 0.2, 4, ph * 0.7), accentPaint);

      // Heavy Dual Cannons
      canvas.drawRect(Rect.fromLTWH(px + pw * 0.16, py - 4, 4, 10), armorPaint);
      canvas.drawRect(Rect.fromLTWH(px + pw * 0.84 - 4, py - 4, 4, 10), armorPaint);

      // Core Reactor
      canvas.drawCircle(Offset(px + pw / 2, py + ph * 0.48), 5.0, corePaint);

    } else if (player.shipType == 'interceptor') {
      // PHANTOM INTERCEPTOR (Forward swept delta wings, emerald glow, needle canopy)
      final flamePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(px + pw / 2, py + ph),
          Offset(px + pw / 2, py + ph + 14 + flameFlicker),
          [const Color(0xFF00FF88), Colors.transparent],
        );
      final flamePath = Path()
        ..moveTo(px + pw * 0.38, py + ph - 2)
        ..lineTo(px + pw / 2, py + ph + 14 + flameFlicker)
        ..lineTo(px + pw * 0.62, py + ph - 2)
        ..close();
      canvas.drawPath(flamePath, flamePaint);

      final bodyPaint = Paint()..color = const Color(0xFF1E293B);
      final wingPaint = Paint()..color = const Color(0xFF334155);
      final accentPaint = Paint()..color = const Color(0xFF00FF88);
      final canopyPaint = Paint()..color = const Color(0xFF00FFFF);

      // Forward-swept wings
      final wingPath = Path()
        ..moveTo(px + pw / 2, py + ph * 0.45)
        ..lineTo(px, py + ph * 0.15) // Swept forward!
        ..lineTo(px + pw * 0.18, py + ph)
        ..lineTo(px + pw * 0.82, py + ph)
        ..lineTo(px + pw, py + ph * 0.15)
        ..close();
      canvas.drawPath(wingPath, wingPaint);

      // Wing glow streaks
      canvas.drawLine(
        Offset(px, py + ph * 0.15),
        Offset(px + pw * 0.18, py + ph),
        Paint()..color = accentPaint.color..strokeWidth = 2.0,
      );
      canvas.drawLine(
        Offset(px + pw, py + ph * 0.15),
        Offset(px + pw * 0.82, py + ph),
        Paint()..color = accentPaint.color..strokeWidth = 2.0,
      );

      // Needle fuselage
      final fusePath = Path()
        ..moveTo(px + pw / 2, py - 4)
        ..lineTo(px + pw * 0.35, py + ph)
        ..lineTo(px + pw * 0.65, py + ph)
        ..close();
      canvas.drawPath(fusePath, bodyPaint);

      // Cockpit
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(px + pw / 2, py + ph * 0.4),
          width: 5,
          height: 12,
        ),
        canopyPaint,
      );

    } else {
      // F-22 STARFIGHTER (Standard Balanced Jet)
      final flamePaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(px + pw / 2, py + ph),
          Offset(px + pw / 2, py + ph + 10 + flameFlicker),
          [Colors.yellow, Colors.red.withValues(alpha: 0.0)],
        );
      final flamePath = Path()
        ..moveTo(px + pw * 0.35, py + ph - 2)
        ..lineTo(px + pw / 2, py + ph + 10 + flameFlicker)
        ..lineTo(px + pw * 0.65, py + ph - 2)
        ..close();
      canvas.drawPath(flamePath, flamePaint);

      final bodyPaint = Paint()..color = const Color(0xFFC0C0C0);
      final wingPaint = Paint()..color = const Color(0xFF909090);
      final accentPaint = Paint()..color = const Color(0xFFFF3333);
      final glassPaint = Paint()..color = const Color(0xFF33CCFF);

      // Wings
      final wingPath = Path()
        ..moveTo(px + pw / 2, py + ph * 0.3)
        ..lineTo(px, py + ph * 0.8)
        ..lineTo(px + pw * 0.2, py + ph)
        ..lineTo(px + pw * 0.8, py + ph)
        ..lineTo(px + pw, py + ph * 0.8)
        ..close();
      canvas.drawPath(wingPath, wingPaint);
      
      // Wing accents
      canvas.drawPath(Path()..moveTo(px, py + ph * 0.8)..lineTo(px + pw * 0.1, py + ph * 0.8)..lineTo(px + pw * 0.2, py + ph)..lineTo(px + pw * 0.05, py + ph)..close(), accentPaint);
      canvas.drawPath(Path()..moveTo(px + pw, py + ph * 0.8)..lineTo(px + pw * 0.9, py + ph * 0.8)..lineTo(px + pw * 0.8, py + ph)..lineTo(px + pw * 0.95, py + ph)..close(), accentPaint);

      // Main fuselage
      final fuselagePath = Path()
        ..moveTo(px + pw / 2, py)
        ..lineTo(px + pw * 0.35, py + ph)
        ..lineTo(px + pw * 0.65, py + ph)
        ..close();
      canvas.drawPath(fuselagePath, bodyPaint);

      // Cockpit
      final cockpitPath = Path()
        ..moveTo(px + pw / 2, py + ph * 0.2)
        ..lineTo(px + pw * 0.42, py + ph * 0.5)
        ..lineTo(px + pw * 0.58, py + ph * 0.5)
        ..close();
      canvas.drawPath(cockpitPath, glassPaint);
    }

    // Ship Health Bar (Beneath ship)
    final double hpRatio = (player.hp / player.maxHp).clamp(0.0, 1.0);
    final hpColor = hpRatio > 0.5
        ? const Color(0xFF00FF88)
        : (hpRatio > 0.25 ? const Color(0xFFFFCC00) : const Color(0xFFFF3333));
    
    final hpBgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final hpFillPaint = Paint()
      ..color = hpColor
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py + ph + 16, pw, 3.5),
        const Radius.circular(2),
      ),
      hpBgPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px, py + ph + 16, pw * hpRatio, 3.5),
        const Radius.circular(2),
      ),
      hpFillPaint,
    );

    // 4. Draw Bullets (Red Rectangles)
    final bulletPaint = Paint()
      ..color = const Color(0xFFFF4040)
      ..style = PaintingStyle.fill;
    for (final bullet in bullets) {
      canvas.drawRect(
        Rect.fromLTWH(bullet.x, bullet.y, 4.0, 10.0),
        bulletPaint,
      );
    }

    // 5. Draw Powerups (Cyan boxes with black crosses)
    final powerUpPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;
    final crossPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    for (final p in powerUps) {
      canvas.drawRect(Rect.fromLTWH(p.x, p.y, 16.0, 16.0), powerUpPaint);
      canvas.drawRect(Rect.fromLTWH(p.x + 6, p.y + 3, 4.0, 10.0), crossPaint);
      canvas.drawRect(Rect.fromLTWH(p.x + 3, p.y + 6, 10.0, 4.0), crossPaint);
    }

    // 6. Draw Coins (Gold Circles with dark borders)
    final coinPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.fill;
    final coinBorderPaint = Paint()
      ..color = const Color(0xFF7A5A00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final c in coins) {
      canvas.drawCircle(Offset(c.x, c.y), 7.0, coinPaint);
      canvas.drawCircle(Offset(c.x, c.y), 6.0, coinBorderPaint);
    }

    // 7. Draw Bosses, Spawnlings, and Ink Shots
    _drawBosses(canvas);

    // 8. Draw Aliens (Sleek UFO design)
    for (final alien in aliens) {
      final double cx = alien.x + alien.width / 2;
      final double cy = alien.y + alien.height / 2;
      
      // UFO glass dome
      final domePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(cx, cy - 2),
          alien.width / 2.5,
          [const Color(0xFF00FFFF), const Color(0xFF006666)],
        )
        ..style = PaintingStyle.fill;
      final domePath = Path();
      domePath.addArc(
        Rect.fromCenter(center: Offset(cx, alien.y + alien.height * 0.4), width: alien.width * 0.6, height: alien.height * 0.8),
        math.pi,
        math.pi,
      );
      canvas.drawPath(domePath, domePaint);

      // UFO saucer body
      final saucerPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(alien.x, cy),
          Offset(alien.x + alien.width, cy),
          [const Color(0xFF666666), const Color(0xFF333333)],
        )
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, alien.y + alien.height * 0.6), width: alien.width, height: alien.height * 0.5),
        saucerPaint,
      );

      // UFO lights
      final lightPaint = Paint()..color = (DateTime.now().millisecondsSinceEpoch ~/ 300 % 2 == 0) ? Colors.yellow : Colors.red;
      canvas.drawCircle(Offset(cx - alien.width * 0.35, alien.y + alien.height * 0.6), 1.5, lightPaint);
      canvas.drawCircle(Offset(cx + alien.width * 0.35, alien.y + alien.height * 0.6), 1.5, lightPaint);
      canvas.drawCircle(Offset(cx, alien.y + alien.height * 0.7), 1.5, lightPaint);
    }

    // 9. Draw Exploding Particles
    for (final p in particles) {
      final particlePaint = Paint()
        ..color = p.color.withValues(
          alpha: ((p.life / 30.0).clamp(0.0, 1.0)).toDouble(),
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), 2.0, particlePaint);
    }

    // 10. Draw Floating Popups
    for (final popup in scorePopups) {
      final double alpha = (popup.life / 32.0).clamp(0.0, 1.0);
      _drawText(
        canvas: canvas,
        text: popup.text,
        x: popup.x,
        y: popup.y,
        color: popup.color.withValues(alpha: alpha),
        fontSize: 14.0,
        bold: true,
        centered: true,
      );
    }

    // 11. Draw HUD / Stats
    _drawStatsHUD(canvas);

    // 12. Draw Full Screen Flash effect
    if (flashOpacity > 0.0) {
      final flashPaint = Paint()
        ..color = Colors.white.withValues(alpha: flashOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(0, 0, 800.0, logicalHeight), flashPaint);
    }

    canvas.restore();
  }

  void _drawStatsHUD(Canvas canvas) {
    // Pulsing Score
    final double pulseScale = 1.0 + (scoreFlashFrames * 0.012);
    final double scoreX = 800.0 - 12.0;
    const double scoreY = 16.0;

    _drawText(
      canvas: canvas,
      text: 'Score $score',
      x: scoreX,
      y: scoreY,
      color: const Color(0xFFFFE066),
      fontSize: 26.0 * pulseScale,
      bold: true,
      alignRight: true,
      glowing: true,
    );

    // Combo multiplier text
    if (comboCount >= 2 && comboTimerFrames > 0) {
      final double comboAlpha = (comboTimerFrames / comboWindowFrames).clamp(
        0.0,
        1.0,
      );
      _drawText(
        canvas: canvas,
        text: 'COMBO x$multiplier ($comboCount)',
        x: scoreX,
        y: scoreY + 34.0,
        color: const Color(0xFF00F2FE).withValues(alpha: comboAlpha),
        fontSize: 15.0,
        bold: true,
        alignRight: true,
        glowing: true,
      );
    }

    // Left HUD items
    const double startX = 12.0;
    final double hitRate = bulletsShot > 0 ? (hits / bulletsShot) * 100.0 : 0.0;
    final double hpRatio = (player.hp / player.maxHp).clamp(0.0, 1.0);
    final Color hpColor = hpRatio > 0.5
        ? const Color(0xFF00FF88)
        : (hpRatio > 0.25 ? const Color(0xFFFFCC00) : const Color(0xFFFF3333));

    _drawText(
      canvas: canvas,
      text: 'Hull: ${player.hp}/${player.maxHp} HP',
      x: startX,
      y: 16.0,
      color: hpColor,
      fontSize: 15.0,
      bold: true,
    );
    _drawText(
      canvas: canvas,
      text: 'Hit Rate: ${hitRate.toStringAsFixed(1)}%',
      x: startX,
      y: 36.0,
      color: Colors.white,
      fontSize: 14.0,
    );
    _drawText(
      canvas: canvas,
      text: 'Shots: $bulletsShot',
      x: startX,
      y: 56.0,
      color: Colors.white,
      fontSize: 14.0,
    );
    _drawText(
      canvas: canvas,
      text: 'Hits: $hits',
      x: startX,
      y: 76.0,
      color: Colors.white,
      fontSize: 14.0,
    );
    _drawText(
      canvas: canvas,
      text: 'Coins: $coinsCollected',
      x: startX,
      y: 96.0,
      color: Colors.white,
      fontSize: 14.0,
    );

    final bool hasBoss = bosses.isNotEmpty;
    if (hasBoss) {
      final int bossTotalHp = bosses.fold(0, (sum, b) => sum + b.hp);
      final String bossLabel = '${kBossNames[bosses.first.type] ?? "Boss"}${bosses.length > 1 ? " x${bosses.length}" : ""}';
      _drawText(
        canvas: canvas,
        text: '$bossLabel: $bossTotalHp HP',
        x: startX,
        y: 116.0,
        color: const Color(0xFFFF5252),
        fontSize: 14.0,
        bold: true,
        glowing: true,
      );
    }

    final String weaponStatus = weaponLevel == 1
        ? 'Single Shot'
        : weaponLevel == 2
        ? 'Dual Missile'
        : 'Triple Shot';

    _drawText(
      canvas: canvas,
      text: 'Weapon: $weaponStatus',
      x: startX,
      y: hasBoss ? 136.0 : 116.0,
      color: const Color(0xFF9BE7FF),
      fontSize: 14.0,
    );

    _drawText(
      canvas: canvas,
      text: 'Wave: $waveNumber',
      x: 800.0 - 100.0,
      y: hasBoss ? 150.0 : 130.0,
      color: Colors.white70,
      fontSize: 14.0,
    );
  }

  void _drawBosses(Canvas canvas) {
    for (final boss in bosses) {
      if (boss.type == BossType.mothership) {
        _drawMothership(canvas, boss);
      } else if (boss.type == BossType.lasercore) {
        _drawLaserCore(canvas, boss);
      } else if (boss.type == BossType.hive) {
        _drawHive(canvas, boss);
      } else {
        _drawOctopus(canvas, boss);
      }

      if (bosses.length > 1) {
        _drawBossHpBar(canvas, boss);
      }
    }

    _drawSpawnlings(canvas);
    _drawInkShots(canvas);
  }

  void _drawBossHpBar(Canvas canvas, GameBoss boss) {
    final double hpRatio = (boss.hp / boss.maxHp).clamp(0.0, 1.0);
    final hpBgPaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(boss.x, boss.y - 8, boss.width, 4), hpBgPaint);

    final hpFillPaint = Paint()
      ..color = const Color(0xFFFF4040)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(boss.x, boss.y - 8, boss.width * hpRatio, 4),
      hpFillPaint,
    );
  }

  void _drawOctopus(Canvas canvas, GameBoss b) {
    canvas.save();
    final double cx = b.x + b.width / 2;
    final double headRadius = b.width * 0.28;
    final double headCenterY = b.y + b.height * 0.45;

    // Head shape
    final bossBodyPaint = Paint()
      ..color = b.bodyColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final bossBodyPath = Path();
    bossBodyPath.addArc(
      Rect.fromCircle(center: Offset(cx, headCenterY), radius: headRadius),
      math.pi,
      math.pi,
    );
    bossBodyPath.lineTo(b.x + b.width * 0.78, b.y + b.height * 0.72);
    bossBodyPath.quadraticBezierTo(
      cx,
      b.y + b.height * 0.92,
      b.x + b.width * 0.22,
      b.y + b.height * 0.72,
    );
    bossBodyPath.close();
    canvas.drawPath(bossBodyPath, bossBodyPaint);

    // Highlight spot on head
    final highlightPaint = Paint()
      ..color = b.highlightColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(b.x + b.width * 0.42, b.y + b.height * 0.33),
      headRadius * 0.35,
      highlightPaint,
    );

    // Eyes
    final double eyeY = b.y + b.height * 0.52;
    final double leftEyeX = b.x + b.width * 0.42;
    final double rightEyeX = b.x + b.width * 0.58;
    final double eyeRadius = b.width * 0.045;

    final whiteEyePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius, whiteEyePaint);
    canvas.drawCircle(Offset(rightEyeX, eyeY), eyeRadius, whiteEyePaint);

    final darkEyePaint = Paint()
      ..color = const Color(0xFF111111).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(leftEyeX, eyeY), eyeRadius * 0.45, darkEyePaint);
    canvas.drawCircle(
      Offset(rightEyeX, eyeY),
      eyeRadius * 0.45,
      darkEyePaint,
    );

    // Tentacles (bezier lines)
    final tentaclePaint = Paint()
      ..color = b.tentacleColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (b.width * 0.04).clamp(2.0, 10.0);

    final double baseY = b.y + b.height * 0.72;
    for (int i = 0; i < 6; i++) {
      final double t = i / 5.0;
      final double startX = b.x + b.width * (0.2 + t * 0.6);
      final double swing = (i % 2 == 0 ? -1 : 1) * b.width * 0.05;

      final tentaclePath = Path();
      tentaclePath.moveTo(startX, baseY);
      tentaclePath.cubicTo(
        startX + swing,
        baseY + b.height * 0.18,
        startX - swing,
        baseY + b.height * 0.3,
        startX,
        baseY + b.height * 0.42,
      );
      canvas.drawPath(tentaclePath, tentaclePaint);
    }

    if (bosses.length == 1) {
      _drawBossHpBar(canvas, b);
    }
    canvas.restore();
  }

  void _drawMothership(Canvas canvas, GameBoss b) {
    canvas.save();
    final double cx = b.x + b.width / 2;
    final double cy = b.y + b.height * 0.55;
    final double now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Metallic Hull
    final hullPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(b.x, b.y),
        Offset(b.x, b.y + b.height),
        [
          const Color(0xFF8D98AD),
          const Color(0xFF525C70),
          const Color(0xFF2E3442),
        ],
        [0.0, 0.6, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: b.width,
        height: b.height * 0.84,
      ),
      hullPaint,
    );

    // Command dome
    final domePaint = Paint()
      ..color = const Color(0xFF3A4358)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, b.y + b.height * 0.32),
        width: b.width * 0.44,
        height: b.height * 0.6,
      ),
      math.pi,
      math.pi,
      true,
      domePaint,
    );

    final domeGlowPaint = Paint()
      ..color = const Color(0x808CDCFF)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, b.y + b.height * 0.3),
        width: b.width * 0.26,
        height: b.height * 0.32,
      ),
      math.pi,
      math.pi,
      true,
      domeGlowPaint,
    );

    // Chasing rim lights
    const int lightCount = 7;
    for (int i = 0; i < lightCount; i++) {
      final double t = i / (lightCount - 1);
      final double lx = b.x + b.width * (0.12 + t * 0.76);
      final bool on = (now * 4).floor() % lightCount == i;
      final lightPaint = Paint()
        ..color = on ? const Color(0xFFFFE066) : const Color(0x40FFE066)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(lx, cy + b.height * 0.18),
        math.max(1.5, b.width * 0.012),
        lightPaint,
      );
    }

    // Hangar bay glow
    final double charge = (1.0 - b.spawnT / 150.0).clamp(0.0, 1.0);
    final hangarPaint = Paint()
      ..color = Color.fromRGBO(255, 140, 60, (0.2 + 0.6 * charge).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, b.y + b.height * 0.85),
        width: b.width * 0.32,
        height: b.height * 0.36,
      ),
      hangarPaint,
    );

    if (bosses.length == 1) {
      _drawBossHpBar(canvas, b);
    }
    canvas.restore();
  }

  void _drawLaserCore(Canvas canvas, GameBoss b) {
    canvas.save();
    final double cx = b.x + b.width / 2;
    final double cy = b.y + b.height / 2;
    final bool charging = b.phase == 'charging';
    final bool firing = b.phase == 'firing';
    final double chargeProgress = charging ? (1.0 - b.phaseT / 70.0).clamp(0.0, 1.0) : 0.0;
    final double now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    // Telegraph dashed line guide when charging
    if (charging) {
      final double pulse = 0.25 + 0.35 * (0.5 + 0.5 * math.sin(now * 24.0)) * chargeProgress;
      final guidePaint = Paint()
        ..color = Color.fromRGBO(255, 80, 120, pulse.clamp(0.1, 1.0))
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      
      double curY = b.y + b.height;
      while (curY < logicalHeight) {
        canvas.drawLine(
          Offset(cx, curY),
          Offset(cx, math.min(curY + 6.0, logicalHeight)),
          guidePaint,
        );
        curY += 12.0;
      }
    }

    // Lethal beam when firing
    if (firing) {
      final double halfW = b.width * 0.45;
      final double beamLeft = cx - halfW;
      final double beamRight = cx + halfW;
      final double beamTop = b.y + b.height;

      final beamPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(beamLeft, 0),
          Offset(beamRight, 0),
          [
            const Color(0x00FF3C78),
            const Color(0xCCFF3C78),
            const Color(0x00FF3C78),
          ],
          [0.0, 0.5, 1.0],
        )
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(beamLeft, beamTop, beamRight, logicalHeight),
        beamPaint,
      );

      // White-hot core
      final double coreHalf = (beamRight - beamLeft) * 0.16;
      final corePaint = Paint()
        ..color = Color.fromRGBO(255, 235, 245, 0.75 + 0.25 * math.sin(now * 40.0))
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(cx - coreHalf, beamTop, cx + coreHalf, logicalHeight),
        corePaint,
      );
    }

    // Diamond hull
    final diamondPath = Path()
      ..moveTo(cx, b.y)
      ..lineTo(b.x + b.width, cy)
      ..lineTo(cx, b.y + b.height)
      ..lineTo(b.x, cy)
      ..close();

    final hullPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(b.x, b.y),
        Offset(b.x, b.y + b.height),
        [
          const Color(0xFFE8ECF7),
          const Color(0xFF7B87A8),
          const Color(0xFF39415A),
        ],
        [0.0, 0.5, 1.0],
      )
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, hullPaint);

    final borderPaint = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(diamondPath, borderPaint);

    // Glowing core
    final double coreR = b.width * (0.1 + 0.08 * chargeProgress + (firing ? 0.1 : 0.0));
    final double coreAlpha = firing ? 1.0 : (0.45 + 0.55 * chargeProgress);
    final corePaint = Paint()
      ..color = Color.fromRGBO(255, 60, 120, coreAlpha.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), coreR, corePaint);

    final coreCenterPaint = Paint()
      ..color = const Color(0xE6FFE6F0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), coreR * 0.45, coreCenterPaint);

    if (bosses.length == 1) {
      _drawBossHpBar(canvas, b);
    }
    canvas.restore();
  }

  void _drawHive(Canvas canvas, GameBoss b) {
    canvas.save();
    final double cx = b.x + b.width / 2;
    final double cy = b.y + b.height / 2;
    final double rx = b.width / 2;
    final double ry = b.height / 2;
    final double hue = (110.0 - b.gen * 18.0).clamp(0.0, 360.0);

    // Wobbly perimeter polygon
    final blobPath = Path();
    const int segs = 14;
    for (int i = 0; i <= segs; i++) {
      final double a = (i / segs) * math.pi * 2;
      final double wob = 1.0 + 0.12 * math.sin(b.wobbleT + i * 2.1);
      final double px = cx + math.cos(a) * rx * wob;
      final double py = cy + math.sin(a) * ry * wob;
      if (i == 0) {
        blobPath.moveTo(px, py);
      } else {
        blobPath.lineTo(px, py);
      }
    }
    blobPath.close();

    final blobPaint = Paint()
      ..color = HSVColor.fromAHSV(0.92, hue, 0.65, 0.32).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawPath(blobPath, blobPaint);

    // Inner membrane & nucleus
    final innerPaint = Paint()
      ..color = HSVColor.fromAHSV(0.7, hue, 0.70, 0.45).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: rx * 1.24, height: ry * 1.24),
      innerPaint,
    );

    final nucleusPaint = Paint()
      ..color = HSVColor.fromAHSV(0.9, (hue + 30.0) % 360.0, 0.80, 0.62).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          cx + math.sin(b.wobbleT * 0.7) * rx * 0.1,
          cy + math.cos(b.wobbleT * 0.9) * ry * 0.1,
        ),
        width: rx * 0.56,
        height: ry * 0.6,
      ),
      nucleusPaint,
    );

    // Drifting bubbles in goo
    for (int i = 0; i < 3; i++) {
      final double bx = cx + math.sin(b.wobbleT * 1.3 + i * 2.4) * rx * 0.4;
      final double by = cy + math.cos(b.wobbleT * 1.1 + i * 1.9) * ry * 0.4;
      final bubblePaint = Paint()
        ..color = HSVColor.fromAHSV(0.5, (hue + 40.0) % 360.0, 0.80, 0.70).toColor()
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(bx, by), math.max(1.5, rx * 0.08), bubblePaint);
    }

    // Angry eyes
    final eyePaint = Paint()
      ..color = const Color(0xFF1A0F1E)
      ..style = PaintingStyle.fill;
    final double eyeR = math.max(1.5, rx * 0.09);
    canvas.drawCircle(Offset(cx - rx * 0.28, cy - ry * 0.12), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx + rx * 0.28, cy - ry * 0.12), eyeR, eyePaint);

    if (bosses.length == 1) {
      _drawBossHpBar(canvas, b);
    }
    canvas.restore();
  }

  void _drawSpawnlings(Canvas canvas) {
    for (final k in spawnlings) {
      final double cx = k.x + k.width / 2;

      // Exhaust flame
      final flamePaint = Paint()
        ..color = _random.nextBool() ? Colors.orange : const Color(0xFFFF5D5D)
        ..style = PaintingStyle.fill;
      final flamePath = Path()
        ..moveTo(cx - k.width * 0.12, k.y)
        ..lineTo(cx, k.y - _random.nextDouble() * k.height * 0.7 - 2.0)
        ..lineTo(cx + k.width * 0.12, k.y)
        ..close();
      canvas.drawPath(flamePath, flamePaint);

      // Downward dagger hull
      final daggerPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(k.x, k.y),
          Offset(k.x, k.y + k.height),
          [const Color(0xFFB8642E), const Color(0xFFFFB46B)],
        )
        ..style = PaintingStyle.fill;
      final daggerPath = Path()
        ..moveTo(cx, k.y + k.height)
        ..lineTo(k.x + k.width, k.y + k.height * 0.25)
        ..lineTo(cx, k.y + k.height * 0.45)
        ..lineTo(k.x, k.y + k.height * 0.25)
        ..close();
      canvas.drawPath(daggerPath, daggerPaint);
    }
  }

  void _drawInkShots(Canvas canvas) {
    for (final ink in inkShots) {
      final double squish = 1.0 + 0.15 * math.sin(ink.wobbleT * 2.0);

      // Halo
      final haloPaint = Paint()
        ..color = const Color(0x999664DC)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ink.x, ink.y),
          width: ink.r * 3.0 * squish,
          height: (ink.r * 3.0) / squish,
        ),
        haloPaint,
      );

      // Core
      final corePaint = Paint()
        ..color = const Color(0xFF9A6DDB)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(ink.x, ink.y),
          width: ink.r * 2.0 * squish,
          height: (ink.r * 2.0) / squish,
        ),
        corePaint,
      );

      // Sheen
      final sheenPaint = Paint()
        ..color = const Color(0xE6F0DCFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(ink.x - ink.r * 0.3, ink.y - ink.r * 0.3),
        math.max(1.0, ink.r * 0.3),
        sheenPaint,
      );
    }
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required double x,
    required double y,
    required Color color,
    required double fontSize,
    bool bold = false,
    bool centered = false,
    bool alignRight = false,
    bool glowing = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'monospace',
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        shadows: glowing
            ? [
                Shadow(color: color.withValues(alpha: 0.6), blurRadius: 10),
                const Shadow(
                  color: Colors.black,
                  offset: Offset(2.0, 2.0),
                  blurRadius: 4,
                ),
              ]
            : [
                const Shadow(
                  color: Colors.black,
                  offset: Offset(1.5, 1.5),
                  blurRadius: 3,
                ),
              ],
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    double startX = x;
    if (centered) {
      startX = x - textPainter.width / 2;
    } else if (alignRight) {
      startX = x - textPainter.width;
    }

    textPainter.paint(canvas, Offset(startX, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
