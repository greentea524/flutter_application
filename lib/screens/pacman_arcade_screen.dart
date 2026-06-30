import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Point;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localstorage/localstorage.dart';

class PacmanArcadeScreen extends StatefulWidget {
  const PacmanArcadeScreen({super.key});

  @override
  State<PacmanArcadeScreen> createState() => _PacmanArcadeScreenState();
}

class _PacmanArcadeScreenState extends State<PacmanArcadeScreen> {
  static const int _gridMin = -8;
  static const int _gridMax = 8;
  static const int _playMin = -7;
  static const int _playMax = 7;
  static const int _spawnX = -7;
  static const int _spawnZ = -7;
  static const String _scoreStorageKey = 'jsPacmanPersistentScore';

  static const List<Point<int>> _ghostDirections = <Point<int>>[
    Point<int>(1, 0),
    Point<int>(-1, 0),
    Point<int>(0, 1),
    Point<int>(0, -1),
  ];

  static const List<Point<int>> _ghostSpawnPreferences = <Point<int>>[
    Point<int>(_playMax, _playMax),
    Point<int>(_playMax, _playMin),
    Point<int>(_playMin, _playMax),
    Point<int>(0, _playMax),
    Point<int>(_playMax, 0),
  ];

  static const List<Color> _ghostColors = <Color>[
    Color(0xFFFF4D5A),
    Color(0xFF5AD3FF),
    Color(0xFFFFA64D),
    Color(0xFFFF66DA),
    Color(0xFF99FF66),
  ];

  final FocusNode _focusNode = FocusNode();
  final math.Random _random = math.Random();

  Timer? _loopTimer;
  Timer? _roundTimer;
  DateTime? _lastFrameAt;

