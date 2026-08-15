// Big 2 (大老二) 4-Player Table UI & Interactive Gameplay Screen — #14
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../big2_deck.dart';
import '../big2_rules.dart';
import '../big2_bot.dart';
import '../big2_game.dart';

const List<String> kBig2PlayerNames = ['You', 'West 🤖', 'North 🤖', 'East 🤖'];
const int kLocalPlayer = 0;

class Big2Screen extends StatefulWidget {
  const Big2Screen({super.key});

  @override
  State<Big2Screen> createState() => _Big2ScreenState();
}

class _Big2ScreenState extends State<Big2Screen> with SingleTickerProviderStateMixin {
  late Big2GameState _gameState;
  final Set<String> _selectedCardIds = {};
  String _sortMode = 'rank'; // 'rank' or 'suit'
  final List<int> _cumulativeScores = [0, 0, 0, 0];
  int _round = 1;
  bool _isPaused = false;
  Timer? _botTimer;
  Timer? _autoPassTimer;
  String? _statusBanner;

  @override
  void initState() {
    super.initState();
    _startNewRound(isInitial: true);
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _autoPassTimer?.cancel();
    super.dispose();
  }

  void _startNewRound({bool isInitial = false}) {
    _botTimer?.cancel();
    _autoPassTimer?.cancel();
    setState(() {
      if (!isInitial) {
        _round++;
      }
      _gameState = Big2GameState.newGame();
      _selectedCardIds.clear();
      _statusBanner = null;
    });
    _checkBotTurn();
  }

  void _checkBotTurn() {
    if (_isPaused || _gameState.winner != null) return;

    final currentTurn = _gameState.turn;

    // Check if it's the human player's turn with an unbeatable trick on table
    if (currentTurn == kLocalPlayer) {
      if (_gameState.trick != null && Big2Rules.isUnbeatable(_gameState.trick!.cards)) {
        _statusBanner = 'Trick is unbeatable! Auto-passing...';
        _autoPassTimer = Timer(const Duration(milliseconds: 1100), () {
          if (mounted && _gameState.turn == kLocalPlayer && _gameState.winner == null) {
            _onPass();
          }
        });
      }
      return;
    }

    // Bot turn with natural randomized delay (700-1100 ms)
    final delayMs = 750 + math.Random().nextInt(350);
    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || _isPaused || _gameState.winner != null || _gameState.turn == kLocalPlayer) {
        return;
      }

      final botHand = _gameState.hands[_gameState.turn];
      final move = Big2Bot.chooseBotMove(botHand, _gameState.trick?.cards);

      setState(() {
        if (move.isPlay) {
          _gameState = _gameState.playCards(move.cardIds);
          HapticFeedback.selectionClick();
        } else {
          _gameState = _gameState.passTurn();
        }
      });

