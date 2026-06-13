import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localstorage/localstorage.dart';

class Game2048Screen extends StatefulWidget {
  const Game2048Screen({super.key});

  @override
  State<Game2048Screen> createState() => _Game2048ScreenState();
}

enum _MoveDirection { up, down, left, right }

class _Game2048ScreenState extends State<Game2048Screen> {
  static const int _boardSize = 5;
  static const int _targetTile = 2048;
  static const int _moveScore = 150;
  static const String _bestScoreKey = 'game_2048_best_score';
  static const Duration _slideDuration = Duration(milliseconds: 115);

  final FocusNode _focusNode = FocusNode();
  final Random _random = Random();

  final List<_TileData> _tiles = [];
  int _nextTileId = 1;
  int _score = 0;
  int _bestScore = 0;
  bool _gameOver = false;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _resetGame();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _loadBestScore() {
    try {
      final String? saved = localStorage.getItem(_bestScoreKey);
      _bestScore = int.tryParse(saved ?? '0') ?? 0;
    } catch (_) {
      _bestScore = 0;
    }
  }

  void _saveBestScore() {
    try {
      localStorage.setItem(_bestScoreKey, _bestScore.toString());
    } catch (_) {
      // Ignore storage errors and keep gameplay uninterrupted.
    }
  }

  void _resetGame() {
    setState(() {
      _tiles.clear();
      _nextTileId = 1;
      _score = 0;
      _gameOver = false;
      _won = false;
      _spawnRandomTile();
      _spawnRandomTile();
    });
  }

  void _spawnRandomTile() {
    final occupied = _occupiedPositions();
    final empties = <_CellPos>[];

    for (int r = 0; r < _boardSize; r++) {
      for (int c = 0; c < _boardSize; c++) {
        final key = _key(r, c);
        if (!occupied.containsKey(key)) {
          empties.add(_CellPos(r, c));
        }
      }
    }

    if (empties.isEmpty) return;

    final spot = empties[_random.nextInt(empties.length)];
    _tiles.add(
      _TileData(
        id: _nextTileId++,
        value: _random.nextBool() ? 2 : 4,
        row: spot.row,
        col: spot.col,
        isNew: true,
      ),
    );
  }

  Map<int, _TileData> _occupiedPositions() {
    final result = <int, _TileData>{};
    for (final tile in _tiles) {
      result[_key(tile.row, tile.col)] = tile;
    }
    return result;
  }

