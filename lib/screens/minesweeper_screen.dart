import 'dart:math';

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

class MinesweeperScreen extends StatefulWidget {
  const MinesweeperScreen({super.key});

  @override
  State<MinesweeperScreen> createState() => _MinesweeperScreenState();
}

enum _TileStatus { hidden, mine, number, marked }

class _Tile {
  const _Tile({
    required this.x,
    required this.y,
    required this.mine,
    required this.status,
    this.adjacentMinesCount = 0,
  });

  final int x;
  final int y;
  final bool mine;
  final _TileStatus status;
  final int adjacentMinesCount;

  _Tile copyWith({
    int? x,
    int? y,
    bool? mine,
    _TileStatus? status,
    int? adjacentMinesCount,
  }) {
    return _Tile(
      x: x ?? this.x,
      y: y ?? this.y,
      mine: mine ?? this.mine,
      status: status ?? this.status,
      adjacentMinesCount: adjacentMinesCount ?? this.adjacentMinesCount,
    );
  }
}

class _MinesweeperScreenState extends State<MinesweeperScreen> {
  static const int _boardSize = 10;
  static const int _baseMineCount = 3;
  static const String _bestScoreKey = 'minesweeper_best_score';
  static const String _bestLevelKey = 'minesweeper_best_level';

  final Random _random = Random();

  List<List<_Tile>> _board = const [];
  int _difficulty = 0;
  int _score = 0;
  int _bestScore = 0;
  int _bestLevel = 0;
  bool _roundEnded = false;
  bool _scoreAddedThisRound = false;

  @override
  void initState() {
    super.initState();
    _loadBestStats();
    _newGame();
  }

  void _loadBestStats() {
    try {
      final String? bestScoreStr = localStorage.getItem(_bestScoreKey);
      final String? bestLevelStr = localStorage.getItem(_bestLevelKey);

      _bestScore = int.tryParse(bestScoreStr ?? '0') ?? 0;
      _bestLevel = int.tryParse(bestLevelStr ?? '0') ?? 0;
    } catch (_) {
      _bestScore = 0;
      _bestLevel = 0;
    }
  }

  void _saveBestStats() {
    try {
      localStorage.setItem(_bestScoreKey, _bestScore.toString());
      localStorage.setItem(_bestLevelKey, _bestLevel.toString());
    } catch (_) {
      // Keep gameplay smooth even if storage fails.
    }
  }

  void _updateBestStats() {
    var changed = false;

    if (_score > _bestScore) {
      _bestScore = _score;
      changed = true;
    }

    if (_difficulty > _bestLevel) {
      _bestLevel = _difficulty;
      changed = true;
    }

    if (changed) {
      _saveBestStats();
    }
  }

  void _newGame() {
    final mineCount = _baseMineCount + _difficulty;
    final minePositions = _getMinePositions(_boardSize, mineCount);

    setState(() {
      _roundEnded = false;
      _scoreAddedThisRound = false;
      _board = _createBoard(_boardSize, minePositions);
    });
  }

  List<List<_Tile>> _createBoard(
    int boardSize,
    List<Point<int>> minePositions,
  ) {
    return List.generate(boardSize, (x) {
      return List.generate(boardSize, (y) {
        final mine = minePositions.any((p) => p.x == x && p.y == y);
        return _Tile(x: x, y: y, mine: mine, status: _TileStatus.hidden);
      });
    });
  }

  List<Point<int>> _getMinePositions(int boardSize, int numberOfMines) {
    final positions = <Point<int>>[];

    while (positions.length < numberOfMines) {
      final position = Point<int>(
        _random.nextInt(boardSize),
        _random.nextInt(boardSize),
      );
      if (!positions.contains(position)) {
        positions.add(position);
      }
    }

    return positions;
  }

  int get _markedTilesCount {
    return _board.fold<int>(0, (count, row) {
      return count +
          row.where((tile) => tile.status == _TileStatus.marked).length;
    });
  }

