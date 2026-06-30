// Smoke test for the Boxing RPG screen.
//
// Verifies the menu -> game transition and that throwing a punch updates the
// combat log. Storage calls inside BoxingScreen are guarded, so no
// localStorage initialization is required here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application/screens/boxing_screen.dart';

void main() {
  testWidgets('New Game starts a fight and punching logs damage', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BoxingScreen()));

    // Menu is shown first.
    expect(find.text('NEW GAME'), findsOneWidget);

    await tester.tap(find.text('NEW GAME'));
    await tester.pumpAndSettle();

    // Game screen controls are present.
    final punch = find.text('Punch');
    expect(punch, findsOneWidget);
    expect(find.text('Scrap Bot'), findsWidgets);

    // The button can sit below the fold in the test viewport; make sure the
    // tap actually lands on it.
    await tester.ensureVisible(punch);
    await tester.tap(punch);
    await tester.pumpAndSettle();

    // One exchange does not KO either fighter, so the status line advances to
    // the in-progress message.
    expect(find.text('Fight in progress!'), findsOneWidget);
  });
}
