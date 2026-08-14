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
  static const int bossMaxHp = 12;
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
  GameBoss? boss;
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
    boss = null;
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
    const double bossWidth = 90.0;
    final int bossHue = _random.nextInt(360);

    boss = GameBoss(
      x: logicalWidth / 2 - bossWidth / 2,
      y: 8.0,
      hp: bossMaxHp,
      maxHp: bossMaxHp,
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

    // Update aliens & boss movement
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

    if (boss != null) {
      boss!.x += alienSpeed * 0.7 * alienDirection;
      if (boss!.x + boss!.width > logicalWidth || boss!.x < 0) {
        hitEdge = true;
      }
      if (boss!.y + boss!.height > currentHeight - player.height - 20) {
        _damagePlayer(40);
        boss!.y = 10.0;
      }
    }

    if (hitEdge) {
      alienDirection *= -1;
      for (final alien in aliens) {
        alien.y += 20;
      }
      if (boss != null) {
        boss!.y += 12;
      }
    }

    // Collision detection: Bullets vs Aliens & Boss
    for (int bIndex = bullets.length - 1; bIndex >= 0; bIndex--) {
      if (bIndex >= bullets.length) continue;
      final bullet = bullets[bIndex];
      bool hitAlien = false;

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
          hitAlien = true;
          break;
        }
      }

      if (hitAlien || bIndex >= bullets.length) continue;

      // Bullet vs Boss
      if (boss != null) {
        final b = boss!;
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
            _playAlertSound();
            _createFireworks(b.x + b.width / 2, b.y + b.height / 2);
            _createFireworks(b.x + b.width / 2 + 10, b.y + b.height / 2);
            flashOpacity = 0.6;
            HapticFeedback.vibrate();
            _addScore(
              120,
              b.x + b.width / 2,
              b.y + b.height / 2,
              const Color(0xFF7AF58F),
            );
            boss = null;
          }
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

    // Start next wave if empty
    if (aliens.isEmpty) {
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
                              boss: boss,
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

class GameBoss {
  double x;
  double y;
  double width = 90.0;
  double height = 30.0;
  int hp;
  int maxHp;
  Color bodyColor;
  Color highlightColor;
  Color tentacleColor;
  GameBoss({
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.bodyColor,
    required this.highlightColor,
    required this.tentacleColor,
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
  final GameBoss? boss;
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
    required this.boss,
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

    // 7. Draw Boss (Giant Squid/Octopus)
    if (boss != null) {
      final b = boss!;
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
      canvas.restore();

      // HP Bar above boss
      final double hpRatio = (b.hp / b.maxHp).clamp(0.0, 1.0);
      final hpBgPaint = Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(b.x, b.y - 8, b.width, 4), hpBgPaint);

      final hpFillPaint = Paint()
        ..color = const Color(0xFFFF4040)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(b.x, b.y - 8, b.width * hpRatio, 4),
        hpFillPaint,
      );
    }

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

    if (boss != null) {
      _drawText(
        canvas: canvas,
        text: 'Boss HP: ${boss!.hp}',
        x: startX,
        y: 116.0,
        color: Colors.redAccent,
        fontSize: 14.0,
        bold: true,
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
      y: boss != null ? 136.0 : 116.0,
      color: const Color(0xFF9BE7FF),
      fontSize: 14.0,
    );

    _drawText(
      canvas: canvas,
      text: 'Wave: $waveNumber',
      x: 800.0 - 100.0,
      y: boss != null ? 150.0 : 130.0,
      color: Colors.white70,
      fontSize: 14.0,
    );
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
