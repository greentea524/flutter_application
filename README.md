# Nebula Play — Games Hub

A Flutter arcade hub bundling several self-contained mini-games behind a single
neon-themed launcher. Best scores and progress persist locally via
[`localstorage`](https://pub.dev/packages/localstorage), so each game remembers
your stats between sessions.

Runs on all Flutter targets: Android, iOS, web, Windows, macOS, and Linux.

## Games

| Game | Genre | Notes |
| --- | --- | --- |
| Alien Invasion | Retro space shooter | Fire missiles, dodge bombs, beat unique boss roster, and unlock achievements |
| Pacman Arcade | Maze / arcade | Chomp pellets, dodge ghosts with neon virtual joystick |
| Big Two (大老二) | Card game / strategy | 4-player trick shedding with 3 smart AI bots, combinations, and penalty scoring |
| 2048 Fusion | Puzzle / logic | Slide and merge tiles to 2048 |
| Wordle Clone | Word puzzle | Guess the randomized 5-letter word with auto-submission |
| Minesweeper | Logic / puzzle | Reveal safe tiles, flag mines, level up |
| Sudoku | Logic / puzzle | Fill the 9×9 grid; multiple difficulties |

## Project layout

```
lib/
  main.dart                     App entry; dark theme + GamesHubScreen
  big2_deck.dart                Big Two 52-card deck, dealing, and hand sorting
  big2_rules.dart               Big Two combination classification and trick beating rules
  big2_bot.dart                 Big Two 3-bot AI heuristics
  big2_game.dart                Big Two table state machine & game loop
  big2_scoring.dart             Big Two end-of-round penalty and combo scoring
  big2_stats.dart               Big Two persistent stats
  wordle_words.dart             Word list for Wordle
  screens/
    games_hub_screen.dart       Launcher grid + persisted best-score stats
    big2_screen.dart            4-player felt table, interactive cards & modals
    alien_invasion_screen.dart  Starfleet hangar, boss roster, galaxy map & achievements
    pacman_arcade_screen.dart   Virtual joystick & neon maze rendering
    game_2048_screen.dart
    wordle_screen.dart
    minesweeper_screen.dart
    sudoku_screen.dart
test/
  widget_test.dart              Smoke and feature tests
  big2_deck_test.dart           Big Two deck unit tests
  big2_rules_test.dart          Big Two combinations and rules tests
  big2_bot_test.dart            Big Two AI bot tests
  big2_game_test.dart           Big Two state machine tests
  big2_screen_test.dart         Big Two widget tests
  big2_scoring_test.dart        Big Two scoring unit tests
assets/
  wordle_dictionary.json
```

Each game is a `StatefulWidget` screen using `CustomPainter` /
`AnimationController` for rendering — no external game engine.

## Getting Started

Install dependencies and run on a connected device or emulator:

```powershell
cd c:\codebase\flutter-app\flutter_application
flutter pub get
flutter run
```

New to Flutter? See the
[online documentation](https://docs.flutter.dev/) for tutorials, samples, and a
full API reference.

## Development

Static analysis and tests:

```powershell
flutter analyze
flutter test
```

## Build Android Package (APK)

Run these commands from the project root:

```powershell
cd c:\codebase\flutter-app\flutter_application
flutter clean
flutter pub get
```

Build a release APK:

```powershell
flutter build apk --release
```

Output location:

- `build/app/outputs/flutter-apk/app-release.apk`

Build split APKs by ABI (optional):

```powershell
flutter build apk --split-per-abi
```

Output location:

- `build/app/outputs/flutter-apk/`

Build Android App Bundle for Play Store (recommended for publishing):

```powershell
flutter build appbundle --release
```

Output location:

- `build/app/outputs/bundle/release/app-release.aab`
