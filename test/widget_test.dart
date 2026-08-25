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
    expect(kAchievements.length, 11);
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

    // Fully Loaded is still earned at level 3, but the top of the ladder
    // (level 5) is a separate tier that these stats have not reached (#18).
    final fullyLoaded = kAchievements.firstWhere((a) => a.id == 'fully_loaded');
    expect(fullyLoaded.currentVal(stats) >= fullyLoaded.target, isTrue);

    final maxFirepower = kAchievements.firstWhere(
      (a) => a.id == 'fully_loaded_v2',
    );
    expect(maxFirepower.target, kWeaponLevelCap);
    expect(maxFirepower.currentVal(stats) >= maxFirepower.target, isFalse);

    stats.maxWeaponLevel = kWeaponLevelCap;
    expect(maxFirepower.currentVal(stats) >= maxFirepower.target, isTrue);
  });

  test('Weapon ladder is paced by crates collected and runs to 5 (#18)', () {
    expect(kWeaponLevelCap, 5);

    // Names cover the whole ladder -- the web WEAPON_NAMES map stops at 3.
    for (int level = 1; level <= kWeaponLevelCap; level++) {
      expect(kWeaponNames[level], isNotNull);
    }

    // 1/3/6/10 crates -> levels 2/3/4/5, matching the web engine.
    const expected = <int, int>{
      0: 1,
      1: 2,
      2: 2,
      3: 3,
      5: 3,
      6: 4,
      9: 4,
      10: 5,
      14: 5,
    };
    expected.forEach((crates, level) {
      expect(
        weaponLevelForCrates(crates),
        level,
        reason: '$crates crates should give level $level',
      );
    });
  });

  test('Power-up taxonomy covers all five web types (#17)', () {
    expect(PowerUpType.values.length, 5);

    // Fixed order, mirroring the web engine's POWERUP_TYPES.
    expect(kPowerUpDropOrder, [
      PowerUpType.weapon,
      PowerUpType.shield,
      PowerUpType.drone,
      PowerUpType.laser,
      PowerUpType.homing,
    ]);

    // Every type is drawable, and no two crates read the same on screen.
    for (final type in PowerUpType.values) {
      expect(kPowerUpStyles[type], isNotNull, reason: '$type has no style');
    }
    final letters = kPowerUpStyles.values.map((s) => s.letter).toSet();
    final colors = kPowerUpStyles.values.map((s) => s.color).toSet();
    expect(letters.length, PowerUpType.values.length);
    expect(colors.length, PowerUpType.values.length);

    // Crates default to the weapon type so existing drops are unchanged.
    expect(GamePowerUp(0, 0).type, PowerUpType.weapon);
  });

  test('Timed weapons alternate with the standard shot (#17)', () {
    // Nothing active: always the standard shot.
    for (int i = 0; i < 4; i++) {
      expect(
        activeWeaponForCycle(i, laserActive: false, homingActive: false),
        PowerUpType.weapon,
      );
    }

    // One active weapon alternates with the standard shot, so the ladder
    // still fires half the time.
    expect(
      activeWeaponForCycle(0, laserActive: true, homingActive: false),
      PowerUpType.laser,
    );
    expect(
      activeWeaponForCycle(1, laserActive: true, homingActive: false),
      PowerUpType.weapon,
    );

    // Both active: laser, homing, standard, repeating.
    const expected = [
      PowerUpType.laser,
      PowerUpType.homing,
      PowerUpType.weapon,
    ];
    for (int i = 0; i < 7; i++) {
      expect(
        activeWeaponForCycle(i, laserActive: true, homingActive: true),
        expected[i % 3],
        reason: 'cycle index $i',
      );
    }
  });

  // The game loop steps on accumulated lag, not on pump count, so a pump
  // shorter than a frame can run no game update at all.
  Future<void> pumpFrames(WidgetTester tester, int frames) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  // Launches a run and hands back the live game state. The State class is
  // private, so the test reaches its public fields through `dynamic`.
  Future<dynamic> launchRun(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AlienInvasionScreen()));
    final launchBtn = find.text('LAUNCH MISSION');
    await tester.ensureVisible(launchBtn);
    await tester.tap(launchBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    return tester.state(find.byType(AlienInvasionScreen)) as dynamic;
  }

  testWidgets('Escort drones take station and open fire (#17)', (
    WidgetTester tester,
  ) async {
    final state = await launchRun(tester);

    expect(state.drones.length, 2);
    expect(state.drones[0].isPlaced, isFalse);

    state.droneTimer = 600;
    for (int i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    // Drones snap to their slots either side of the ship...
    expect(state.drones[0].isPlaced, isTrue);
    expect(state.drones[0].x, lessThan(state.player.x));
    expect(state.drones[1].x, greaterThan(state.player.x));

    // ...and fire on the wave without the player pulling the trigger.
    expect(state.drones[0].bulletsShot, greaterThan(0));

    // Their rounds count towards Hit Rate's denominator, or drone kills
    // would push it past 100%.
    expect(state.bulletsShot, greaterThan(0));

    // The timer runs down and is the only thing keeping them alive.
    expect(state.droneTimer, lessThan(600));
  });

  testWidgets('Laser shots outrun standard ones; homing shots steer (#17)', (
    WidgetTester tester,
  ) async {
    final state = await launchRun(tester);

    state.bullets.clear();
    final standard = GameBullet(400, 300);
    final laser = GameBullet(
      300,
      300,
      isLaser: true,
      width: 16.0,
      height: 40.0,
    );
    state.bullets.addAll(<GameBullet>[standard, laser]);

    final double startY = standard.y;
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final double standardTravel = startY - standard.y;
    final double laserTravel = startY - laser.y;
    expect(standardTravel, greaterThan(0));
    expect(laserTravel, closeTo(standardTravel * 2.5, 0.001));

    // A homing shot drifts towards the nearest alien rather than flying
    // straight up.
    state.bullets.clear();
    state.aliens.clear();
    state.aliens.add(GameAlien(700, 200));
    final homing = GameBullet(100, 300, isHoming: true);
    state.bullets.add(homing);

    await tester.pump(const Duration(milliseconds: 16));
    expect(homing.vx, greaterThan(0), reason: 'should steer right');

    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Drift is capped so a homing shot never becomes a horizontal beam.
    expect(homing.vx, lessThanOrEqualTo(4.0));
  });

  testWidgets('Shield soaks damage before the hull does (#17)', (
    WidgetTester tester,
  ) async {
    final state = await launchRun(tester);

    final int fullHp = state.player.hp as int;
    state.playerShieldHp = 50;

    // A kamikaze spawnling deals 15. Land one on the ship.
    void ramPlayer() {
      state.spawnlings.add(
        GameSpawnling(
          x: state.player.x as double,
          y: (state.player.y as double) - 2,
          vy: 4.0,
        ),
      );
    }

    ramPlayer();
    await pumpFrames(tester, 3);

    // Shield absorbed it; the hull is untouched.
    expect(state.playerShieldHp, 35);
    expect(state.player.hp, fullHp);

    // Drain the shield down to less than a single hit.
    state.playerShieldHp = 5;
    ramPlayer();
    await pumpFrames(tester, 3);

    // The overflow carries through to the hull rather than being lost.
    expect(state.playerShieldHp, 0);
    expect(state.player.hp, fullHp - 10);

    // With the shield gone, damage lands in full.
    ramPlayer();
    await pumpFrames(tester, 3);
    expect(state.player.hp, fullHp - 25);
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
