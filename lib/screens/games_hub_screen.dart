import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'alien_invasion_screen.dart';
import 'game_2048_screen.dart';
import 'minesweeper_screen.dart';
import 'pacman_arcade_screen.dart';
import 'sudoku_screen.dart';
import 'wordle_screen.dart';

class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  int _highScore = 0;
  int _bestAlienWave = 0;
  int _best2048Score = 0;
  int _bestMinesweeperScore = 0;
  int _bestMinesweeperLevel = 0;
  int _bestPacmanScore = 0;
  int _sudokuSolved = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  void _loadHighScore() {
    try {
      final String? scoreStr = localStorage.getItem('alien_invasion_highscore');
      final String? alienWaveStr = localStorage.getItem(
        'alien_invasion_best_wave',
      );
      final String? score2048Str = localStorage.getItem('game_2048_best_score');
      final String? pacmanScoreStr = localStorage.getItem(
        'jsPacmanPersistentScore',
      );
      final String? minesweeperBestScoreStr = localStorage.getItem(
        'minesweeper_best_score',
      );
      final String? minesweeperBestLevelStr = localStorage.getItem(
        'minesweeper_best_level',
      );
      final String? sudokuSolvedStr = localStorage.getItem(
        'sudoku_solved_count',
      );

      final int nextAlienScore = int.tryParse(scoreStr ?? '0') ?? 0;
      final int nextAlienWave = int.tryParse(alienWaveStr ?? '0') ?? 0;
      final int next2048Score = int.tryParse(score2048Str ?? '0') ?? 0;
      final int nextPacmanScore = int.tryParse(pacmanScoreStr ?? '0') ?? 0;
      final int nextMinesweeperBestScore =
          int.tryParse(minesweeperBestScoreStr ?? '0') ?? 0;
      final int nextMinesweeperBestLevel =
          int.tryParse(minesweeperBestLevelStr ?? '0') ?? 0;
      final int nextSudokuSolved = int.tryParse(sudokuSolvedStr ?? '0') ?? 0;

      setState(() {
        _highScore = nextAlienScore;
        _bestAlienWave = nextAlienWave;
        _best2048Score = next2048Score;
        _bestPacmanScore = nextPacmanScore;
        _bestMinesweeperScore = nextMinesweeperBestScore;
        _bestMinesweeperLevel = nextMinesweeperBestLevel;
        _sudokuSolved = nextSudokuSolved;
      });
    } catch (_) {
      // Fallback if localStorage fails
    }
  }

  // Reload the high score when returning to this screen
  Future<void> _navigateToGame(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AlienInvasionScreen()),
    );
    _loadHighScore();
  }

  Future<void> _navigateToWordle(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WordleScreen()),
    );
  }

  Future<void> _navigateTo2048(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Game2048Screen()),
    );
    _loadHighScore();
  }

  Future<void> _navigateToMinesweeper(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MinesweeperScreen()),
    );
    _loadHighScore();
  }

  Future<void> _navigateToPacman(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PacmanArcadeScreen()),
    );
    _loadHighScore();
  }

  Future<void> _navigateToSudoku(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SudokuScreen()),
    );
    _loadHighScore();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 768;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06070B), Color(0xFF0E101A), Color(0xFF1B1429)],
            stops: [0.1, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Beautiful glowing header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7B2CBF),
                                      Color(0xFF00F2FE),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF7B2CBF,
                                      ).withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.sports_esports_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [
                                            Colors.white,
                                            Color(0xFFC0A6FF),
                                          ],
                                        ).createShader(bounds),
                                    child: const Text(
                                      'NEBULA PLAY',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2.0,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'ANTIGRAVITY ARCADE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 3.0,
                                      color: Color(0xFF00F2FE),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const SizedBox(height: 8),
                      const Text(
                        'EXPLORE THE ARCADE',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9E8FFF),
                          letterSpacing: 2.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Grid list of games
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 2 : 1,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: isDesktop ? 1.4 : 1.6,
                  ),
                  delegate: SliverChildListDelegate([
                    // Game 1: Alien Invasion (Active)
                    _buildGameCard(
                      context: context,
                      title: 'Alien Invasion',
                      description:
                          'Retro 2D shooter. Fire missiles, dodge alien bombs, collect weapon crates and gold coins, and destroy the giant octopus boss!',
                      genre: 'Retro Space Shooter',
                      bannerGradient: const [
                        Color(0xFF3A0CA3),
                        Color(0xFF7209B7),
                      ],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.rocket_launch,
                      statText: 'Best: $_highScore | Wave: $_bestAlienWave',
                      onTap: () => _navigateToGame(context),
                    ),
                    // Game 2: Pacman (Active)
                    _buildGameCard(
                      context: context,
                      title: 'Pacman Arcade',
                      description:
                          'Chomp dungeon pellets, dodge roaming ghosts, and survive increasingly crowded rounds in this arcade maze challenge.',
                      genre: 'Maze / Arcade',
                      bannerGradient: const [
                        Color(0xFF0E3A66),
                        Color(0xFF1E6091),
                      ],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.sports_esports,
                      statText: 'Best: $_bestPacmanScore',
                      onTap: () => _navigateToPacman(context),
                    ),
                    // Game 3: 2048 (Locked)
                    _buildGameCard(
                      context: context,
                      title: '2048 Fusion',
                      description:
                          'Slide numbers across the grid to merge matching tiles and try to reach the legendary 2048 tile in this relaxing logic puzzle.',
                      genre: 'Puzzle / Logic',
                      bannerGradient: const [
                        Color(0xFF8B5E34),
                        Color(0xFFB87D39),
                      ],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.grid_on,
                      statText: 'Best: $_best2048Score',
                      onTap: () => _navigateTo2048(context),
                    ),
                    // Game 4: Wordle (Now ACTIVE!)
                    _buildGameCard(
                      context: context,
                      title: 'Wordle Clone',
                      description:
                          'Test your vocabulary! Guess the secret 5-letter word in six attempts or fewer, using green/yellow color-coded feedback hints. A new word every day!',
                      genre: 'Word Puzzle',
                      bannerGradient: const [
                        Color(0xFF006400),
                        Color(0xFF1A7A1A),
                      ],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.abc_outlined,
                      onTap: () => _navigateToWordle(context),
                    ),
                    // Game 5: Minesweeper (Active)
                    _buildGameCard(
                      context: context,
                      title: 'Minesweeper',
                      description:
                          'Classic minefield puzzle. Reveal safe tiles, flag bombs, and clear the board to level up and earn points.',
                      genre: 'Logic / Puzzle',
                      bannerGradient: const [
                        Color(0xFF1F3A5B),
                        Color(0xFF3A6073),
                      ],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.grid_4x4,
                      statText:
                          'Best: $_bestMinesweeperScore | Lvl: $_bestMinesweeperLevel',
                      onTap: () => _navigateToMinesweeper(context),
                    ),
                    // Game 6: Sudoku (Active)
                    _buildGameCard(
                      context: context,
                      title: 'Sudoku',
                      description:
                          'Fill the 9×9 grid so every row, column, and 3×3 box holds 1–9. Pick a difficulty, use hints when stuck, and solve unique puzzles generated every game.',
                      genre: 'Logic / Puzzle',
                      bannerGradient: const [
                        Color(0xFF3A0CA3),
                        Color(0xFF4361EE),
                      ],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.grid_3x3,
                      statText: 'Solved: $_sudokuSolved',
                      onTap: () => _navigateToSudoku(context),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String description,
    required String genre,
    required List<Color> bannerGradient,
    required String actionText,
    required bool isPlayable,
    required IconData icon,
    String? statText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isPlayable ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isPlayable
                ? [
                    bannerGradient[0].withValues(alpha: 0.85),
                    bannerGradient[1].withValues(alpha: 0.85),
                  ]
                : [bannerGradient[0], bannerGradient[1]],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isPlayable
                ? const Color(0xFF00F2FE).withValues(alpha: 0.5)
                : Colors.white10,
            width: isPlayable ? 1.5 : 1,
          ),
          boxShadow: [
            if (isPlayable)
              BoxShadow(
                color: bannerGradient[1].withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Abstract neon vector circle background for premium look
            Positioned(
              right: -30,
              top: -30,
              child: Opacity(
                opacity: isPlayable ? 0.15 : 0.04,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Locked Overlay
            if (!isPlayable)
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: Colors.white60,
                    size: 16,
                  ),
                ),
              ),
            // Card Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        color: isPlayable
                            ? const Color(0xFF00F2FE)
                            : Colors.white60,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        genre.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isPlayable
                              ? const Color(0xFF00F2FE)
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isPlayable ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isPlayable
                            ? Colors.white.withValues(alpha: 0.8)
                            : Colors.white38,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (statText != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPlayable ? Colors.white : Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          actionText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isPlayable ? Colors.black : Colors.white30,
                          ),
                        ),
                      ),
                      if (isPlayable)
                        const Row(
                          children: [
                            Text(
                              'LAUNCH',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 11,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
