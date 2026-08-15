import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/screens/big2_screen.dart';

void main() {
  testWidgets('Big2Screen renders 4 player seats and felt table', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: Big2Screen()));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('🎴 Big Two (大老二)'), findsOneWidget);
    expect(find.text('West 🤖'), findsOneWidget);
    expect(find.text('North 🤖'), findsOneWidget);
    expect(find.text('East 🤖'), findsOneWidget);

    // South player hand widgets
    expect(find.byType(Big2CardWidget), findsWidgets);
  });

  testWidgets('Big2Screen card selection and sort toggle', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: Big2Screen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on the first card in player's hand
    final firstCard = find.byType(Big2CardWidget).first;
    await tester.tap(firstCard);
    await tester.pump(const Duration(milliseconds: 100));

    // Clear selection
    final clearBtn = find.text('Clear');
    if (clearBtn.evaluate().isNotEmpty) {
      await tester.tap(clearBtn);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Toggle sort to 'Suit'
    final suitSegment = find.text('Suit');
    expect(suitSegment, findsOneWidget);
    await tester.tap(suitSegment);
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('Big2Screen rules dialog opens and closes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: Big2Screen()));
    await tester.pump(const Duration(milliseconds: 100));

    // Open Rules
    final helpBtn = find.byIcon(Icons.help_outline);
    expect(helpBtn, findsOneWidget);
    await tester.tap(helpBtn);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Big Two Rules & Combinations'), findsOneWidget);

    // Close Dialog
    await tester.tap(find.text('Got it'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Big Two Rules & Combinations'), findsNothing);
  });
}
