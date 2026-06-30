import 'dart:math';

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

const int _size = 9;
const int _box = 3;
const int _cellCount = _size * _size;

// Difficulty -> number of clues to keep in the generated puzzle. Fewer clues
// is harder. The digger may stop short of the target if going further would
// break the puzzle's unique solution.
enum _Difficulty { easy, medium, hard }

const Map<_Difficulty, int> _clueCounts = {
  _Difficulty.easy: 40,
  _Difficulty.medium: 32,
  _Difficulty.hard: 26,
};

final Random _random = Random();

int _boxIndex(int row, int col) {
  return (row ~/ _box) * _box + (col ~/ _box);
}

// Fisher–Yates in-place shuffle.
List<int> _shuffle(List<int> arr) {
  for (int i = arr.length - 1; i > 0; i--) {
    final j = _random.nextInt(i + 1);
    final tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

// Can `value` (1–9) be placed at flat `index` without violating Sudoku rules?
bool _canPlace(List<int> grid, int index, int value) {
  final r = index ~/ _size;
  final c = index % _size;
  for (int k = 0; k < _size; k++) {
    if (grid[r * _size + k] == value) return false;
    if (grid[k * _size + c] == value) return false;
    final br = (r ~/ _box) * _box + (k ~/ _box);
    final bc = (c ~/ _box) * _box + (k % _box);
    if (grid[br * _size + bc] == value) return false;
  }
  return true;
}

// Fill empty cells (0) with a complete valid solution using randomized
// backtracking. Mutates and returns true on success.
bool _fillGrid(List<int> grid) {
  final index = grid.indexOf(0);
  if (index == -1) return true;
  for (final value in _shuffle([1, 2, 3, 4, 5, 6, 7, 8, 9])) {
    if (_canPlace(grid, index, value)) {
      grid[index] = value;
      if (_fillGrid(grid)) return true;
      grid[index] = 0;
    }
  }
  return false;
}

List<int> _generateSolvedGrid() {
  final grid = List<int>.filled(_cellCount, 0);
  _fillGrid(grid);
  return grid;
}

// Count solutions of `grid`, stopping early once `limit` is reached. Used to
// confirm a dug-out puzzle still has exactly one solution.
int _countSolutions(List<int> grid, int limit) {
  final index = grid.indexOf(0);
  if (index == -1) return 1;
  int count = 0;
  for (int value = 1; value <= 9 && count < limit; value++) {
    if (_canPlace(grid, index, value)) {
      grid[index] = value;
      count += _countSolutions(grid, limit - count);
      grid[index] = 0;
    }
  }
  return count;
}

// Build a fresh puzzle: start from a full solution, then remove cells one at a
// time, keeping a removal only if the puzzle still has a unique solution.
// Returns both the dug-out puzzle and the full solution (used for hints).
({List<int> puzzle, List<int> solution}) _generatePuzzle(int targetClues) {
  final solution = _generateSolvedGrid();
  final puzzle = List<int>.of(solution);
  int clues = _cellCount;
  for (final index in _shuffle(List<int>.generate(_cellCount, (i) => i))) {
    if (clues <= targetClues) break;
    final backup = puzzle[index];
    puzzle[index] = 0;
    if (_countSolutions(List<int>.of(puzzle), 2) == 1) {
      clues--;
    } else {
      puzzle[index] = backup; // removal made the solution ambiguous; keep it
    }
  }
  return (puzzle: puzzle, solution: solution);
}

// One editable cell on the board.
class _Cell {
  const _Cell({required this.value, required this.given});

  final String value; // "" when empty, otherwise "1".."9"
  final bool given; // true for fixed clues that can't be edited

  _Cell copyWith({String? value, bool? given}) {
    return _Cell(value: value ?? this.value, given: given ?? this.given);
  }
}

// Turn a numeric puzzle grid (0 = empty) into the cell objects used by the UI.
List<_Cell> _buildCells(List<int> grid) {
  return grid
      .map((value) => _Cell(value: value == 0 ? '' : '$value', given: value != 0))
      .toList();
}

// Returns the set of cell indices that conflict with another cell sharing the
// same row, column, or 3×3 box. Empty cells never conflict.
Set<int> _findConflicts(List<_Cell> cells) {
  final conflicts = <int>{};

  void check(List<int> group) {
    final seen = <String, int>{};
    for (final idx in group) {
      final value = cells[idx].value;
      if (value.isEmpty) continue;
      if (seen.containsKey(value)) {
        conflicts.add(idx);
        conflicts.add(seen[value]!);
      } else {
        seen[value] = idx;
      }
    }
  }

  for (int i = 0; i < _size; i++) {
    final row = <int>[];
    final col = <int>[];
    final box = <int>[];
    for (int j = 0; j < _size; j++) {
      row.add(i * _size + j);
      col.add(j * _size + i);
      final r = (i ~/ _box) * _box + (j ~/ _box);
      final c = (i % _box) * _box + (j % _box);
      box.add(r * _size + c);
    }
    check(row);
    check(col);
    check(box);
  }

  return conflicts;
}

// Returns the set of cell indices belonging to a row, column, or 3×3 box that
// is fully filled and correct (its nine cells contain 1–9 with no repeats).
Set<int> _findCompletedCells(List<_Cell> cells) {
  final completed = <int>{};

  void markIfComplete(List<int> group) {
    final values = <String>{};
    for (final idx in group) {
      final value = cells[idx].value;
      if (value.isEmpty) return; // not fully filled
      values.add(value);
    }
    if (values.length == _size) {
      completed.addAll(group);
    }
  }

  for (int i = 0; i < _size; i++) {
    final row = <int>[];
    final col = <int>[];
    final box = <int>[];
    for (int j = 0; j < _size; j++) {
      row.add(i * _size + j);
      col.add(j * _size + i);
      final r = (i ~/ _box) * _box + (j ~/ _box);
      final c = (i % _box) * _box + (j % _box);
      box.add(r * _size + c);
    }
    markIfComplete(row);
    markIfComplete(col);
    markIfComplete(box);
  }

  return completed;
}

class _SudokuScreenState extends State<SudokuScreen> {
  static const String _solvedCountKey = 'sudoku_solved_count';

  _Difficulty _difficulty = _Difficulty.medium;
  // cells + solution kept together so they're always from the same puzzle.
  late List<_Cell> _cells;
  late List<int> _solution;
  int? _selected;
  bool _won = false;
  int _solvedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSolvedCount();
    _startNewGame(_difficulty);
  }

  void _loadSolvedCount() {
    try {
      final stored = localStorage.getItem(_solvedCountKey);
      _solvedCount = int.tryParse(stored ?? '0') ?? 0;
    } catch (_) {
      _solvedCount = 0;
    }
  }

  void _saveSolvedCount() {
    try {
      localStorage.setItem(_solvedCountKey, _solvedCount.toString());
    } catch (_) {
      // Keep gameplay smooth even if storage fails.
    }
  }

  void _startNewGame(_Difficulty level) {
    final generated = _generatePuzzle(_clueCounts[level]!);
    setState(() {
      _difficulty = level;
      _cells = _buildCells(generated.puzzle);
      _solution = generated.solution;
      _selected = null;
      _won = false;
    });
  }

  // Apply a value to the selected cell, then re-check for a win.
  void _setCellValue(int index, String value) {
    if (_cells[index].given) return;
    if (_cells[index].value == value) return;
    setState(() {
      _cells = List<_Cell>.of(_cells);
      _cells[index] = _cells[index].copyWith(value: value);
      _checkWin();
    });
  }

  void _checkWin() {
    final filled = _cells.every((cell) => cell.value.isNotEmpty);
    if (!filled) return;
    if (_findConflicts(_cells).isNotEmpty) return;
    _won = true;
    _solvedCount += 1;
    _saveSolvedCount();
  }

  void _handlePadInput(String value) {
    final selected = _selected;
    if (selected == null || _won) return;
    if (_cells[selected].given) return;
    _setCellValue(selected, value);
  }

  // Fill one randomly chosen empty-or-incorrect cell with its solution value.
  void _handleHint() {
    if (_won) return;
    final candidates = <int>[];
    for (int i = 0; i < _cells.length; i++) {
      if (!_cells[i].given && _cells[i].value != '${_solution[i]}') {
        candidates.add(i);
      }
    }
    if (candidates.isEmpty) return;
    final index = candidates[_random.nextInt(candidates.length)];
    _setCellValue(index, '${_solution[index]}');
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _findConflicts(_cells);
    final completed = _findCompletedCells(_cells);
    final width = MediaQuery.of(context).size.width;
    final boardSize = min(width - 32, 460).toDouble();
    final selected = _selected;
    final padDisabled =
        selected == null || _won || (_cells[selected].given);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          TextButton.icon(
            onPressed: () => _startNewGame(_difficulty),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Tap a cell, then pick a number. Use Erase to clear.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                _buildDifficultySelector(),
                const SizedBox(height: 8),
                _SolvedChip(count: _solvedCount),
                const SizedBox(height: 16),
                _buildBoard(boardSize, conflicts, completed),
                const SizedBox(height: 16),
                if (_won) ...[
                  _buildWinBanner(),
                  const SizedBox(height: 16),
                ],
                _buildNumberPad(padDisabled),
                const SizedBox(height: 16),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return SegmentedButton<_Difficulty>(
      segments: const [
        ButtonSegment(value: _Difficulty.easy, label: Text('Easy')),
        ButtonSegment(value: _Difficulty.medium, label: Text('Medium')),
        ButtonSegment(value: _Difficulty.hard, label: Text('Hard')),
      ],
      selected: {_difficulty},
      onSelectionChanged: (selection) => _startNewGame(selection.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF7B2CBF);
          }
          return const Color(0xFF1C2336).withValues(alpha: 0.85);
        }),
        foregroundColor: WidgetStateProperty.all(Colors.white),
        side: WidgetStateProperty.all(
          BorderSide(color: const Color(0xFF00F2FE).withValues(alpha: 0.35)),
        ),
      ),
    );
  }

  Widget _buildBoard(
    double boardSize,
    Set<int> conflicts,
    Set<int> completed,
  ) {
    const neon = Color(0xFF00F2FE);
    return Container(
      width: boardSize,
      height: boardSize,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1320),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: neon, width: 2),
        boxShadow: [
          BoxShadow(
            color: neon.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _cellCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _size,
        ),
        itemBuilder: (context, index) {
          return _buildCell(index, conflicts, completed);
        },
      ),
    );
  }

  Widget _buildCell(int index, Set<int> conflicts, Set<int> completed) {
    const neon = Color(0xFF00F2FE);
    const thick = 2.0;
    const thin = 0.5;

    final row = index ~/ _size;
    final col = index % _size;
    final cell = _cells[index];
    final isSelected = _selected == index;
    final isConflict = conflicts.contains(index);
    final isCompleted = completed.contains(index) && !isConflict;

    // Subtle checkerboard tint per 3×3 box so the nine boxes read distinctly.
    final boxTinted = _boxIndex(row, col).isEven;
    Color background = boxTinted
        ? const Color(0xFF161D2E)
        : const Color(0xFF101623);
    if (isConflict) {
      background = const Color(0xFFE53935).withValues(alpha: 0.85);
    } else if (isSelected) {
      background = const Color(0xFF7B2CBF).withValues(alpha: 0.55);
    } else if (isCompleted) {
      background = const Color(0xFF1B5E20).withValues(alpha: 0.55);
    }

    // Thicker neon borders on 3×3 box boundaries; thin elsewhere.
    final borderColor = neon.withValues(alpha: 0.6);
    final faint = Colors.white.withValues(alpha: 0.12);
    final border = Border(
      left: BorderSide(
        color: col % _box == 0 ? borderColor : faint,
        width: col % _box == 0 ? thick : thin,
      ),
      top: BorderSide(
        color: row % _box == 0 ? borderColor : faint,
        width: row % _box == 0 ? thick : thin,
      ),
      right: BorderSide(
        color: col == _size - 1 ? borderColor : faint,
        width: col == _size - 1 ? thick : thin,
      ),
      bottom: BorderSide(
        color: row == _size - 1 ? borderColor : faint,
        width: row == _size - 1 ? thick : thin,
      ),
    );

    Color textColor;
    if (isConflict) {
      textColor = Colors.white;
    } else if (cell.given) {
      textColor = Colors.white;
    } else if (isCompleted) {
      textColor = const Color(0xFF69F0AE);
    } else {
      textColor = neon;
    }

    return GestureDetector(
      onTap: _won ? null : () => setState(() => _selected = index),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, border: border),
        child: Text(
          cell.value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: cell.given ? FontWeight.w800 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad(bool disabled) {
    final digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final digit in digits)
              _PadButton(
                label: digit,
                disabled: disabled,
                onTap: () => _handlePadInput(digit),
              ),
            _PadButton(
              label: '⌫',
              disabled: disabled,
              onTap: () => _handlePadInput(''),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _won ? null : _handleHint,
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Hint'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00F2FE),
            side: BorderSide(
              color: const Color(0xFF00F2FE).withValues(alpha: 0.6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _startNewGame(_difficulty),
          icon: const Icon(Icons.refresh),
          label: const Text('New Game'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7B2CBF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildWinBanner() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF00F2FE),
          Color(0xFF69F0AE),
          Color(0xFFC0A6FF),
          Color(0xFF7B2CBF),
        ],
      ).createShader(bounds),
      child: const Text(
        '🎉 You Win! 🎉',
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({
    required this.label,
    required this.disabled,
    required this.onTap,
  });

  final String label;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: ElevatedButton(
        onPressed: disabled ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF1C2336),
          foregroundColor: const Color(0xFF00F2FE),
          disabledBackgroundColor:
              const Color(0xFF1C2336).withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: const Color(0xFF00F2FE).withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _SolvedChip extends StatelessWidget {
  const _SolvedChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2336).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF6FC3FF).withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        'SOLVED: $count',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
