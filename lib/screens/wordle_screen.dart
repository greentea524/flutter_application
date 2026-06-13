import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localstorage/localstorage.dart';
import '../wordle_words.dart';

// Tile state
enum TileState { empty, active, correct, wrongLocation, wrong }

// Key state (for on-screen keyboard coloring)
enum KeyState { unused, correct, wrongLocation, wrong }

class WordleScreen extends StatefulWidget {
  const WordleScreen({super.key});

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> with TickerProviderStateMixin {
  static const int wordLength = 5;
  static const int maxGuesses = 6;

  late String _targetWord;
  List<List<String>> _grid = []; // 6 rows x 5 columns of letters
  List<List<TileState>> _tileStates = [];
  Map<String, KeyState> _keyStates = {};
  List<List<AnimationController>> _flipControllers = [];
  List<List<AnimationController>> _shakeControllers = [];
  List<List<AnimationController>> _bounceControllers = [];

  int _currentRow = 0;
  int _currentCol = 0;
  bool _gameOver = false;
  bool _interactionLocked = false; // lock while flip animations play

  Set<String> _dictionary = {};
  bool _dictionaryLoaded = false;

  String? _alertMessage;
  AnimationController? _alertController;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadDictionary();
  }

  void _initGame() {
    // Pick a target word based on the day (same as original JS logic)
    final offsetFromDate = DateTime(2022, 1, 1);
    final dayOffset = DateTime.now().difference(offsetFromDate).inDays;
    _targetWord = kTargetWords[dayOffset % kTargetWords.length];

    _grid = List.generate(maxGuesses, (_) => List.filled(wordLength, ''));
    _tileStates = List.generate(maxGuesses, (_) => List.filled(wordLength, TileState.empty));
    _keyStates = {};
    _currentRow = 0;
    _currentCol = 0;
    _gameOver = false;
    _interactionLocked = false;
    _alertMessage = null;

    // Dispose old controllers
    for (final row in _flipControllers) {
      for (final c in row) { c.dispose(); }
    }
    for (final row in _shakeControllers) {
      for (final c in row) { c.dispose(); }
    }
    for (final row in _bounceControllers) {
      for (final c in row) { c.dispose(); }
    }

    _flipControllers = List.generate(maxGuesses, (_) => List.generate(wordLength, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250))));
    _shakeControllers = List.generate(maxGuesses, (_) => List.generate(wordLength, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300))));
    _bounceControllers = List.generate(maxGuesses, (_) => List.generate(wordLength, (_) =>
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500))));
    
    _alertController?.dispose();
    _alertController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  Future<void> _loadDictionary() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/wordle_dictionary.json');
      final List<dynamic> words = jsonDecode(jsonStr);
      setState(() {
        _dictionary = words.cast<String>().toSet();
        _dictionaryLoaded = true;
      });
    } catch (e) {
      setState(() {
        _dictionaryLoaded = true; // allow play even if load fails
      });
    }
  }

  @override
  void dispose() {
    for (final row in _flipControllers) {
      for (final c in row) { c.dispose(); }
    }
    for (final row in _shakeControllers) {
      for (final c in row) { c.dispose(); }
    }
    for (final row in _bounceControllers) {
      for (final c in row) { c.dispose(); }
    }
    _alertController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _pressKey(String key) {
    if (_gameOver || _interactionLocked) return;
    if (_currentCol >= wordLength) return;
    setState(() {
      _grid[_currentRow][_currentCol] = key;
      _tileStates[_currentRow][_currentCol] = TileState.active;
      _currentCol++;
    });
  }

  void _deleteKey() {
    if (_gameOver || _interactionLocked) return;
    if (_currentCol <= 0) return;
    setState(() {
      _currentCol--;
      _grid[_currentRow][_currentCol] = '';
      _tileStates[_currentRow][_currentCol] = TileState.empty;
    });
  }

  Future<void> _submitGuess() async {
    if (_gameOver || _interactionLocked) return;
    if (_currentCol < wordLength) {
      _showAlert('Not enough letters');
      _shakeRow(_currentRow);
      return;
    }

    final guess = _grid[_currentRow].join('').toLowerCase();

    if (_dictionaryLoaded && _dictionary.isNotEmpty && !_dictionary.contains(guess)) {
      _showAlert('Not in word list');
      _shakeRow(_currentRow);
      return;
    }

    _interactionLocked = true;
    await _flipRow(_currentRow, guess);
    _interactionLocked = false;

    final won = guess == _targetWord;

    if (won) {
      _showAlert('Brilliant! 🎉', duration: 4000);
      await Future.delayed(const Duration(milliseconds: 400));
      _bounceRow(_currentRow);
      setState(() { _gameOver = true; });
      _saveStats(won: true);
    } else if (_currentRow >= maxGuesses - 1) {
      _showAlert(_targetWord.toUpperCase(), duration: null);
      setState(() { _gameOver = true; });
      _saveStats(won: false);
    } else {
      setState(() {
        _currentRow++;
        _currentCol = 0;
      });
    }
  }

  Future<void> _flipRow(int row, String guess) async {
    final target = _targetWord;
    // Calculate tile states first (accounting for duplicate letters correctly)
    final result = List.filled(wordLength, TileState.wrong);
    final targetLetterCount = <String, int>{};
    for (var c in target.split('')) {
      targetLetterCount[c] = (targetLetterCount[c] ?? 0) + 1;
    }

    // First pass: mark correct
    for (int i = 0; i < wordLength; i++) {
      if (guess[i] == target[i]) {
        result[i] = TileState.correct;
        targetLetterCount[guess[i]] = targetLetterCount[guess[i]]! - 1;
      }
    }

    // Second pass: mark wrong-location
    for (int i = 0; i < wordLength; i++) {
      if (result[i] == TileState.correct) continue;
      if ((targetLetterCount[guess[i]] ?? 0) > 0) {
        result[i] = TileState.wrongLocation;
        targetLetterCount[guess[i]] = targetLetterCount[guess[i]]! - 1;
      }
    }

    // Animate each tile with staggered flip
    for (int i = 0; i < wordLength; i++) {
      await Future.delayed(Duration(milliseconds: i * 250));
      final controller = _flipControllers[row][i];
      // Flip to 90deg (hide), update state, flip back
      await controller.forward();
      setState(() {
        _tileStates[row][i] = result[i];
        // Update key state (only upgrade, never downgrade)
        final letter = guess[i];
        final current = _keyStates[letter] ?? KeyState.unused;
        if (result[i] == TileState.correct) {
          _keyStates[letter] = KeyState.correct;
        } else if (result[i] == TileState.wrongLocation && current != KeyState.correct) {
          _keyStates[letter] = KeyState.wrongLocation;
        } else if (result[i] == TileState.wrong && current == KeyState.unused) {
          _keyStates[letter] = KeyState.wrong;
        }
      });
      await controller.reverse();
    }
  }

  void _shakeRow(int row) {
    for (int i = 0; i < wordLength; i++) {
      final c = _shakeControllers[row][i];
      c.forward(from: 0).then((_) => c.reverse());
    }
  }

  void _bounceRow(int row) {
    for (int i = 0; i < wordLength; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          final c = _bounceControllers[row][i];
          c.forward(from: 0).then((_) => c.reverse());
        }
      });
    }
  }

  void _showAlert(String message, {int? duration = 1500}) {
    setState(() { _alertMessage = message; });
    _alertController?.forward(from: 0);
    if (duration != null) {
      Future.delayed(Duration(milliseconds: duration), () {
        if (mounted) {
          setState(() { _alertMessage = null; });
        }
      });
    }
  }

  void _saveStats({required bool won}) {
    try {
      final wins = int.tryParse(localStorage.getItem('wordle_wins') ?? '0') ?? 0;
      final games = int.tryParse(localStorage.getItem('wordle_games') ?? '0') ?? 0;
      localStorage.setItem('wordle_games', (games + 1).toString());
      if (won) localStorage.setItem('wordle_wins', (wins + 1).toString());
    } catch (_) {}
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      _submitGuess();
    } else if (key == LogicalKeyboardKey.backspace || key == LogicalKeyboardKey.delete) {
      _deleteKey();
    } else {
      final char = event.character;
      if (char != null && RegExp(r'^[a-zA-Z]$').hasMatch(char)) {
        _pressKey(char.toUpperCase());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    return Scaffold(
      backgroundColor: const Color(0xFF121213),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              if (_alertMessage != null) _buildAlert(),
              const SizedBox(height: 8),
              Expanded(child: _buildGrid()),
              const SizedBox(height: 8),
              _buildKeyboard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF3A3A3C), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'WORDLE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() { _initGame(); });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlert() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD7DADC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _alertMessage!,
        style: const TextStyle(
          color: Color(0xFF121213),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxGuesses, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(wordLength, (col) {
            return _buildTile(row, col);
          }),
        );
      }),
    );
  }

  Widget _buildTile(int row, int col) {
    final letter = _grid[row][col];
    final state = _tileStates[row][col];
    final flipAnim = _flipControllers[row][col];
    final shakeAnim = _shakeControllers[row][col];
    final bounceAnim = _bounceControllers[row][col];

    Color bgColor;
    Color borderColor;
    switch (state) {
      case TileState.correct:
        bgColor = const Color(0xFF538D4E);
        borderColor = const Color(0xFF538D4E);
        break;
      case TileState.wrongLocation:
        bgColor = const Color(0xFFB59F3B);
        borderColor = const Color(0xFFB59F3B);
        break;
      case TileState.wrong:
        bgColor = const Color(0xFF3A3A3C);
        borderColor = const Color(0xFF3A3A3C);
        break;
      case TileState.active:
        bgColor = Colors.transparent;
        borderColor = const Color(0xFF565758);
        break;
      case TileState.empty:
        bgColor = Colors.transparent;
        borderColor = const Color(0xFF3A3A3C);
    }

    return AnimatedBuilder(
      animation: Listenable.merge([flipAnim, shakeAnim, bounceAnim]),
      builder: (context, child) {
        // Flip: 0 → 1 means rotating to 90deg (hide), then reversing back
        final flipValue = flipAnim.value;
        // Shake: oscillate left-right
        final shakeValue = (math.sin(shakeAnim.value * math.pi * 4) * 4.0);
        // Bounce: jump up
        final bounceValue = -(math.sin(bounceAnim.value * math.pi) * 12.0);

        return Transform.translate(
          offset: Offset(shakeValue, bounceValue),
          child: Transform(
            transform: Matrix4.rotationX(flipValue * (math.pi / 2)),
            alignment: Alignment.center,
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border.all(color: borderColor, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                letter,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeyboard() {
    const row1 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'];
    const row2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'];
    const row3 = ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', '⌫'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildKeyRow(row1),
          const SizedBox(height: 8),
          _buildKeyRow(row2),
          const SizedBox(height: 8),
          _buildKeyRow(row3),
        ],
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) => _buildKey(key)).toList(),
    );
  }

  Widget _buildKey(String key) {
    final isLarge = key == 'ENTER' || key == '⌫';
    final keyState = _keyStates[key] ?? KeyState.unused;

    Color bgColor;
    switch (keyState) {
      case KeyState.correct:
        bgColor = const Color(0xFF538D4E);
        break;
      case KeyState.wrongLocation:
        bgColor = const Color(0xFFB59F3B);
        break;
      case KeyState.wrong:
        bgColor = const Color(0xFF3A3A3C);
        break;
      case KeyState.unused:
        bgColor = const Color(0xFF818384);
    }

    return GestureDetector(
      onTap: () {
        if (key == 'ENTER') {
          _submitGuess();
        } else if (key == '⌫') {
          _deleteKey();
        } else {
          _pressKey(key);
        }
        _focusNode.requestFocus();
      },
      child: Container(
        width: isLarge ? 56 : 36,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          key,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 11 : 16,
          ),
        ),
      ),
    );
  }
}
