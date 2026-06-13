import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'alien_invasion_screen.dart';
import 'wordle_screen.dart';

class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
  }

  void _loadHighScore() {
    try {
      final String? scoreStr = localStorage.getItem('alien_invasion_highscore');
      if (scoreStr != null) {
        setState(() {
          _highScore = int.tryParse(scoreStr) ?? 0;
        });
      }
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
            colors: [
              Color(0xFF06070B),
              Color(0xFF0E101A),
              Color(0xFF1B1429),
            ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
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
                                    colors: [Color(0xFF7B2CBF), Color(0xFF00F2FE)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF7B2CBF).withOpacity(0.4),
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
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [Colors.white, Color(0xFFC0A6FF)],
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
                          // Stats/Profile Icon
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2135).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF7B2CBF).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars, color: Color(0xFFFFD54A), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'Score: $_highScore',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // High score showcase card (Premium visual)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF1C1430).withOpacity(0.75),
                              const Color(0xFF0F1226).withOpacity(0.75),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF7B2CBF).withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2CBF).withOpacity(0.1),
                              blurRadius: 24,
                              spreadRadius: -8,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CURRENT HIGHEST RECORD',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF9E8FFF),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Alien Invasion',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Defend the galaxy and beat your limits.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  color: Color(0xFFFFD700),
                                  size: 40,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_highScore pts',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
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
                      description: 'Retro 2D shooter. Fire missiles, dodge alien bombs, collect weapon crates and gold coins, and destroy the giant octopus boss!',
                      genre: 'Retro Space Shooter',
                      bannerGradient: const [Color(0xFF3A0CA3), Color(0xFF7209B7)],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.rocket_launch,
                      onTap: () => _navigateToGame(context),
                    ),
                    // Game 2: Pacman (Locked)
                    _buildGameCard(
                      context: context,
                      title: 'Pacman Arcade',
                      description: 'Chomp pellets, dodge ghosts (Blinky, Pinky, Inky, and Clyde), and clear the retro neon maze to establish your high score.',
                      genre: 'Maze / Arcade',
                      bannerGradient: const [Color(0xFF2C2F3F), Color(0xFF1F2232)],
                      actionText: 'COMING SOON',
                      isPlayable: false,
                      icon: Icons.pie_chart_outline,
                      onTap: () {},
                    ),
                    // Game 3: 2048 (Locked)
                    _buildGameCard(
                      context: context,
                      title: '2048 Fusion',
                      description: 'Slide numbers across the grid to merge matching tiles and try to reach the legendary 2048 tile in this relaxing logic puzzle.',
                      genre: 'Puzzle / Logic',
                      bannerGradient: const [Color(0xFF2C2F3F), Color(0xFF1F2232)],
                      actionText: 'COMING SOON',
                      isPlayable: false,
                      icon: Icons.grid_on,
                      onTap: () {},
                    ),
                    // Game 4: Wordle (Now ACTIVE!)
                    _buildGameCard(
                      context: context,
                      title: 'Wordle Clone',
                      description: 'Test your vocabulary! Guess the secret 5-letter word in six attempts or fewer, using green/yellow color-coded feedback hints. A new word every day!',
                      genre: 'Word Puzzle',
                      bannerGradient: const [Color(0xFF006400), Color(0xFF1A7A1A)],
                      actionText: 'PLAY NOW',
                      isPlayable: true,
                      icon: Icons.abc_outlined,
                      onTap: () => _navigateToWordle(context),
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
                ? [bannerGradient[0].withOpacity(0.85), bannerGradient[1].withOpacity(0.85)]
                : [bannerGradient[0], bannerGradient[1]],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isPlayable ? const Color(0xFF00F2FE).withOpacity(0.5) : Colors.white10,
            width: isPlayable ? 1.5 : 1,
          ),
          boxShadow: [
            if (isPlayable)
              BoxShadow(
                color: bannerGradient[1].withOpacity(0.35),
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
                        color: isPlayable ? const Color(0xFF00F2FE) : Colors.white60,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        genre.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: isPlayable ? const Color(0xFF00F2FE) : Colors.white60,
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
                        color: isPlayable ? Colors.white.withOpacity(0.8) : Colors.white38,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
