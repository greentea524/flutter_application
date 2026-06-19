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

class _WordleScreenState extends State<WordleScreen>
    with TickerProviderStateMixin {
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

  int _gamesPlayed = 0;
  int _gamesWon = 0;
  int _totalScore = 0;
  int _wordShift = 0;
  final Map<int, int> _winsByGuess = {
    for (int guess = 1; guess <= maxGuesses; guess++) guess: 0,
  };

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initGame();
    _loadDictionary();
    _loadStats();
  }

  void _initGame() {
    // Pick a target word based on the day (same as original JS logic)
    final offsetFromDate = DateTime(2022, 1, 1);
    final dayOffset = DateTime.now().difference(offsetFromDate).inDays;
    final wordIndex = (dayOffset + _wordShift) % kTargetWords.length;
    _targetWord = kTargetWords[wordIndex];

    _grid = List.generate(maxGuesses, (_) => List.filled(wordLength, ''));
    _tileStates = List.generate(
      maxGuesses,
      (_) => List.filled(wordLength, TileState.empty),
    );
    _keyStates = {};
    _currentRow = 0;
    _currentCol = 0;
    _gameOver = false;
    _interactionLocked = false;
    _alertMessage = null;

    // Dispose old controllers
    for (final row in _flipControllers) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _shakeControllers) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _bounceControllers) {
      for (final c in row) {
        c.dispose();
      }
    }

    _flipControllers = List.generate(
      maxGuesses,
      (_) => List.generate(
        wordLength,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        ),
      ),
    );
    _shakeControllers = List.generate(
      maxGuesses,
      (_) => List.generate(
        wordLength,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
    _bounceControllers = List.generate(
      maxGuesses,
      (_) => List.generate(
        wordLength,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        ),
      ),
    );

    _alertController?.dispose();
    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _loadStats() async {
    try {
      final games =
          int.tryParse(localStorage.getItem('wordle_games') ?? '0') ?? 0;
      final wins =
          int.tryParse(localStorage.getItem('wordle_wins') ?? '0') ?? 0;
      final totalScore =
          int.tryParse(localStorage.getItem('wordle_total_score') ?? '0') ?? 0;

      final guessWins = <int, int>{};
      for (int guess = 1; guess <= maxGuesses; guess++) {
        guessWins[guess] =
            int.tryParse(localStorage.getItem('wordle_guess_$guess') ?? '0') ??
            0;
      }

      if (!mounted) return;
      setState(() {
        _gamesPlayed = games;
        _gamesWon = wins;
        _totalScore = totalScore;
        _winsByGuess
          ..clear()
          ..addAll(guessWins);
      });
    } catch (_) {}
  }

  int _scoreForGuess(int guessNumber) {
    if (guessNumber < 1 || guessNumber > maxGuesses) return 0;
    return (((maxGuesses - guessNumber + 1) / maxGuesses) * 100).round();
  }

  double _guessWinRate(int guessNumber) {
    if (_gamesWon == 0) return 0;
    final guessWins = _winsByGuess[guessNumber] ?? 0;
    return (guessWins / _gamesWon) * 100;
  }

  void _startNextGame() {
    setState(() {
      _wordShift++;
      _initGame();
    });
  }

  void _revealOneLetterHint() {
    if (_gameOver || _interactionLocked) return;
    if (_currentCol >= wordLength) {
      _showAlert('Row is full. Submit guess');
      return;
    }

    setState(() {
      final targetLetter = _targetWord[_currentCol].toUpperCase();
      _grid[_currentRow][_currentCol] = targetLetter;
      _tileStates[_currentRow][_currentCol] = TileState.active;
      _currentCol++;
    });
    _showAlert('1 letter revealed');
  }

  void _revealFullWordHint() {
    if (_gameOver || _interactionLocked) return;

    setState(() {
      for (int i = 0; i < wordLength; i++) {
        _grid[_currentRow][i] = _targetWord[i].toUpperCase();
        _tileStates[_currentRow][i] = TileState.active;
      }
      _currentCol = wordLength;
    });
    _showAlert('Full word revealed');
  }

  void _resetGameWithRandomWord() {
    final offsetFromDate = DateTime(2022, 1, 1);
    final dayOffset = DateTime.now().difference(offsetFromDate).inDays;
    final currentWordIndex = (dayOffset + _wordShift) % kTargetWords.length;

    if (kTargetWords.length <= 1) {
      _wordShift = 0;
      _initGame();
      return;
    }

    final random = math.Random();
    var randomWordIndex = currentWordIndex;
    while (randomWordIndex == currentWordIndex) {
      randomWordIndex = random.nextInt(kTargetWords.length);
    }

    _wordShift = (randomWordIndex - dayOffset) % kTargetWords.length;
    if (_wordShift < 0) {
      _wordShift += kTargetWords.length;
    }

    _initGame();
  }

  void _resetStats() {
    try {
      localStorage.setItem('wordle_games', '0');
      localStorage.setItem('wordle_wins', '0');
      localStorage.setItem('wordle_total_score', '0');
      for (int guess = 1; guess <= maxGuesses; guess++) {
        localStorage.setItem('wordle_guess_$guess', '0');
      }

      if (!mounted) return;
      setState(() {
        _gamesPlayed = 0;
        _gamesWon = 0;
        _totalScore = 0;
        for (int guess = 1; guess <= maxGuesses; guess++) {
          _winsByGuess[guess] = 0;
        }
      });

      _showAlert('Stats reset');
    } catch (_) {}
  }

  Future<void> _loadDictionary() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/wordle_dictionary.json',
      );
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
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _shakeControllers) {
      for (final c in row) {
        c.dispose();
      }
    }
    for (final row in _bounceControllers) {
      for (final c in row) {
        c.dispose();
      }
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

    if (_dictionaryLoaded &&
        _dictionary.isNotEmpty &&
        !_dictionary.contains(guess)) {
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
      setState(() {
        _gameOver = true;
      });
      _saveStats(won: true, guessNumber: _currentRow + 1);
    } else if (_currentRow >= maxGuesses - 1) {
      _showAlert(_targetWord.toUpperCase(), duration: null);
      setState(() {
        _gameOver = true;
      });
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
        } else if (result[i] == TileState.wrongLocation &&
            current != KeyState.correct) {
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
    setState(() {
      _alertMessage = message;
    });
    _alertController?.forward(from: 0);
    if (duration != null) {
      Future.delayed(Duration(milliseconds: duration), () {
        if (mounted) {
          setState(() {
            _alertMessage = null;
          });
        }
      });
    }
  }

  void _saveStats({required bool won, int? guessNumber}) {
    try {
      final games =
          int.tryParse(localStorage.getItem('wordle_games') ?? '0') ?? 0;
      final wins =
          int.tryParse(localStorage.getItem('wordle_wins') ?? '0') ?? 0;
      final totalScore =
          int.tryParse(localStorage.getItem('wordle_total_score') ?? '0') ?? 0;

      final updatedGames = games + 1;
      var updatedWins = wins;
      var updatedScore = totalScore;

      localStorage.setItem('wordle_games', (games + 1).toString());
      if (won) {
        updatedWins = wins + 1;
        localStorage.setItem('wordle_wins', updatedWins.toString());

        if (guessNumber != null) {
          final key = 'wordle_guess_$guessNumber';
          final currentGuessWins =
              int.tryParse(localStorage.getItem(key) ?? '0') ?? 0;
          localStorage.setItem(key, (currentGuessWins + 1).toString());
          updatedScore += _scoreForGuess(guessNumber);
        }
      }

      localStorage.setItem('wordle_total_score', updatedScore.toString());

      if (!mounted) return;
      setState(() {
        _gamesPlayed = updatedGames;
        _gamesWon = updatedWins;
        _totalScore = updatedScore;
        if (won && guessNumber != null) {
          _winsByGuess[guessNumber] = (_winsByGuess[guessNumber] ?? 0) + 1;
        }
      });
    } catch (_) {}
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter) {
      _submitGuess();
    } else if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      if (_alertMessage != null) _buildAlert(),
                      _buildStatsPanel(),
                      if (_gameOver) _buildGameOverActions(),
                      const SizedBox(height: 8),
                      _buildGrid(),
                      const SizedBox(height: 8),
                      _buildKeyboard(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
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
              setState(() {
                _resetGameWithRandomWord();
              });
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

  Widget _buildStatsPanel() {
    final overallWinRate = _gamesPlayed == 0
        ? 0
        : (_gamesWon / _gamesPlayed) * 100;
    final averageScore = _gamesWon == 0 ? 0 : (_totalScore / _gamesWon);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score: $_totalScore  |  Games: $_gamesPlayed  |  Wins: $_gamesWon',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Overall Win Rate: ${overallWinRate.toStringAsFixed(1)}%  |  Avg Score: ${averageScore.toStringAsFixed(1)}',
            style: const TextStyle(color: Color(0xFFD7DADC), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(maxGuesses, (index) {
              final guessNumber = index + 1;
              final guessWins = _winsByGuess[guessNumber] ?? 0;
              final rate = _guessWinRate(guessNumber);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'G$guessNumber: $guessWins (${rate.toStringAsFixed(1)}%)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          _buildHintPanel(),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _resetStats,
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Reset Stats'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD7DADC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintPanel() {
    final hintsDisabled = _gameOver || _interactionLocked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF222225),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Helpline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: hintsDisabled ? null : _revealOneLetterHint,
                icon: const Icon(Icons.lightbulb_outline, size: 18),
                label: const Text('Reveal 1 Letter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD7DADC),
                  side: const BorderSide(color: Color(0xFF565758)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: hintsDisabled ? null : _revealFullWordHint,
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Reveal Full Word'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD7DADC),
                  side: const BorderSide(color: Color(0xFF565758)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ElevatedButton.icon(
        onPressed: _startNextGame,
        icon: const Icon(Icons.skip_next),
        label: const Text('Next Game'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF538D4E),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