  int get _minesLeft => (_baseMineCount + _difficulty) - _markedTilesCount;

  void _replaceTile(int x, int y, _Tile newTile) {
    _board = List.generate(_board.length, (rowIndex) {
      final row = _board[rowIndex];
      return List.generate(row.length, (colIndex) {
        if (rowIndex == x && colIndex == y) {
          return newTile;
        }
        return row[colIndex];
      });
    });
  }

  void _toggleMark(int x, int y) {
    if (_roundEnded) return;

    final tile = _board[x][y];
    if (tile.status != _TileStatus.hidden &&
        tile.status != _TileStatus.marked) {
      return;
    }

    setState(() {
      if (tile.status == _TileStatus.marked) {
        _replaceTile(x, y, tile.copyWith(status: _TileStatus.hidden));
      } else {
        _replaceTile(x, y, tile.copyWith(status: _TileStatus.marked));
      }
      _checkGameEnd();
    });
  }

  void _reveal(int x, int y) {
    if (_roundEnded) return;

    setState(() {
      _board = _revealTile(_board, x, y);
      _checkGameEnd();
    });
  }

  List<List<_Tile>> _revealTile(List<List<_Tile>> board, int x, int y) {
    final tile = board[x][y];

    if (tile.status != _TileStatus.hidden) {
      return board;
    }

    if (tile.mine) {
      return _replaceTileInBoard(
        board,
        x,
        y,
        tile.copyWith(status: _TileStatus.mine),
      );
    }

    final adjacentTiles = _nearbyTiles(board, x, y);
    final mines = adjacentTiles.where((t) => t.mine).length;
    var newBoard = _replaceTileInBoard(
      board,
      x,
      y,
      tile.copyWith(status: _TileStatus.number, adjacentMinesCount: mines),
    );

    if (mines == 0) {
      for (final adjacent in adjacentTiles) {
        newBoard = _revealTile(newBoard, adjacent.x, adjacent.y);
      }
    }

    return newBoard;
  }

  List<List<_Tile>> _replaceTileInBoard(
    List<List<_Tile>> board,
    int x,
    int y,
    _Tile newTile,
  ) {
    return List.generate(board.length, (rowIndex) {
      final row = board[rowIndex];
      return List.generate(row.length, (colIndex) {
        if (rowIndex == x && colIndex == y) {
          return newTile;
        }
        return row[colIndex];
      });
    });
  }

  List<_Tile> _nearbyTiles(List<List<_Tile>> board, int x, int y) {
    final tiles = <_Tile>[];

    for (int xOffset = -1; xOffset <= 1; xOffset++) {
      for (int yOffset = -1; yOffset <= 1; yOffset++) {
        final nextX = x + xOffset;
        final nextY = y + yOffset;

        if (nextX < 0 ||
            nextX >= board.length ||
            nextY < 0 ||
            nextY >= board[nextX].length) {
          continue;
        }

        tiles.add(board[nextX][nextY]);
      }
    }

    return tiles;
  }

  bool _checkWin(List<List<_Tile>> board) {
    return board.every((row) {
      return row.every((tile) {
        return tile.status == _TileStatus.number ||
            (tile.mine &&
                (tile.status == _TileStatus.hidden ||
                    tile.status == _TileStatus.marked));
      });
    });
  }

  bool _checkLose(List<List<_Tile>> board) {
    return board.any(
      (row) => row.any((tile) => tile.status == _TileStatus.mine),
    );
  }

  void _checkGameEnd() {
    if (_roundEnded) return;

    final win = _checkWin(_board);
    final lose = _checkLose(_board);

    if (win) {
      if (!_scoreAddedThisRound) {
        _difficulty += 1;
        final thisRoundScore = (_difficulty * 1.5 * 1000).round();
        _score += thisRoundScore;
        _updateBestStats();
        _scoreAddedThisRound = true;
        _roundEnded = true;

        _showStatus('You Win +$thisRoundScore');
        _scheduleNewRound();
      }
      return;
    }

    if (lose) {
      if (_difficulty > 0) {
        _difficulty -= 1;
      }

      _board = _revealAllMines(_board);
      _roundEnded = true;
      _showStatus('You Lose');
      _scheduleNewRound();
    }
  }

