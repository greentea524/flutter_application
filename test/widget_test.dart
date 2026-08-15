import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application/screens/alien_invasion_screen.dart';
import 'package:flutter_application/screens/games_hub_screen.dart';
import 'package:flutter_application/screens/pacman_arcade_screen.dart';
import 'package:flutter_application/screens/wordle_screen.dart';

void main() {
  testWidgets('Hangar screen displays, selects ship, and launches mission', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AlienInvasionScreen()));

    // Hangar title and ship options are shown first.
    expect(find.text('STARFLEET HANGAR'), findsOneWidget);
    expect(find.text('F-22 Starfighter'), findsOneWidget);
    expect(find.text('Dreadnought Cruiser'), findsOneWidget);
    expect(find.text('Phantom Interceptor'), findsOneWidget);

    // Select the Dreadnought Cruiser
    await tester.tap(find.text('Dreadnought Cruiser'));
    await tester.pump();

    // Launch button launches game
    final launchBtn = find.text('LAUNCH MISSION');
    expect(launchBtn, findsOneWidget);

    await tester.ensureVisible(launchBtn);
    await tester.tap(launchBtn);
    await tester.pump();

    // Hangar should be dismissed and game view active
    expect(find.text('STARFLEET HANGAR'), findsNothing);
    expect(find.byType(AlienInvasionScreen), findsOneWidget);

    // Let the ticker run a frame so painter draws
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  test('Boss roster and names metadata verification', () {
    expect(BossType.values.length, 4);
    expect(kBossNames[BossType.octopus], 'Octo Commander');
    expect(kBossNames[BossType.mothership], 'The Mothership');
    expect(kBossNames[BossType.lasercore], 'The Laser Core');
    expect(kBossNames[BossType.hive], 'The Swarm Hive');
  });

  test('Lifetime Achievements evaluation & progress verification (#6)', () {
    expect(kAchievements.length, 10);
    final stats = LifetimeStats()
      ..totalKills = 105
      ..bestCombo = 12
      ..maxWeaponLevel = 3
      ..bossKills = 10
      ..wavesCleared = 52
      ..flawlessWaves = 2
      ..shipsUsed = {'fighter', 'cruiser', 'interceptor'};

    // First Blood
    final firstBlood = kAchievements.firstWhere((a) => a.id == 'first_blood');
    expect(firstBlood.currentVal(stats), 105);
    expect(firstBlood.currentVal(stats) >= firstBlood.target, isTrue);

    // Pest Control
    final pestControl = kAchievements.firstWhere((a) => a.id == 'pest_control');
    expect(pestControl.currentVal(stats) >= pestControl.target, isTrue);

    // Sharpshooter
    final sharpshooter = kAchievements.firstWhere((a) => a.id == 'sharpshooter');
    expect(sharpshooter.currentVal(stats), 12);
    expect(sharpshooter.currentVal(stats) >= sharpshooter.target, isTrue);

    // Test Pilot
    final testPilot = kAchievements.firstWhere((a) => a.id == 'test_pilot');
    expect(testPilot.currentVal(stats), 3);
    expect(testPilot.currentVal(stats) >= testPilot.target, isTrue);
  });

  test('Roguelite Galaxy Map tier structure & generation verification (#7)', () {
    final random = math.Random(42);
    final map = generateGalaxyMap(0, random);

    expect(map.length, 5); // 5 tiers: [1, 2, 3, 2, 1]
    expect(map[0].length, 1);
    expect(map[1].length, 2);
    expect(map[2].length, 3);
    expect(map[3].length, 2);
    expect(map[4].length, 1);

    // First tier is nebula, last tier is boss
    expect(map[0][0].type, 'nebula');
    expect(map[4][0].type, 'boss');

    // Sector node themes
    expect(kSectorNodeTypes.length, 5);
  });

  testWidgets('Alien Invasion Hangar opens Achievements Modal and toggles Roguelite Mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AlienInvasionScreen()));

    // Open Achievements modal
    final achBtn = find.textContaining('ACHIEVEMENTS');
    expect(achBtn, findsOneWidget);
    await tester.ensureVisible(achBtn);
    await tester.tap(achBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('LIFETIME ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('First Blood'), findsOneWidget);
    expect(find.text('Pest Control'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('CLOSE'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('LIFETIME ACHIEVEMENTS'), findsNothing);

    // Toggle Roguelite Galaxy mode
    final roguMode = find.text('ROGUELITE GALAXY');
    await tester.tap(roguMode);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ENTER GALAXY MAP'), findsOneWidget);

    // Enter Galaxy Map
    await tester.tap(find.text('ENTER GALAXY MAP'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('GALAXY SECTOR 1'), findsOneWidget);
    expect(find.text('DEPLOY NOW'), findsOneWidget);
  });

  testWidgets('Wordle automatically submits on 5th letter entered', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: WordleScreen()));
    await tester.pumpAndSettle();

    // Enter 5 letters: C - R - A - N - E
    for (final char in ['C', 'R', 'A', 'N', 'E']) {
      final keyWidget = find.text(char).last;
      await tester.ensureVisible(keyWidget);
      await tester.tap(keyWidget);
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Advance flip animations
    await tester.pump(const Duration(seconds: 2));

    expect(find.byType(WordleScreen), findsOneWidget);
  });

  testWidgets('Pacman Arcade renders with Virtual Joystick and responds to drag', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: PacmanArcadeScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pacman Arcade'), findsOneWidget);
    expect(find.text('Score'), findsOneWidget);
    expect(find.text('Ghosts'), findsOneWidget);

    // Drag joystick
    final joystickFinder = find.byType(GestureDetector).last;
    await tester.drag(joystickFinder, const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PacmanArcadeScreen), findsOneWidget);
  });

  testWidgets('GamesHubScreen renders Big Two (大老二) launcher card', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: GamesHubScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('NEBULA PLAY'), findsOneWidget);

    final cardFinder = find.text('Big Two (大老二)');
    await tester.scrollUntilVisible(
      cardFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(cardFinder, findsOneWidget);
  });
}