      _checkBotTurn();
    });
  }

  void _toggleCardSelection(String cardId) {
    if (_gameState.winner != null || _gameState.turn != kLocalPlayer) return;
    setState(() {
      if (_selectedCardIds.contains(cardId)) {
        _selectedCardIds.remove(cardId);
      } else {
        _selectedCardIds.add(cardId);
      }
      HapticFeedback.selectionClick();
    });
  }

  void _onPlay() {
    if (_gameState.turn != kLocalPlayer || _gameState.winner != null) return;

    final myHand = _gameState.hands[kLocalPlayer];
    final selectedCards = myHand.where((c) => _selectedCardIds.contains(c.id)).toList();

    if (!Big2Rules.canBeat(selectedCards, _gameState.trick?.cards)) return;

    setState(() {
      _gameState = _gameState.playCards(_selectedCardIds.toList());
      _selectedCardIds.clear();
      _statusBanner = null;
      HapticFeedback.mediumImpact();
    });

    _checkBotTurn();
  }

  void _onPass() {
    if (_gameState.turn != kLocalPlayer || _gameState.winner != null) return;
    if (!Big2Rules.canPass(_gameState.trick?.cards)) return;

    setState(() {
      _gameState = _gameState.passTurn();
      _selectedCardIds.clear();
      _statusBanner = null;
      HapticFeedback.lightImpact();
    });

    _checkBotTurn();
  }

  @override
  Widget build(BuildContext context) {
    final myHand = _gameState.hands[kLocalPlayer];
    final displayHand = _sortMode == 'suit'
        ? Big2Deck.sortHandBySuit(myHand)
        : Big2Deck.sortHand(myHand);

    final selectedCards = myHand.where((c) => _selectedCardIds.contains(c.id)).toList();
    final combination = Big2Rules.classifyHand(selectedCards);
    final isMyTurn = _gameState.turn == kLocalPlayer && _gameState.winner == null;
    final canPlay = isMyTurn && Big2Rules.canBeat(selectedCards, _gameState.trick?.cards);
    final canPass = isMyTurn && Big2Rules.canPass(_gameState.trick?.cards);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 2,
        title: Row(
          children: [
            const Text(
              '🎴 Big Two (大老二)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Round $_round',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white70),
            tooltip: _isPaused ? 'Resume' : 'Pause',
            onPressed: () {
              setState(() {
                _isPaused = !_isPaused;
                if (!_isPaused) {
                  _checkBotTurn();
                } else {
                  _botTimer?.cancel();
                  _autoPassTimer?.cancel();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            tooltip: 'Rules & Combinations',
            onPressed: _showRulesDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'New Game',
            onPressed: () {
              _startNewRound();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.2,
              colors: [
                Color(0xFF1B4D2E), // Green felt center
                Color(0xFF0F321C),
                Color(0xFF071B0E),
              ],
            ),
          ),
          child: Column(
            children: [
              // Top Seat: North Bot
              _buildOpponentSeat(
                playerIndex: 2,
                positionLabel: 'North',
                alignment: Alignment.topCenter,
              ),

              // Middle Row: West Bot, Center Trick Table, East Bot
              Expanded(
                child: Row(
                  children: [
                    // West Bot
                    SizedBox(
                      width: 100,
                      child: _buildOpponentSeat(
                        playerIndex: 1,
                        positionLabel: 'West',
                        isVertical: true,
                        alignment: Alignment.centerLeft,
                      ),
                    ),

                    // Center Felt Trick Arena
                    Expanded(
                      child: _buildCenterArena(),
                    ),

                    // East Bot
                    SizedBox(
                      width: 100,
                      child: _buildOpponentSeat(
                        playerIndex: 3,
                        positionLabel: 'East',
                        isVertical: true,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Seat: Local Human Player
              _buildSouthPlayerSection(
                displayHand: displayHand,
                combination: combination,
                canPlay: canPlay,
                canPass: canPass,
                isMyTurn: isMyTurn,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpponentSeat({
    required int playerIndex,
    required String positionLabel,
    bool isVertical = false,
    required Alignment alignment,
  }) {
    final isTurn = _gameState.turn == playerIndex && _gameState.winner == null;
    final cardCount = _gameState.hands[playerIndex].length;
    final name = kBig2PlayerNames[playerIndex];
    final score = _cumulativeScores[playerIndex];

    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isTurn
            ? Colors.amber.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isTurn ? Colors.amber : Colors.white12,
          width: isTurn ? 2 : 1,
        ),
        boxShadow: isTurn
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTurn ? Colors.amber : Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                _buildScorePill(score),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: cardCount <= 2 ? Colors.redAccent : Colors.blueGrey.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$cardCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isTurn) ...[
            const SizedBox(height: 2),
            const Text(
              'Thinking...',
              style: TextStyle(fontSize: 9, color: Colors.amberAccent, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 4),
          // Compact overlapping stack of face-down cards
          SizedBox(
            height: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                math.min(cardCount, 4),
                (i) => Container(
                  width: 10,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A),
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Colors.white70, width: 0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScorePill(int score) {
    final color = score > 0 ? Colors.greenAccent : score < 0 ? Colors.redAccent : Colors.white60;
    return Text(
      score > 0 ? '+$score' : '$score',
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildCenterArena() {
    final trick = _gameState.trick;
    final winner = _gameState.winner;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (winner != null) ...[
              Text(
                '🏆 ${kBig2PlayerNames[winner]} WINS!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _startNewRound,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Next Round'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
              ),
            ] else if (trick != null && trick.cards.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${Big2Rules.classifyHand(trick.cards)?.type.label ?? "Cards"} by ${kBig2PlayerNames[trick.owner]}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: trick.cards.map((c) => Big2CardWidget(card: c)).toList(),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _gameState.turn == kLocalPlayer
                      ? '⭐ You lead anything'
                      : '⭐ ${kBig2PlayerNames[_gameState.turn]} leads anything',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
            if (_statusBanner != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusBanner!,
                style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSouthPlayerSection({
    required List<Big2Card> displayHand,
    required Big2Combination? combination,
    required bool canPlay,
    required bool canPass,
    required bool isMyTurn,
  }) {
    String? hintText;
    Color hintColor = Colors.white70;

    if (_selectedCardIds.isNotEmpty) {
      if (combination == null) {
        hintText = 'Not a valid combination';
        hintColor = Colors.redAccent;
      } else if (!canPlay && isMyTurn) {
        hintText = "${combination.type.label} can't beat current trick";
        hintColor = Colors.orangeAccent;
      } else {
        hintText = combination.type.label;
        hintColor = Colors.greenAccent;
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: isMyTurn ? Colors.amber : Colors.white12, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Player Name + Hint Badge + Sort Button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isMyTurn ? Colors.amber : Colors.white24,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isMyTurn ? 'YOUR TURN' : 'You (${displayHand.length})',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isMyTurn ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (hintText != null)
                Expanded(
                  child: Text(
                    hintText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: hintColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              // Sort toggle button
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'rank', label: Text('Rank', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 'suit', label: Text('Suit', style: TextStyle(fontSize: 11))),
                ],
                selected: {_sortMode},
                onSelectionChanged: (set) => setState(() => _sortMode = set.first),
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.white10,
                  selectedBackgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white70,
                  selectedForegroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Scrollable Hand Cards
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayHand.map((card) {
                final isSelected = _selectedCardIds.contains(card.id);
                return Big2CardWidget(
                  card: card,
                  isSelected: isSelected,
                  onTap: () => _toggleCardSelection(card.id),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Action Controls: Pass / Clear / Play
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.block, size: 16),
                label: const Text('PASS'),
                onPressed: canPass ? _onPass : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.amber,
                  side: const BorderSide(color: Colors.amber),
                  disabledForegroundColor: Colors.white24,
                ),
              ),
              const SizedBox(width: 10),
              if (_selectedCardIds.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _selectedCardIds.clear()),
                  child: const Text('Clear', style: TextStyle(color: Colors.white60)),
                ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('PLAY CARDS'),
                onPressed: canPlay ? _onPlay : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white24,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRulesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Big Two Rules & Combinations', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hierarchy & Rankings:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              SizedBox(height: 4),
              Text(
                '• Card Values: 3 (lowest) ... K, A, 2 (highest)\n'
                '• Suit Order: ♦ < ♣ < ♥ < ♠ (Spades highest)\n'
                '• 3♦ leads the first trick of the round.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                '5-Card Combinations (Lowest to Highest):',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              SizedBox(height: 4),
              Text(
                '1. Straight (5 consecutive, A-2-3-4-5 wheel supported)\n'
                '2. Flush (5 cards of the same suit)\n'
                '3. Full House (Triple + Pair)\n'
                '4. Four of a Kind (4 of a rank + 1 kicker)\n'
                '5. Straight Flush (5 consecutive cards of the same suit)',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
    );
  }
}

class Big2CardWidget extends StatelessWidget {
  final Big2Card card;
  final bool isSelected;
  final VoidCallback? onTap;

  const Big2CardWidget({
    super.key,
    required this.card,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = card.suit.isRed ? const Color(0xFFC0392B) : const Color(0xFF1C1C1C);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      margin: EdgeInsets.only(
        left: 3,
        right: 3,
        bottom: isSelected ? 16 : 0,
        top: isSelected ? 0 : 16,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 46,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? const Color(0xFF2F6FDB) : const Color(0xFF9AA0A6),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFF2F6FDB).withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: isSelected ? 8 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top-left rank & suit
                Positioned(
                  top: 2,
                  left: 3,
                  child: Column(
                    children: [
                      Text(
                        card.rank.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        card.suit.symbol,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Center big pip
                Center(
                  child: Text(
                    card.suit.symbol,
                    style: TextStyle(
                      fontSize: 22,
                      color: color,
                      height: 1.0,
                    ),
                  ),
                ),
                // Bottom-right rank & suit (rotated)
                Positioned(
                  bottom: 2,
                  right: 3,
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: Column(
                      children: [
                        Text(
                          card.rank.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          card.suit.symbol,
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            height: 1.0,
                          ),
                        ),
                      ],
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