  final Set<String> _walls = <String>{};
  final Set<String> _pellets = <String>{};
  final List<_GhostState> _ghosts = <_GhostState>[];
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};

  Offset _pacmanPosition = Offset(_spawnX.toDouble(), _spawnZ.toDouble());
  Point<int> _currentDirection = const Point<int>(0, 0);
  Point<int> _lastInputDirection = const Point<int>(1, 0);
  Offset _moveInput = Offset.zero;

  bool _upPressed = false;
  bool _downPressed = false;
  bool _leftPressed = false;
  bool _rightPressed = false;

  int _score = 0;
  int _ghostCount = 1;
  double _ghostMoveCooldownSeconds = 0;
  double _ghostRenderLerp = 0;

  bool _isGameOver = false;
  bool _isStartingNewGame = false;

  double _chompPhase = 0;
  double _mouthBoost = 0;

  static const double _pacmanSpeedTilesPerSecond = 4.4;
  static const double _pacmanRadiusTiles = 0.23;
  static const double _wallHalfExtentTiles = 0.42;
  static const double _pelletConsumeRadiusTiles = 0.36;
  static const double _ghostStepIntervalSeconds = 0.34;

  @override
  void initState() {
    super.initState();
    _score = _loadPersistedScore();
    _resetRound();
    _startLoop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _loopTimer?.cancel();
    _roundTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  int _loadPersistedScore() {
    try {
      final String? value = localStorage.getItem(_scoreStorageKey);
      final int parsed = int.tryParse(value ?? '0') ?? 0;
      return parsed < 0 ? 0 : parsed;
    } catch (_) {
      return 0;
    }
  }

  void _persistScore() {
    try {
      localStorage.setItem(_scoreStorageKey, _score.toString());
    } catch (_) {
      // Keep gameplay running even if storage is unavailable.
    }
  }

  void _startLoop() {
    _loopTimer?.cancel();
    _lastFrameAt = DateTime.now();
    _loopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      final DateTime now = DateTime.now();
      final DateTime previous = _lastFrameAt ?? now;
      _lastFrameAt = now;

      // Clamp dt to avoid giant jumps when app focus changes.
      final double dtSeconds = math.min(
        0.05,
        now.difference(previous).inMicroseconds / 1000000,
      );

      setState(() => _updateGame(dtSeconds));
    });
  }

  String _key(int x, int z) => '$x,$z';

  bool _isWallAt(int x, int z) => _walls.contains(_key(x, z));

  bool _isBlocked(int x, int z) {
    if (x < _gridMin || x > _gridMax || z < _gridMin || z > _gridMax) {
      return true;
    }
    return _isWallAt(x, z);
  }

  void _addWallRect(int centerX, int centerZ, int width, int depth) {
    final int halfW = width ~/ 2;
    final int halfD = depth ~/ 2;

    for (int x = centerX - halfW; x <= centerX + halfW; x++) {
      for (int z = centerZ - halfD; z <= centerZ + halfD; z++) {
        _walls.add(_key(x, z));
      }
    }
  }

  bool _inSpawnSafeZone(int x, int z) {
    return (x - _spawnX).abs() <= 2 && (z - _spawnZ).abs() <= 2;
  }

  bool _canPlaceRect(int centerX, int centerZ, int width, int depth) {
    final int halfW = width ~/ 2;
    final int halfD = depth ~/ 2;

    for (int x = centerX - halfW; x <= centerX + halfW; x++) {
      for (int z = centerZ - halfD; z <= centerZ + halfD; z++) {
        if (x <= _gridMin || x >= _gridMax || z <= _gridMin || z >= _gridMax) {
          return false;
        }
        if (_inSpawnSafeZone(x, z)) {
          return false;
        }
        if (_walls.contains(_key(x, z))) {
          return false;
        }
      }
    }

    return true;
  }

  bool _tryAddMirroredRect(int centerX, int centerZ, int width, int depth) {
    final int mirrorX = -centerX;

    if (centerX == 0) {
      if (!_canPlaceRect(0, centerZ, width, depth)) return false;
      _addWallRect(0, centerZ, width, depth);
      return true;
    }

    if (!_canPlaceRect(centerX, centerZ, width, depth) ||
        !_canPlaceRect(mirrorX, centerZ, width, depth)) {
      return false;
    }

    _addWallRect(centerX, centerZ, width, depth);
    _addWallRect(mirrorX, centerZ, width, depth);
    return true;
  }

  void _buildRandomLabyrinth() {
    _walls.clear();

    // Border walls
    for (int i = _gridMin; i <= _gridMax; i++) {
      _walls.add(_key(i, _gridMin));
      _walls.add(_key(i, _gridMax));
      _walls.add(_key(_gridMin, i));
      _walls.add(_key(_gridMax, i));
    }

    // Center house similar to JS version.
    _addWallRect(0, -1, 3, 1);
    _addWallRect(0, 1, 3, 1);
    _addWallRect(-1, 0, 1, 3);
    _addWallRect(1, 0, 1, 3);

    int horizontalAdded = 0;
    for (int i = 0; i < 90 && horizontalAdded < 5; i++) {
      final int centerX = -(_random.nextInt(5) + 2); // -2..-6
      final int centerZ = _random.nextInt(13) - 6; // -6..6
      final int width = 3;
      if (_tryAddMirroredRect(centerX, centerZ, width, 1)) {
        horizontalAdded++;
      }
    }

    int verticalAdded = 0;
    for (int i = 0; i < 90 && verticalAdded < 5; i++) {
      final int centerX = -(_random.nextInt(6) + 1); // -1..-6
      final int centerZ = _random.nextInt(11) - 5; // -5..5
      final int depth = 3;
      if (_tryAddMirroredRect(centerX, centerZ, 1, depth)) {
        verticalAdded++;
      }
    }

    if (_random.nextDouble() > 0.6 && _canPlaceRect(0, -6, 5, 1)) {
      _addWallRect(0, -6, 5, 1);
    }
    if (_random.nextDouble() > 0.6 && _canPlaceRect(0, 6, 5, 1)) {
      _addWallRect(0, 6, 5, 1);
    }

    _ensureMazeConnectivity();
  }

  void _ensureMazeConnectivity() {
    final Set<String> walkable = <String>{};
    for (int z = _playMin; z <= _playMax; z++) {
      for (int x = _playMin; x <= _playMax; x++) {
        if (!_isBlocked(x, z)) {
          walkable.add(_key(x, z));
        }
      }
    }

    if (walkable.isEmpty) return;

    final List<Set<Point<int>>> components = <Set<Point<int>>>[];
    final Set<String> visited = <String>{};

    for (final String start in walkable) {
      if (visited.contains(start)) continue;

      final List<String> queue = <String>[start];
      final Set<Point<int>> component = <Point<int>>{};
      visited.add(start);
      int cursor = 0;

      while (cursor < queue.length) {
        final String current = queue[cursor++];
        final List<String> parts = current.split(',');
        final int cx = int.parse(parts[0]);
        final int cz = int.parse(parts[1]);
        component.add(Point<int>(cx, cz));

        for (final Point<int> dir in _ghostDirections) {
          final int nx = cx + dir.x;
          final int nz = cz + dir.y;
          if (nx < _playMin ||
              nx > _playMax ||
              nz < _playMin ||
              nz > _playMax) {
            continue;
          }
          final String neighbor = _key(nx, nz);
          if (!walkable.contains(neighbor) || visited.contains(neighbor)) {
            continue;
          }
          visited.add(neighbor);
          queue.add(neighbor);
        }
      }

      components.add(component);
    }

    if (components.length <= 1) return;

    final Set<Point<int>> mainComponent = components.first;

    for (int i = 1; i < components.length; i++) {
      final Set<Point<int>> component = components[i];
      final Point<int> from = component.first;
      final Point<int> to = mainComponent.first;

      _carvePath(from, to);
      mainComponent.addAll(component);
    }
  }

  void _carvePath(Point<int> from, Point<int> to) {
    int x = from.x;
    int z = from.y;

    void clearCell(int cx, int cz) {
      if (cx < _playMin || cx > _playMax || cz < _playMin || cz > _playMax) {
        return;
      }
      _walls.remove(_key(cx, cz));
    }

    clearCell(x, z);

    while (x != to.x) {
      x += to.x > x ? 1 : -1;
      clearCell(x, z);
    }

    while (z != to.y) {
      z += to.y > z ? 1 : -1;
      clearCell(x, z);
    }
  }

  Point<int> _findNearestWalkableTile(int preferredX, int preferredZ) {
    Point<int> best = const Point<int>(_spawnX, _spawnZ);
    int bestDistance = 1 << 30;

    for (int z = _playMin; z <= _playMax; z++) {
      for (int x = _playMin; x <= _playMax; x++) {
        if (_isBlocked(x, z)) continue;
        final int distance = (x - preferredX).abs() + (z - preferredZ).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          best = Point<int>(x, z);
        }
      }
    }

    return best;
  }

  List<Point<int>> _buildReachablePelletPositions() {
    final Set<String> walkable = <String>{};
    for (int z = _playMin; z <= _playMax; z++) {
      for (int x = _playMin; x <= _playMax; x++) {
        if (!_isBlocked(x, z)) {
          walkable.add(_key(x, z));
        }
      }
    }

    final Point<int> pacmanTile = Point<int>(
      _pacmanPosition.dx.round(),
      _pacmanPosition.dy.round(),
    );

    String start = _key(pacmanTile.x, pacmanTile.y);
    if (!walkable.contains(start)) {
      if (walkable.isEmpty) return <Point<int>>[];
      start = walkable.first;
    }

    final List<String> queue = <String>[start];
    final Set<String> visited = <String>{start};

    int cursor = 0;
    while (cursor < queue.length) {
      final String key = queue[cursor++];
      final List<String> parts = key.split(',');
      final int x = int.parse(parts[0]);
      final int z = int.parse(parts[1]);

      for (final Point<int> dir in _ghostDirections) {
        final int nx = x + dir.x;
        final int nz = z + dir.y;
        if (nx < _playMin || nx > _playMax || nz < _playMin || nz > _playMax) {
          continue;
        }
        final String neighbor = _key(nx, nz);
        if (!walkable.contains(neighbor) || visited.contains(neighbor)) {
          continue;
        }
        visited.add(neighbor);
        queue.add(neighbor);
      }
    }

    final List<String> startParts = start.split(',');
    final int startX = int.parse(startParts[0]);
    final int startZ = int.parse(startParts[1]);

    final List<Point<int>> candidates = <Point<int>>[];
    for (final String key in visited) {
      final List<String> parts = key.split(',');
      final int x = int.parse(parts[0]);
      final int z = int.parse(parts[1]);
      if (x == startX && z == startZ) continue;
      candidates.add(Point<int>(x, z));
    }

    candidates.shuffle(_random);
    final int pelletCount = math.max(30, (candidates.length * 0.42).floor());
    return candidates.take(pelletCount).toList(growable: false);
  }

  void _spawnPellets() {
    _pellets
      ..clear()
      ..addAll(_buildReachablePelletPositions().map((p) => _key(p.x, p.y)));
  }

  void _resetGhosts() {
    _ghosts.clear();

    for (int i = 0; i < _ghostCount; i++) {
      final Point<int> preferred =
          _ghostSpawnPreferences[i % _ghostSpawnPreferences.length];
      final Point<int> tile = _findNearestWalkableTile(
        preferred.x,
        preferred.y,
      );

      _ghosts.add(
        _GhostState(
          previousPosition: tile,
          position: tile,
          direction: _random.nextBool()
              ? const Point<int>(-1, 0)
              : const Point<int>(0, -1),
          color: _ghostColors[i % _ghostColors.length],
        ),
      );
    }
  }

  void _resetRound() {
    _pacmanPosition = Offset(_spawnX.toDouble(), _spawnZ.toDouble());
    _currentDirection = const Point<int>(0, 0);
    _moveInput = Offset.zero;
    _pressedKeys.clear();
    _upPressed = false;
    _downPressed = false;
    _leftPressed = false;
    _rightPressed = false;
    _ghostMoveCooldownSeconds = _ghostStepIntervalSeconds;
    _ghostRenderLerp = 0;
    _buildRandomLabyrinth();
    _resetGhosts();
    _spawnPellets();
  }

  void _resetGame({required bool resetScore}) {
    _roundTimer?.cancel();
    _isStartingNewGame = false;
    _isGameOver = false;
    _ghostCount = 1;

    if (resetScore) {
      _score = 0;
      _persistScore();
    }

    setState(_resetRound);
  }

  bool _canMove(Point<int> from, Point<int> direction) {
    final int nx = from.x + direction.x;
    final int nz = from.y + direction.y;
    return !_isBlocked(nx, nz);
  }

  bool _isCircleBlocked(Offset position) {
    final int minX = (position.dx - (_pacmanRadiusTiles + _wallHalfExtentTiles))
        .floor();
    final int maxX = (position.dx + (_pacmanRadiusTiles + _wallHalfExtentTiles))
        .ceil();
    final int minZ = (position.dy - (_pacmanRadiusTiles + _wallHalfExtentTiles))
        .floor();
    final int maxZ = (position.dy + (_pacmanRadiusTiles + _wallHalfExtentTiles))
        .ceil();

    for (int x = minX; x <= maxX; x++) {
      for (int z = minZ; z <= maxZ; z++) {
        if (!_isBlocked(x, z)) continue;

        final double nearestX = position.dx
            .clamp(x - _wallHalfExtentTiles, x + _wallHalfExtentTiles)
            .toDouble();
        final double nearestZ = position.dy
            .clamp(z - _wallHalfExtentTiles, z + _wallHalfExtentTiles)
            .toDouble();
        final double dx = position.dx - nearestX;
        final double dz = position.dy - nearestZ;

        if ((dx * dx) + (dz * dz) < (_pacmanRadiusTiles * _pacmanRadiusTiles)) {
          return true;
        }
      }
    }

    return false;
  }

  bool _consumeNearbyPellet() {
    final int minX = (_pacmanPosition.dx - _pelletConsumeRadiusTiles).floor();
    final int maxX = (_pacmanPosition.dx + _pelletConsumeRadiusTiles).ceil();
    final int minZ = (_pacmanPosition.dy - _pelletConsumeRadiusTiles).floor();
    final int maxZ = (_pacmanPosition.dy + _pelletConsumeRadiusTiles).ceil();

    for (int z = minZ; z <= maxZ; z++) {
      for (int x = minX; x <= maxX; x++) {
        final String key = _key(x, z);
        if (!_pellets.contains(key)) continue;

        final double dx = _pacmanPosition.dx - x;
        final double dz = _pacmanPosition.dy - z;
        if ((dx * dx) + (dz * dz) <=
            (_pelletConsumeRadiusTiles * _pelletConsumeRadiusTiles)) {
          _pellets.remove(key);
          return true;
        }
      }
    }

    return false;
  }

  void _updateMoveInputFromControls() {
    double x = 0;
    double y = 0;

    if (_leftPressed ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA)) {
      x -= 1;
    }
    if (_rightPressed ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyD)) {
      x += 1;
    }
    if (_upPressed ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyW)) {
      y -= 1;
    }
    if (_downPressed ||
        _pressedKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyS)) {
      y += 1;
    }

    if (x == 0 && y == 0) {
      _moveInput = Offset.zero;
      return;
    }

    // Lock movement to one axis (no diagonal). When both axes are pressed,
    // keep the axis of the latest directional input.
    if (x != 0 && y != 0) {
      if (_lastInputDirection.x != 0) {
        y = 0;
      } else {
        x = 0;
      }
    }

    if (x != 0) {
      _moveInput = Offset(x.sign.toDouble(), 0);
      return;
    }

    _moveInput = Offset(0, y.sign.toDouble());
  }

  void _updatePacmanMovement(double dtSeconds) {
    if (_moveInput == Offset.zero) {
      return;
    }

    final double moveDistance = _pacmanSpeedTilesPerSecond * dtSeconds;
    final double moveX = _moveInput.dx * moveDistance;
    final double moveY = _moveInput.dy * moveDistance;

    if (moveX.abs() >= moveY.abs()) {
      _currentDirection = Point<int>(moveX >= 0 ? 1 : -1, 0);
    } else {
      _currentDirection = Point<int>(0, moveY >= 0 ? 1 : -1);
    }

    final int steps = math.max(1, (moveDistance / 0.08).ceil());
    final double stepX = moveX / steps;
    final double stepY = moveY / steps;

    for (int i = 0; i < steps; i++) {
      final Offset nextX = Offset(
        _pacmanPosition.dx + stepX,
        _pacmanPosition.dy,
      );
      if (!_isCircleBlocked(nextX)) {
        _pacmanPosition = nextX;
      } else if (stepX != 0) {
        // Nudge toward corridor center to reduce corner sticking while sliding.
        final double targetY = _pacmanPosition.dy.roundToDouble();
        final Offset skimY = Offset(
          _pacmanPosition.dx,
          _pacmanPosition.dy + ((targetY - _pacmanPosition.dy) * 0.2),
        );
        if (!_isCircleBlocked(skimY)) {
          _pacmanPosition = skimY;
        }
      }

      final Offset nextY = Offset(
        _pacmanPosition.dx,
        _pacmanPosition.dy + stepY,
      );
      if (!_isCircleBlocked(nextY)) {
        _pacmanPosition = nextY;
      } else if (stepY != 0) {
        final double targetX = _pacmanPosition.dx.roundToDouble();
        final Offset skimX = Offset(
          _pacmanPosition.dx + ((targetX - _pacmanPosition.dx) * 0.2),
          _pacmanPosition.dy,
        );
        if (!_isCircleBlocked(skimX)) {
          _pacmanPosition = skimX;
        }
      }
    }
  }

  Point<int> _chooseGhostDirection(_GhostState ghost) {
    final List<Point<int>> options = _ghostDirections
        .where((Point<int> dir) {
          return _canMove(ghost.position, dir);
        })
        .toList(growable: false);

    if (options.isEmpty) {
      return Point<int>(-ghost.direction.x, -ghost.direction.y);
    }

    final Point<int>? forward = options.cast<Point<int>?>().firstWhere(
      (Point<int>? dir) =>
          dir!.x == ghost.direction.x && dir.y == ghost.direction.y,
      orElse: () => null,
    );

    if (forward != null && _random.nextDouble() > 0.25) {
      return forward;
    }

    return options[_random.nextInt(options.length)];
  }

  void _stepGhostsOnce() {
    for (int i = 0; i < _ghosts.length; i++) {
      final _GhostState ghost = _ghosts[i];
      final bool canKeepMoving = _canMove(ghost.position, ghost.direction);

      if (!canKeepMoving || _random.nextDouble() < 0.015) {
        ghost.direction = _chooseGhostDirection(ghost);
      }

      ghost.previousPosition = ghost.position;

      if (_canMove(ghost.position, ghost.direction)) {
        ghost.position = Point<int>(
          ghost.position.x + ghost.direction.x,
          ghost.position.y + ghost.direction.y,
        );
      } else {
        ghost.direction = _chooseGhostDirection(ghost);
      }
    }
  }

  void _updateGhostMovement(double dtSeconds) {
    _ghostMoveCooldownSeconds -= dtSeconds;
    int safety = 0;
    while (_ghostMoveCooldownSeconds <= 0 && safety < 2) {
      _ghostMoveCooldownSeconds += _ghostStepIntervalSeconds;
      _stepGhostsOnce();
      safety++;
    }

    final double progress =
        1 - (_ghostMoveCooldownSeconds / _ghostStepIntervalSeconds);
    _ghostRenderLerp = progress.clamp(0, 1).toDouble();

    // Recover gracefully if the app was paused for a while.
    if (_ghostMoveCooldownSeconds < -_ghostStepIntervalSeconds) {
      _ghostMoveCooldownSeconds = _ghostStepIntervalSeconds;
      _ghostRenderLerp = 0;
    }
  }

  bool _checkGhostCollision() {
    for (final _GhostState ghost in _ghosts) {
      final double dx = _pacmanPosition.dx - ghost.position.x;
      final double dz = _pacmanPosition.dy - ghost.position.y;
      if ((dx * dx) + (dz * dz) < 0.28) {
        return true;
      }
    }
    return false;
  }

  void _updateGame(double dtSeconds) {
    if (!_focusNode.hasFocus && _pressedKeys.isNotEmpty) {
      _pressedKeys.clear();
      _updateMoveInputFromControls();
    }

    if (!_isGameOver) {
      _updatePacmanMovement(dtSeconds);
    }

    final bool isMoving = _moveInput != Offset.zero;
    if (isMoving || _mouthBoost > 0) {
      _chompPhase += 0.38;
    }
    _mouthBoost = math.max(0, _mouthBoost - 0.05);

    if (!_isGameOver) {
      _updateGhostMovement(dtSeconds);
      if (_checkGhostCollision()) {
        _isGameOver = true;
      }
    }

    if (!_isGameOver) {
      if (_consumeNearbyPellet()) {
        _score += 10;
        _mouthBoost = 0.9;
        _persistScore();
      }
    }

    if (_pellets.isEmpty && !_isStartingNewGame && !_isGameOver) {
      _startNewGame();
    }
  }

  bool _isMovementKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyA ||
        key == LogicalKeyboardKey.keyS ||
        key == LogicalKeyboardKey.keyD;
  }

  void _setPadDirectionState(Point<int> direction, bool isPressed) {
    if (_isGameOver) return;

    setState(() {
      if (isPressed) {
        _lastInputDirection = direction;
      }
      if (direction.x < 0) _leftPressed = isPressed;
      if (direction.x > 0) _rightPressed = isPressed;
      if (direction.y < 0) _upPressed = isPressed;
      if (direction.y > 0) _downPressed = isPressed;
      _updateMoveInputFromControls();
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    if (!_isMovementKey(key)) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (_pressedKeys.contains(key)) return KeyEventResult.handled;
      setState(() {
        if (key == LogicalKeyboardKey.arrowUp ||
            key == LogicalKeyboardKey.keyW) {
          _lastInputDirection = const Point<int>(0, -1);
        } else if (key == LogicalKeyboardKey.arrowDown ||
            key == LogicalKeyboardKey.keyS) {
          _lastInputDirection = const Point<int>(0, 1);
        } else if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.keyA) {
          _lastInputDirection = const Point<int>(-1, 0);
        } else if (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.keyD) {
          _lastInputDirection = const Point<int>(1, 0);
        }
        _pressedKeys.add(key);
        _updateMoveInputFromControls();
      });
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      if (!_pressedKeys.contains(key)) return KeyEventResult.handled;
      setState(() {
        _pressedKeys.remove(key);
        _updateMoveInputFromControls();
      });
    }

    return KeyEventResult.handled;
  }

  void _startNewGame() {
    if (_isGameOver || _isStartingNewGame) return;

    _isStartingNewGame = true;
    _roundTimer?.cancel();
    _roundTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || _isGameOver) {
        _isStartingNewGame = false;
        return;
      }

      setState(() {
        _ghostCount = math.min(5, _ghostCount + 1);
        _resetRound();
        _isStartingNewGame = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String status = _isGameOver
        ? 'Game Over'
        : _isStartingNewGame
        ? 'Next Round...'
        : '';

    return Scaffold(
      backgroundColor: const Color(0xFF05070C),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0D1321),
        foregroundColor: Colors.white,
        leading: Focus(
          canRequestFocus: false,
          descendantsAreFocusable: false,
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        title: const Text('Pacman Arcade'),
        actions: [
          Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: IconButton(
              onPressed: () => _resetGame(resetScore: true),
              tooltip: 'Reset score and restart',
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focusNode.requestFocus(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard('Score', _score.toString()),
                      const SizedBox(width: 12),
                      _buildStatCard('Ghosts', _ghostCount.toString()),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (status.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isGameOver
                            ? const Color(0x66FF4D5A)
                            : const Color(0x6600BCD4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1020),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(
                              0xFF00E5FF,
                            ).withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: CustomPaint(
                          painter: _PacmanBoardPainter(
                            walls: _walls,
                            pellets: _pellets,
                            pacman: _pacmanPosition,
                            ghosts: _ghosts,
                            ghostLerp: _ghostRenderLerp,
                            chompPhase: _chompPhase,
                            mouthBoost: _mouthBoost,
                            direction: _currentDirection,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DirectionPad(onDirectionStateChanged: _setPadDirectionState),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF111A30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF243B61)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8EA6D8),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GhostState {
  _GhostState({
    required this.previousPosition,
    required this.position,
    required this.direction,
    required this.color,
  });

  Point<int> previousPosition;
  Point<int> position;
  Point<int> direction;
  Color color;
}

class _PacmanBoardPainter extends CustomPainter {
  const _PacmanBoardPainter({
    required this.walls,
    required this.pellets,
    required this.pacman,
    required this.ghosts,
    required this.ghostLerp,
    required this.chompPhase,
    required this.mouthBoost,
    required this.direction,
  });

  final Set<String> walls;
  final Set<String> pellets;
  final Offset pacman;
  final List<_GhostState> ghosts;
  final double ghostLerp;
  final double chompPhase;
  final double mouthBoost;
  final Point<int> direction;

  static const int _gridMin = -8;
  static const int _gridMax = 8;
  static const double _wallVisualScale = 0.84;

  Offset _cellCenter(Size size, int x, int z) {
    final double tile = size.width / (_gridMax - _gridMin + 1);
    final double dx = (x - _gridMin + 0.5) * tile;
    final double dy = (z - _gridMin + 0.5) * tile;
    return Offset(dx, dy);
  }

  Offset _cellCenterDouble(Size size, double x, double z) {
    final double tile = size.width / (_gridMax - _gridMin + 1);
    final double dx = (x - _gridMin + 0.5) * tile;
    final double dy = (z - _gridMin + 0.5) * tile;
    return Offset(dx, dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double tile = size.width / (_gridMax - _gridMin + 1);

    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF050A17), Color(0xFF0F1C39)],
      ).createShader(Offset.zero & size);

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      bgPaint,
    );

    final Paint wallPaint = Paint()..color = const Color(0xFF2E4D9A);
    for (final String key in walls) {
      final List<String> parts = key.split(',');
      final int x = int.parse(parts[0]);
      final int z = int.parse(parts[1]);
      final Offset c = _cellCenter(size, x, z);
      final Rect cell = Rect.fromCenter(
        center: c,
        width: tile * _wallVisualScale,
        height: tile * _wallVisualScale,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cell, Radius.circular(tile * 0.2)),
        wallPaint,
      );
    }

    final Paint pelletPaint = Paint()..color = const Color(0xFF46FFB2);
    for (final String key in pellets) {
      final List<String> parts = key.split(',');
      final int x = int.parse(parts[0]);
      final int z = int.parse(parts[1]);
      final Offset c = _cellCenter(size, x, z);
      canvas.drawCircle(c, tile * 0.11, pelletPaint);
    }

    for (final _GhostState ghost in ghosts) {
      final double gx =
          ghost.previousPosition.x +
          ((ghost.position.x - ghost.previousPosition.x) * ghostLerp);
      final double gz =
          ghost.previousPosition.y +
          ((ghost.position.y - ghost.previousPosition.y) * ghostLerp);
      final Offset c = _cellCenterDouble(size, gx, gz);
      final Rect body = Rect.fromCenter(
        center: c.translate(0, tile * 0.04),
        width: tile * 0.7,
        height: tile * 0.7,
      );

      final Path ghostPath = Path()
        ..addRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(body.left, body.top, body.width, body.height * 0.85),
            topLeft: Radius.circular(tile * 0.3),
            topRight: Radius.circular(tile * 0.3),
          ),
        )
        ..moveTo(body.left, body.top + body.height * 0.82)
        ..quadraticBezierTo(
          body.left + body.width * 0.1,
          body.bottom,
          body.left + body.width * 0.2,
          body.top + body.height * 0.82,
        )
        ..quadraticBezierTo(
          body.left + body.width * 0.3,
          body.bottom,
          body.left + body.width * 0.4,
          body.top + body.height * 0.82,
        )
        ..quadraticBezierTo(
          body.left + body.width * 0.5,
          body.bottom,
          body.left + body.width * 0.6,
          body.top + body.height * 0.82,
        )
        ..quadraticBezierTo(
          body.left + body.width * 0.7,
          body.bottom,
          body.left + body.width * 0.8,
          body.top + body.height * 0.82,
        )
        ..quadraticBezierTo(
          body.left + body.width * 0.9,
          body.bottom,
          body.right,
          body.top + body.height * 0.82,
        )
        ..close();

      canvas.drawPath(ghostPath, Paint()..color = ghost.color);

      final Paint eyeWhite = Paint()..color = Colors.white;
      final Paint pupil = Paint()..color = const Color(0xFF111111);
      final Offset leftEye = c.translate(-tile * 0.13, -tile * 0.09);
      final Offset rightEye = c.translate(tile * 0.13, -tile * 0.09);

      canvas.drawCircle(leftEye, tile * 0.1, eyeWhite);
      canvas.drawCircle(rightEye, tile * 0.1, eyeWhite);
      canvas.drawCircle(leftEye.translate(0, tile * 0.02), tile * 0.045, pupil);
      canvas.drawCircle(
        rightEye.translate(0, tile * 0.02),
        tile * 0.045,
        pupil,
      );
    }

    final Offset pc = _cellCenterDouble(size, pacman.dx, pacman.dy);
    final double chompWave = (math.sin(chompPhase) + 1) * 0.5;
    final double mouthOpen = math.min(
      0.82,
      0.12 + (0.5 * chompWave) + (0.24 * mouthBoost),
    );

    double angle = 0;
    if (direction.x == -1) {
      angle = math.pi;
    } else if (direction.y == -1) {
      angle = -math.pi / 2;
    } else if (direction.y == 1) {
      angle = math.pi / 2;
    }

    final Path pacmanPath = Path()
      ..moveTo(pc.dx, pc.dy)
      ..arcTo(
        Rect.fromCircle(center: pc, radius: tile * 0.33),
        angle + mouthOpen,
        (math.pi * 2) - (mouthOpen * 2),
        false,
      )
      ..close();

    canvas.drawPath(pacmanPath, Paint()..color = const Color(0xFFFFE34D));
  }

  @override
  bool shouldRepaint(covariant _PacmanBoardPainter oldDelegate) {
    return oldDelegate.walls != walls ||
        oldDelegate.pellets != pellets ||
        oldDelegate.pacman != pacman ||
        oldDelegate.ghostLerp != ghostLerp ||
        oldDelegate.chompPhase != chompPhase ||
        oldDelegate.mouthBoost != mouthBoost ||
        oldDelegate.direction != direction ||
        oldDelegate.ghosts != ghosts;
  }
}

class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.onDirectionStateChanged});

  final void Function(Point<int> direction, bool isPressed)
  onDirectionStateChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, Point<int> direction) {
      return GestureDetector(
        onTapDown: (_) => onDirectionStateChanged(direction, true),
        onTapUp: (_) => onDirectionStateChanged(direction, false),
        onTapCancel: () => onDirectionStateChanged(direction, false),
        child: Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: const Color(0x44333D5E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x5586A7E6)),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      );
    }

    return Column(
      children: [
        button(Icons.keyboard_arrow_up, const Point<int>(0, -1)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            button(Icons.keyboard_arrow_left, const Point<int>(-1, 0)),
            const SizedBox(width: 8),
            button(Icons.keyboard_arrow_down, const Point<int>(0, 1)),
            const SizedBox(width: 8),
            button(Icons.keyboard_arrow_right, const Point<int>(1, 0)),
          ],
        ),
      ],
    );
  }
}
