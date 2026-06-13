import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:localstorage/localstorage.dart';

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

  // Visual effects
  double shakeIntensity = 0.0;
  double flashOpacity = 0.0;

  // Time accumulator for fixed 60FPS game loop
  double _lag = 0.0;
  Duration _lastTime = Duration.zero;

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

  void _resetGame() {
    player = GamePlayer()
      ..width = 40
      ..height = 20
      ..speed = 5
      ..x = logicalWidth / 2 - 20;

    bullets.clear();
    aliens.clear();
    boss = null;
    particles.clear();
    powerUps.clear();
    coins.clear();
    scorePopups.clear();

    score = 0;
    bulletsShot = 0;
    hits = 0;
    coinsCollected = 0;
    weaponLevel = 1;
    waveNumber = 1;
    comboCount = 0;
    comboTimerFrames = 0;
    gameOver = false;
    canShoot = true;
    alienDirection = 1;
    shakeIntensity = 0.0;
    flashOpacity = 0.0;
    _lag = 0.0;
    _lastTime = Duration.zero;

    _adjustPlayerY();
    _createAliens();
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
      if (!gameOver) {
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

  void _updateGame() {
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
    if (spacePressed && canShoot) {
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
    final currentHeight = _logicalHeight;

    for (final alien in aliens) {
      alien.x += alienSpeed * alienDirection;
      if (alien.x + alien.width > logicalWidth || alien.x < 0) {
        hitEdge = true;
      }
      if (alien.y + alien.height > currentHeight - player.height - 20) {
        _endGame();
      }
    }

    if (boss != null) {
      boss!.x += alienSpeed * 0.7 * alienDirection;
      if (boss!.x + boss!.width > logicalWidth || boss!.x < 0) {
        hitEdge = true;
      }
      if (boss!.y + boss!.height > currentHeight - player.height - 20) {
        _endGame();
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
          b.hp--;
          bullets.removeAt(bIndex);
          hits++;
          HapticFeedback.mediumImpact();
          _addScore(5, bullet.x, bullet.y, const Color(0xFF9BE7FF));

          if (b.hp <= 0) {
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
                  ElevatedButton(
                    onPressed: _resetGame,
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
                        if (gameOver) return;
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

                          // Game instructions or Game Over modal overlay
                          if (gameOver)
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
                                  const SizedBox(height: 32),
                                  ElevatedButton(
                                    onPressed: _resetGame,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7B2CBF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'PLAY AGAIN',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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

                      // Fire Button
                      _buildTouchButton(
                        icon: Icons.gps_fixed,
                        color: Colors.redAccent.withValues(alpha: 0.4),
                        onDown: () {
                          if (!gameOver && canShoot) {
                            _shootBullet();
                          }
                        },
                        onUp: () {},
                      ),
                    ],
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Controls: Left/Right Arrows or Mouse Hover to Move | Spacebar or Click to Shoot',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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
}

// Game Objects
class GamePlayer {
  double x = 0;
  double y = 0;
  double width = 40;
  double height = 20;
  double speed = 5;
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

    // 2. Draw Stars (ambient background)
    final starsPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(100, 80), 1.0, starsPaint);
    canvas.drawCircle(const Offset(350, 150), 1.5, starsPaint);
    canvas.drawCircle(const Offset(650, 200), 1.0, starsPaint);
    canvas.drawCircle(const Offset(200, 450), 2.0, starsPaint);
    canvas.drawCircle(const Offset(500, 520), 1.0, starsPaint);
    canvas.drawCircle(const Offset(700, 380), 1.5, starsPaint);
    canvas.drawCircle(const Offset(150, 280), 1.0, starsPaint);
    canvas.drawCircle(const Offset(600, 80), 2.0, starsPaint);
    canvas.drawCircle(const Offset(400, 350), 1.0, starsPaint);

    // 3. Draw Player Jet (White vector path)
    final playerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final playerPath = Path()
      ..moveTo(player.x + player.width / 2, player.y)
      ..lineTo(player.x, player.y + player.height)
      ..lineTo(player.x + player.width * 0.3, player.y + player.height / 2)
      ..lineTo(player.x + player.width * 0.7, player.y + player.height / 2)
      ..lineTo(player.x + player.width, player.y + player.height)
      ..close();
    canvas.drawPath(playerPath, playerPaint);

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

    // 8. Draw Aliens (Space Invader vector style)
    final alienPaint = Paint()
      ..color = const Color(0xFF00FF55)
      ..style = PaintingStyle.fill;
    for (final alien in aliens) {
      final path = Path();
      final double cx = alien.x + alien.width / 2;
      final double cy = alien.y + alien.height / 3;
      final double r = alien.width / 4;
      path.addArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        math.pi,
        math.pi,
      );

      path.moveTo(alien.x, alien.y + alien.height);
      path.lineTo(alien.x + alien.width / 4, alien.y + alien.height / 3);
      path.lineTo(alien.x + (alien.width * 3) / 4, alien.y + alien.height / 3);
      path.lineTo(alien.x + alien.width, alien.y + alien.height);
      path.close();
      canvas.drawPath(path, alienPaint);
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

    _drawText(
      canvas: canvas,
      text: 'Hit Rate: ${hitRate.toStringAsFixed(1)}%',
      x: startX,
      y: 16.0,
      color: Colors.white,
      fontSize: 15.0,
    );
    _drawText(
      canvas: canvas,
      text: 'Shots: $bulletsShot',
      x: startX,
      y: 36.0,
      color: Colors.white,
      fontSize: 14.0,
    );
    _drawText(
      canvas: canvas,
      text: 'Hits: $hits',
      x: startX,
      y: 56.0,
      color: Colors.white,
      fontSize: 14.0,
    );
    _drawText(
      canvas: canvas,
      text: 'Coins: $coinsCollected',
      x: startX,
      y: 76.0,
      color: Colors.white,
      fontSize: 14.0,
    );

    if (boss != null) {
      _drawText(
        canvas: canvas,
        text: 'Boss HP: ${boss!.hp}',
        x: startX,
        y: 96.0,
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
      y: boss != null ? 116.0 : 96.0,
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
