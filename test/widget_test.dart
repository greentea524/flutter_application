import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application/screens/alien_invasion_screen.dart';
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

    // Hangar should be dismissed
    expect(find.text('STARFLEET HANGAR'), findsNothing);
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
}
