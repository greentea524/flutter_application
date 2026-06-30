import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

import '../boxing_model.dart';

const String kBoxingSaveKey = 'boxing_save_v1';
const String kBoxingBestFightKey = 'boxing_best_fight';

/// Returns true if a saved game exists.
bool boxingHasSave() {
  try {
    final String? raw = localStorage.getItem(kBoxingSaveKey);
    return raw != null && raw.isNotEmpty;
  } catch (_) {
    return false;
  }
}

class BoxingScreen extends StatefulWidget {
  const BoxingScreen({super.key});

  @override
  State<BoxingScreen> createState() => _BoxingScreenState();
}

class _BoxingScreenState extends State<BoxingScreen>
    with TickerProviderStateMixin {
  final BoxingGame _game = BoxingGame();

  bool _inMenu = true;
  bool _shopOpen = false;
  bool _hasSave = false;
  Timer? _autoTimer;

  // Animation drivers for the fight stage.
  late final AnimationController _playerPunch;
  late final AnimationController _cpuPunch;
  late final AnimationController _playerHit;
  late final AnimationController _cpuHit;
  bool _playerNextLead = true;
  bool _cpuNextLead = true;
  bool _playerHandLead = true;
  bool _cpuHandLead = true;

  static const Duration _punchDuration = Duration(milliseconds: 300);
  static const Duration _hitDuration = Duration(milliseconds: 160);
  static const Duration _autoTick = Duration(milliseconds: 700);

  @override
  void initState() {
    super.initState();
    _playerPunch = AnimationController(vsync: this, duration: _punchDuration);
    _cpuPunch = AnimationController(vsync: this, duration: _punchDuration);
    _playerHit = AnimationController(vsync: this, duration: _hitDuration);
    _cpuHit = AnimationController(vsync: this, duration: _hitDuration);
    _hasSave = boxingHasSave();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _playerPunch.dispose();
    _cpuPunch.dispose();
    _playerHit.dispose();
    _cpuHit.dispose();
    super.dispose();
  }

  // ---- Persistence ----
  void _save() {
    try {
      localStorage.setItem(kBoxingSaveKey, jsonEncode(_game.toJson()));
      localStorage.setItem(kBoxingBestFightKey, _game.bestFight.toString());
      _hasSave = true;
    } catch (_) {
      // Keep gameplay uninterrupted if storage fails.
    }
  }

  bool _loadSave() {
    try {
      final String? raw = localStorage.getItem(kBoxingSaveKey);
      if (raw == null || raw.isEmpty) {
        return false;
      }
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return false;
      }
      _game.applyJson(Map<String, dynamic>.from(decoded));
      return true;
    } catch (_) {
      try {
        localStorage.removeItem(kBoxingSaveKey);
      } catch (_) {}
      return false;
    }
  }

  // ---- Animation triggers ----
  void _triggerPunch(String side) {
    if (side == 'player') {
      _playerHandLead = _playerNextLead;
      _playerNextLead = !_playerNextLead;
      _playerPunch.forward(from: 0);
    } else {
      _cpuHandLead = _cpuNextLead;
      _cpuNextLead = !_cpuNextLead;
      _cpuPunch.forward(from: 0);
    }
  }

  void _triggerHit(String side) {
    (side == 'player' ? _playerHit : _cpuHit).forward(from: 0);
  }

  // ---- Game flow ----
  void _startNewGame() {
    _autoTimer?.cancel();
    try {
      localStorage.removeItem(kBoxingSaveKey);
    } catch (_) {}
    _game.resetProgress();
    _game.startRound(advance: false);
    setState(() {
      _inMenu = false;
      _shopOpen = false;
    });
    _save();
  }

  void _loadGame() {
    _autoTimer?.cancel();
    if (!_loadSave()) {
      setState(() => _hasSave = boxingHasSave());
      return;
    }
    _game.addLog('Loaded saved progression.');
    setState(() {
      _inMenu = false;
      _shopOpen = false;
    });
    if (_game.autoFightEnabled && !_game.isGameOver) {
      _startAutoLoop();
    }
  }

  void _returnToMenu() {
    _autoTimer?.cancel();
    setState(() {
      _inMenu = true;
      _hasSave = boxingHasSave();
    });
  }

  void _doPlayerPunch() {
    if (_game.isGameOver) {
      return;
    }
    _triggerPunch('player');
    final PunchOutcome outcome = _game.playerPunch();
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) _triggerHit('cpu');
    });
    if (!outcome.cpuDefeated && !outcome.playerDefeated) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _triggerPunch('cpu');
      });
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _triggerHit('player');
      });
    } else if (outcome.playerDefeated) {
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) _triggerPunch('cpu');
      });
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) _triggerHit('player');
      });
    }
    if (_game.isGameOver) {
      _autoTimer?.cancel();
    }
    setState(() {});
    _save();
  }

  void _nextRound() {
    _autoTimer?.cancel();
    _game.startRound(advance: true);
    setState(() => _shopOpen = false);
    if (_game.autoFightEnabled) {
      _startAutoLoop();
    }
    _save();
  }

  void _startAutoLoop() {
    _autoTimer?.cancel();
    if (!_game.autoFightEnabled || _game.isGameOver) {
      return;
    }
    _autoTimer = Timer.periodic(_autoTick, (_) {
      if (_game.isGameOver) {
        _autoTimer?.cancel();
        return;
      }
      _doPlayerPunch();
    });
  }

  void _toggleAuto() {
    _game.autoFightEnabled = !_game.autoFightEnabled;
    if (_game.autoFightEnabled) {
      if (_game.isGameOver) {
        _game.statusText = 'Auto enabled. Press Next to continue.';
      } else {
        _game.statusText = 'Auto fight running...';
        _startAutoLoop();
      }
    } else {
      _autoTimer?.cancel();
      if (!_game.isGameOver) {
        _game.statusText = 'Auto fight stopped. Throw a punch!';
      }
    }
    setState(() {});
    _save();
  }

  void _toggleShop() {
    setState(() => _shopOpen = !_shopOpen);
  }

  void _shopAction(bool Function() action) {
    action();
    setState(() {});
    _save();
  }

  void _applyClass(String key) {
    if (_game.applyClass(key)) {
      setState(() {});
      _save();
    }
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boxing RPG'),
        actions: _inMenu
            ? null
            : [
                TextButton.icon(
                  onPressed: _returnToMenu,
                  icon: const Icon(Icons.menu, color: Colors.white),
                  label: const Text(
                    'Menu',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0C12), Color(0xFF15192A), Color(0xFF232B3E)],
          ),
        ),
        child: SafeArea(child: _inMenu ? _buildMenu() : _buildGame()),
      ),
    );
  }

  Widget _buildMenu() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sports_mma,
                size: 64,
                color: Color(0xFF00F2FE),
              ),
              const SizedBox(height: 16),
              const Text(
                'JS BOXING',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Player vs CPU — RPG Brawler',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startNewGame,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7B2CBF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('NEW GAME'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _hasSave ? _loadGame : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: _hasSave
                          ? const Color(0xFF00F2FE)
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    'LOAD GAME',
                    style: TextStyle(
                      color: _hasSave ? const Color(0xFF00F2FE) : Colors.white38,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatPanel(),
          const SizedBox(height: 12),
          _buildFighterCards(),
          const SizedBox(height: 12),
          _buildFightStage(),
          const SizedBox(height: 12),
          _buildControls(),
          if (_shopOpen) ...[const SizedBox(height: 12), _buildShop()],
          const SizedBox(height: 12),
          _buildMessages(),
        ],
      ),
    );
  }

  Widget _buildStatPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _stat('Class', _game.currentClass.label),
          _stat('Lv', '${_game.level}'),
          _stat('XP', '${_game.xp}/${_game.xpToNextLevel}'),
          _stat('Gold', '${_game.gold}'),
          _stat('Potions', '${_game.potions}'),
          _stat('ATK+', '${_game.playerAttackBonus}'),
          _stat('Fight', '${_game.fightNumber}'),
          _stat('Enemy', _game.currentEnemy.isBoss ? 'Boss' : 'Normal'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFighterCards() {
    return Row(
      children: [
        Expanded(
          child: _fighterCard(
            'Player',
            _game.playerHp,
            _game.playerMaxHp,
            BoxingGame.playerBodyColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _fighterCard(
            _game.currentEnemy.name,
            _game.cpuHp,
            _game.cpuMaxHp,
            _game.currentEnemy.color,
          ),
        ),
      ],
    );
  }

  Widget _fighterCard(String name, int hp, int maxHp, Color color) {
    final double fraction = maxHp > 0 ? (hp / maxHp).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'HP: $hp',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 10, color: Colors.white12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: fraction, end: fraction),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    child: Container(height: 10, color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFightStage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _playerPunch,
            _cpuPunch,
            _playerHit,
            _cpuHit,
          ]),
          builder: (context, _) {
            return CustomPaint(
              painter: _FightPainter(
                playerBody: BoxingGame.playerBodyColor,
                playerGlove: _game.playerGloveColor,
                cpuBody: _game.currentEnemy.color,
                cpuGlove: _game.currentEnemy.gloveColor,
                bossAura: _game.currentEnemy.isBoss,
                playerPunch: _playerPunch.value,
                cpuPunch: _cpuPunch.value,
                playerHit: _playerHit.value,
                cpuHit: _cpuHit.value,
                playerHandLead: _playerHandLead,
                cpuHandLead: _cpuHandLead,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton(
          onPressed: _game.isGameOver ? null : _doPlayerPunch,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7B2CBF),
          ),
          child: const Text('Punch'),
        ),
        OutlinedButton(
          onPressed: _toggleAuto,
          child: Text('Auto: ${_game.autoFightEnabled ? 'On' : 'Off'}'),
        ),
        OutlinedButton(
          onPressed: _toggleShop,
          child: Text(_shopOpen ? 'Close Shop' : 'Shop'),
        ),
        FilledButton(
          onPressed: _game.isGameOver ? _nextRound : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00897B),
          ),
          child: const Text('Next'),
        ),
      ],
    );
  }

  Widget _buildShop() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00F2FE).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Class', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _game.selectedClass,
                dropdownColor: const Color(0xFF1A1F2E),
                style: const TextStyle(color: Colors.white),
                items: kClasses.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.key,
                        child: Text(c.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) _applyClass(value);
                },
              ),
            ],
          ),
          const Divider(color: Colors.white12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () => _shopAction(_game.usePotion),
                child: const Text('Use Potion (+30 HP)'),
              ),
              OutlinedButton(
                onPressed: () => _shopAction(_game.buyPotion),
                child: const Text('Buy Potion (20 Gold)'),
              ),
              OutlinedButton(
                onPressed: () => _shopAction(_game.buyGloves),
                child: const Text('Buy Gloves (+2 ATK, 50 Gold)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _game.statusText,
            style: const TextStyle(
              color: Color(0xFF00F2FE),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _game.log.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _game.log[index],
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the boxing ring and two stylized fighters with punch / recoil
/// animation. A 2D re-implementation of the original Babylon.js FightRenderer.
class _FightPainter extends CustomPainter {
  _FightPainter({
    required this.playerBody,
    required this.playerGlove,
    required this.cpuBody,
    required this.cpuGlove,
    required this.bossAura,
    required this.playerPunch,
    required this.cpuPunch,
    required this.playerHit,
    required this.cpuHit,
    required this.playerHandLead,
    required this.cpuHandLead,
  });

  final Color playerBody;
  final Color playerGlove;
  final Color cpuBody;
  final Color cpuGlove;
  final bool bossAura;
  final double playerPunch;
  final double cpuPunch;
  final double playerHit;
  final double cpuHit;
  final bool playerHandLead;
  final bool cpuHandLead;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRing(canvas, size);

    final double groundY = size.height * 0.80;
    _drawFighter(
      canvas,
      size,
      baseX: size.width * 0.30,
      groundY: groundY,
      facing: 1,
      body: playerBody,
      glove: playerGlove,
      punch: playerPunch,
      hit: playerHit,
      handLead: playerHandLead,
      aura: false,
    );
    _drawFighter(
      canvas,
      size,
      baseX: size.width * 0.70,
      groundY: groundY,
      facing: -1,
      body: cpuBody,
      glove: cpuGlove,
      punch: cpuPunch,
      hit: cpuHit,
      handLead: cpuHandLead,
      aura: bossAura,
    );
  }

  void _paintRing(Canvas canvas, Size size) {
    // Backdrop.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0F141B),
    );

    // Ring mat (a slight trapezoid for depth).
    final double topY = size.height * 0.42;
    final double botY = size.height * 0.92;
    final matPath = Path()
      ..moveTo(size.width * 0.14, botY)
      ..lineTo(size.width * 0.86, botY)
      ..lineTo(size.width * 0.74, topY)
      ..lineTo(size.width * 0.26, topY)
      ..close();
    canvas.drawPath(matPath, Paint()..color = const Color(0xFF2D3F54));
    canvas.drawPath(
      matPath,
      Paint()
        ..color = const Color(0xFF1E2936)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * 0.02,
    );

    // Corner posts.
    final postPaint = Paint()..color = const Color(0xFF9AA4B2);
    final ropePaint = Paint()
      ..color = const Color(0xFFFF5F73)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, size.height * 0.006);
    final corners = [
      Offset(size.width * 0.26, topY),
      Offset(size.width * 0.74, topY),
      Offset(size.width * 0.14, botY),
      Offset(size.width * 0.86, botY),
    ];
    final double postH = size.height * 0.12;
    for (final c in corners) {
      canvas.drawRect(
        Rect.fromLTWH(c.dx - 3, c.dy - postH, 6, postH),
        postPaint,
      );
    }
    // Ropes (3 levels) along front and back edges.
    for (int i = 1; i <= 3; i++) {
      final double off = postH * (i / 3.2);
      canvas.drawLine(
        Offset(corners[2].dx, corners[2].dy - off),
        Offset(corners[3].dx, corners[3].dy - off),
        ropePaint,
      );
      canvas.drawLine(
        Offset(corners[0].dx, corners[0].dy - off),
        Offset(corners[1].dx, corners[1].dy - off),
        ropePaint,
      );
    }
  }

  void _drawFighter(
    Canvas canvas,
    Size size, {
    required double baseX,
    required double groundY,
    required double facing,
    required Color body,
    required Color glove,
    required double punch,
    required double hit,
    required bool handLead,
    required bool aura,
  }) {
    final double unit = size.height;
    final double extend = sin(punch * pi); // 0 -> 1 -> 0
    final double recoil = sin(hit * pi) * unit * 0.045 * -facing;
    final double lean = extend * unit * 0.025 * facing;
    final double cx = baseX + recoil + lean;

    final double hipY = groundY - unit * 0.20;
    final double shoulderY = groundY - unit * 0.40;
    final double headR = unit * 0.065;
    final Offset head = Offset(cx, shoulderY - unit * 0.085);

    final bodyPaint = Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.05
      ..strokeCap = StrokeCap.round;
    final limbPaint = Paint()
      ..color = body.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.03
      ..strokeCap = StrokeCap.round;
    final glovePaint = Paint()..color = glove;
    final skinPaint = Paint()..color = const Color(0xFFD8C8B4);

    // Boss aura.
    if (aura) {
      canvas.drawCircle(
        Offset(cx, shoulderY),
        unit * 0.22,
        Paint()..color = body.withValues(alpha: 0.18),
      );
    }

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, groundY + unit * 0.01),
        width: unit * 0.22,
        height: unit * 0.05,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    // Legs.
    canvas.drawLine(
      Offset(cx, hipY),
      Offset(cx - unit * 0.06, groundY),
      limbPaint,
    );
    canvas.drawLine(
      Offset(cx, hipY),
      Offset(cx + unit * 0.06, groundY),
      limbPaint,
    );

    // Torso.
    canvas.drawLine(Offset(cx, hipY), Offset(cx, shoulderY), bodyPaint);

    // Head.
    canvas.drawCircle(head, headR, skinPaint);

    // Arms: one guard arm, one punching arm.
    final Offset shoulder = Offset(cx, shoulderY);
    final double guardReach = unit * 0.09;
    final double punchReach = unit * 0.12 + extend * unit * 0.26;

    // Guard glove stays up near the chin.
    final Offset guardGlove = Offset(
      cx + facing * guardReach * 0.5,
      shoulderY - unit * 0.05,
    );
    // Punching glove drives toward the opponent (in `facing` direction).
    final double handYOffset = handLead ? -unit * 0.01 : unit * 0.02;
    final Offset punchGlove = Offset(
      cx + facing * punchReach,
      shoulderY + handYOffset,
    );

    canvas.drawLine(shoulder, guardGlove, limbPaint);
    canvas.drawLine(shoulder, punchGlove, limbPaint);
    canvas.drawCircle(guardGlove, unit * 0.035, glovePaint);
    canvas.drawCircle(punchGlove, unit * 0.045, glovePaint);
  }

  @override
  bool shouldRepaint(covariant _FightPainter old) {
    return old.playerPunch != playerPunch ||
        old.cpuPunch != cpuPunch ||
        old.playerHit != playerHit ||
        old.cpuHit != cpuHit ||
        old.cpuBody != cpuBody ||
        old.cpuGlove != cpuGlove ||
        old.playerGlove != playerGlove ||
        old.bossAura != bossAura;
  }
}