  List<List<_Tile>> _revealAllMines(List<List<_Tile>> board) {
    var newBoard = board;

    for (int x = 0; x < board.length; x++) {
      for (int y = 0; y < board[x].length; y++) {
        final tile = newBoard[x][y];

        if (tile.status == _TileStatus.marked) {
          newBoard = _replaceTileInBoard(
            newBoard,
            x,
            y,
            tile.copyWith(status: _TileStatus.hidden),
          );
        }

        final current = newBoard[x][y];
        if (current.mine) {
          newBoard = _replaceTileInBoard(
            newBoard,
            x,
            y,
            current.copyWith(status: _TileStatus.mine),
          );
        }
      }
    }

    return newBoard;
  }

  void _scheduleNewRound() {
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _newGame();
    });
  }

  void _showStatus(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1400),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Color _tileBackground(_Tile tile) {
    switch (tile.status) {
      case _TileStatus.hidden:
        return const Color(0xFFB8BDC8);
      case _TileStatus.marked:
        return const Color(0xFFFFD54F);
      case _TileStatus.mine:
        return const Color(0xFFE53935);
      case _TileStatus.number:
        return const Color(0xFF1D2130);
    }
  }

  String _tileText(_Tile tile) {
    switch (tile.status) {
      case _TileStatus.hidden:
        return '';
      case _TileStatus.marked:
        return 'F';
      case _TileStatus.mine:
        return 'X';
      case _TileStatus.number:
        return tile.adjacentMinesCount == 0 ? '' : '${tile.adjacentMinesCount}';
    }
  }

  Color _numberColor(int number) {
    switch (number) {
      case 1:
        return const Color(0xFF64B5F6);
      case 2:
        return const Color(0xFF81C784);
      case 3:
        return const Color(0xFFEF5350);
      case 4:
        return const Color(0xFF9575CD);
      case 5:
        return const Color(0xFFFF8A65);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tileSize = width < 420 ? 28.0 : 32.0;
    final boardPixelSize =
        (_boardSize * tileSize) + ((_boardSize - 1) * 4) + 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minesweeper'),
        actions: [
          TextButton.icon(
            onPressed: _newGame,
            icon: const Icon(Icons.refresh, color: Colors.white),
            label: const Text(
              'New Game',
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _StatChip(label: 'Points', value: '$_score'),
                    _StatChip(label: 'Level', value: '$_difficulty'),
                    _StatChip(label: 'Best Score', value: '$_bestScore'),
                    _StatChip(label: 'Best Level', value: '$_bestLevel'),
                    _StatChip(label: 'Mines Left', value: '$_minesLeft'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Tap to reveal. Long-press (or right click) to flag.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: Container(
                          width: boardPixelSize,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF737B8D),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: _boardSize * _boardSize,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: _boardSize,
                                  mainAxisExtent: tileSize,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                ),
                            itemBuilder: (context, index) {
                              final x = index ~/ _boardSize;
                              final y = index % _boardSize;
                              final tile = _board[x][y];
                              final isNumber =
                                  tile.status == _TileStatus.number;
                              final text = _tileText(tile);

                              return GestureDetector(
                                onTap: () => _reveal(x, y),
                                onLongPress: () => _toggleMark(x, y),
                                onSecondaryTap: () => _toggleMark(x, y),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _tileBackground(tile),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: tile.status == _TileStatus.hidden
                                            ? 0.5
                                            : 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: tileSize * 0.5,
                                      color: isNumber
                                          ? _numberColor(
                                              tile.adjacentMinesCount,
                                            )
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
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
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2336).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6FC3FF).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