  void _attemptMove(_MoveDirection direction) {
    if (_gameOver) return;

    final moved = _applyMove(direction);
    if (!moved) return;

    setState(() {
      _score += _moveScore;
      _spawnRandomTile();

      if (_score > _bestScore) {
        _bestScore = _score;
        _saveBestScore();
      }

      if (!_won && _tiles.any((tile) => tile.value >= _targetTile)) {
        _won = true;
        _showMessage('You reached $_targetTile! Keep going.');
      }

      if (!_canMove()) {
        _gameOver = true;
        _showMessage('Game Over');
      }
    });

    Future<void>.delayed(_slideDuration, () {
      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _tiles.length; i++) {
          _tiles[i] = _tiles[i].copyWith(isNew: false, isMerged: false);
        }
      });
    });
  }

  bool _applyMove(_MoveDirection direction) {
    final occupied = _occupiedPositions();
    final newGrid = <int, _TileData>{};
    final removedIds = <int>{};
    var moved = false;

    for (final line in _linesForDirection(direction)) {
      var target = 0;

      for (final pos in line) {
        final tile = occupied[_key(pos.row, pos.col)];
        if (tile == null) continue;

        var merged = false;
        if (target > 0) {
          final mergePos = line[target - 1];
          final mergeKey = _key(mergePos.row, mergePos.col);
          final previous = newGrid[mergeKey];
          if (previous != null &&
              !previous.isMerged &&
              previous.value == tile.value) {
            moved =
                moved || tile.row != mergePos.row || tile.col != mergePos.col;
            removedIds.add(previous.id);
            newGrid[mergeKey] = tile.copyWith(
              row: mergePos.row,
              col: mergePos.col,
              value: tile.value * 2,
              isMerged: true,
            );
            merged = true;
            target += 1;
          }
        }

        if (merged) continue;

        final targetPos = line[target];
        moved = moved || tile.row != targetPos.row || tile.col != targetPos.col;
        newGrid[_key(targetPos.row, targetPos.col)] = tile.copyWith(
          row: targetPos.row,
          col: targetPos.col,
          isMerged: false,
        );
        target += 1;
      }
    }

    if (!moved) return false;

    _tiles
      ..clear()
      ..addAll(newGrid.values.where((tile) => !removedIds.contains(tile.id)));
    return true;
  }

  List<List<_CellPos>> _linesForDirection(_MoveDirection direction) {
    final lines = <List<_CellPos>>[];

    switch (direction) {
      case _MoveDirection.left:
        for (int r = 0; r < _boardSize; r++) {
          lines.add(List.generate(_boardSize, (c) => _CellPos(r, c)));
        }
      case _MoveDirection.right:
        for (int r = 0; r < _boardSize; r++) {
          lines.add(
            List.generate(_boardSize, (c) => _CellPos(r, _boardSize - 1 - c)),
          );
        }
      case _MoveDirection.up:
        for (int c = 0; c < _boardSize; c++) {
          lines.add(List.generate(_boardSize, (r) => _CellPos(r, c)));
        }
      case _MoveDirection.down:
        for (int c = 0; c < _boardSize; c++) {
          lines.add(
            List.generate(_boardSize, (r) => _CellPos(_boardSize - 1 - r, c)),
          );
        }
    }

    return lines;
  }

  bool _canMove() {
    if (_tiles.length < _boardSize * _boardSize) return true;

    final occupied = _occupiedPositions();
    for (int r = 0; r < _boardSize; r++) {
      for (int c = 0; c < _boardSize; c++) {
        final current = occupied[_key(r, c)];
        if (current == null) continue;

        if (r + 1 < _boardSize) {
          final down = occupied[_key(r + 1, c)];
          if (down != null && down.value == current.value) return true;
        }
        if (c + 1 < _boardSize) {
          final right = occupied[_key(r, c + 1)];
          if (right != null && right.value == current.value) return true;
        }
      }
    }
    return false;
  }

  int _key(int row, int col) => row * _boardSize + col;

  void _showMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(milliseconds: 1300),
          ),
        );
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    final dx = details.velocity.pixelsPerSecond.dx;
    final dy = details.velocity.pixelsPerSecond.dy;
    if (dx.abs() < 100 && dy.abs() < 100) return;

    if (dx.abs() > dy.abs()) {
      _attemptMove(dx > 0 ? _MoveDirection.right : _MoveDirection.left);
      return;
    }
    _attemptMove(dy > 0 ? _MoveDirection.down : _MoveDirection.up);
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _attemptMove(_MoveDirection.up);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _attemptMove(_MoveDirection.down);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _attemptMove(_MoveDirection.left);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _attemptMove(_MoveDirection.right);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _tileColor(int value) {
    const colors = <int, Color>{
      2: Color(0xFFEEE4DA),
      4: Color(0xFFEDE0C8),
      8: Color(0xFFF2B179),
      16: Color(0xFFF59563),
      32: Color(0xFFF67C5F),
      64: Color(0xFFF65E3B),
      128: Color(0xFFEDCF72),
      256: Color(0xFFEDCC61),
      512: Color(0xFFEDC850),
      1024: Color(0xFFEDC53F),
      2048: Color(0xFFEDC22E),
    };
    return colors[value] ?? const Color(0xFF3C3A32);
  }

  Color _tileTextColor(int value) {
    return value <= 4 ? const Color(0xFF776E65) : const Color(0xFFF9F6F2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF8EF),
        foregroundColor: const Color(0xFF776E65),
        elevation: 0,
        title: const Text(
          '2048',
          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _resetGame,
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ScoreCard(
                        label: 'Score',
                        value: _score,
                        background: const Color(0xFFBBADA0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScoreCard(
                        label: 'Best',
                        value: _bestScore,
                        background: const Color(0xFFBBADA0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _gameOver
                      ? 'Game over. Press restart to try again.'
                      : 'Swipe or use arrow keys to slide tiles.',
                  style: const TextStyle(
                    color: Color(0xFF776E65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final boardSize = min(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      const gap = 8.0;
                      const outerPadding = 10.0;
                      final tileSize =
                          (boardSize -
                              (outerPadding * 2) -
                              (gap * (_boardSize - 1))) /
                          _boardSize;

                      return Center(
                        child: GestureDetector(
                          onTap: () => _focusNode.requestFocus(),
                          onPanEnd: _handlePanEnd,
                          child: Container(
                            width: boardSize,
                            height: boardSize,
                            padding: const EdgeInsets.all(outerPadding),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBBADA0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Stack(
                              children: [
                                GridView.builder(
                                  itemCount: _boardSize * _boardSize,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: _boardSize,
                                        mainAxisSpacing: gap,
                                        crossAxisSpacing: gap,
                                      ),
                                  itemBuilder: (context, _) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFCDC1B4),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    );
                                  },
                                ),
                                ..._tiles.map((tile) {
                                  final left = tile.col * (tileSize + gap);
                                  final top = tile.row * (tileSize + gap);
                                  return AnimatedPositioned(
                                    key: ValueKey<int>(tile.id),
                                    duration: _slideDuration,
                                    curve: Curves.easeInOut,
                                    left: left,
                                    top: top,
                                    width: tileSize,
                                    height: tileSize,
                                    child: _TileWidget(
                                      value: tile.value,
                                      color: _tileColor(tile.value),
                                      textColor: _tileTextColor(tile.value),
                                      isNew: tile.isNew,
                                      isMerged: tile.isMerged,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  const _TileWidget({
    required this.value,
    required this.color,
    required this.textColor,
    required this.isNew,
    required this.isMerged,
  });

  final int value;
  final Color color;
  final Color textColor;
  final bool isNew;
  final bool isMerged;

  @override
  Widget build(BuildContext context) {
    final startScale = isNew ? 0.65 : (isMerged ? 1.2 : 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: startScale, end: 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          boxShadow: value >= 128
              ? const [
                  BoxShadow(
                    color: Color(0x33EDC22E),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: value < 128 ? 36 : 30,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.value,
    required this.background,
  });

  final String label;
  final int value;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              color: Color(0xFFEEE4DA),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFFF9F6F2),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileData {
  const _TileData({
    required this.id,
    required this.value,
    required this.row,
    required this.col,
    this.isNew = false,
    this.isMerged = false,
  });

  final int id;
  final int value;
  final int row;
  final int col;
  final bool isNew;
  final bool isMerged;

  _TileData copyWith({
    int? value,
    int? row,
    int? col,
    bool? isNew,
    bool? isMerged,
  }) {
    return _TileData(
      id: id,
      value: value ?? this.value,
      row: row ?? this.row,
      col: col ?? this.col,
      isNew: isNew ?? this.isNew,
      isMerged: isMerged ?? this.isMerged,
    );
  }
}

class _CellPos {
  const _CellPos(this.row, this.col);

  final int row;
  final int col;
}
