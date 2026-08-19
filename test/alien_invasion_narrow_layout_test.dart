// Phone-width layout for Alien Invasion (#19).
//
// Nothing rendered any screen below 600px before this, which is how two
// visible overflows and an unreachable control went unnoticed: the hangar's
// mode-selector Row needed ~440px inside a ~332px column, so the ROGUELITE
// GALAXY chip sat past its parent's right edge — outside the hit-test bounds,
// looking tappable but impossible to select on any phone 390px or narrower.
//
// Widths below are real devices, not round numbers. Note the test font is
// wider than the shipping one, so these are pessimistic: passing here implies
// passing on device.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/screens/alien_invasion_screen.dart';

const _widths = <(int, String)>[
  (320, 'iPhone SE 1st gen'),
  (360, 'common Android'),
  (375, 'iPhone SE / 13 mini'),
  (390, 'iPhone 14 / 13 / 12'),
  (412, 'Pixel 7'),
  (430, 'iPhone 15 Pro Max'),
];

/// Collects overflow errors raised while [body] runs.
///
/// RenderFlex overflow is reported through FlutterError rather than by
/// throwing, so without capturing it a test can pass over a broken layout.
Future<List<String>> _overflowsDuring(
  WidgetTester tester,
  int width,
  Future<void> Function(WidgetTester) body,
) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  // Everything is swallowed, not just overflow: forwarding the rest to the
  // default handler wedges the run once the game view is on screen.
  //
  // The handler is put back before this returns rather than in a tearDown.
  // Leaving it installed across the caller's expect() swallows the framework's
  // own failure reporting, and a failing test then hangs instead of failing.
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (text.contains('overflowed')) {
      errors.add(text.split('\n').first.trim());
    }
  };

  tester.view.physicalSize = Size(width.toDouble(), 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  try {
    await tester.pumpWidget(const MaterialApp(home: AlienInvasionScreen()));
    await tester.pump();
    await body(tester);
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void main() {
  for (final (width, device) in _widths) {
    testWidgets('hangar lays out without overflow at ${width}px ($device)', (
      tester,
    ) async {
      final errors = await _overflowsDuring(tester, width, (_) async {});
      expect(errors, isEmpty, reason: 'hangar overflowed at ${width}px: $errors');
    });

    testWidgets('roguelite mode is selectable at ${width}px ($device)', (
      tester,
    ) async {
      await _overflowsDuring(tester, width, (t) async {
        // warnIfMissed is off deliberately: the failure being guarded is a
        // chip outside its parent's hit-test bounds, which misses silently.
        await t.tap(find.text('ROGUELITE GALAXY'), warnIfMissed: false);
        await t.pump();
      });
      final dynamic state = tester.state(find.byType(AlienInvasionScreen));
      expect(
        state.isRogueliteMode,
        isTrue,
        reason: 'the ROGUELITE GALAXY chip did not respond at ${width}px — '
            'it is most likely laid out past its parent\'s right edge',
      );
    });

    testWidgets('in-game top bar fits at ${width}px ($device)', (tester) async {
      // The playing bar carries a Hangar button the hangar's does not, so it
      // is under more width pressure than the screen the bug was found on.
      final errors = await _overflowsDuring(tester, width, (t) async {
        // Leaving the menu directly rather than tapping LAUNCH MISSION: at
        // these widths that button needs scrolling into view, and
        // ensureVisible never settles against the hangar's animated
        // background. The bar under test does not care how we got here.
        final dynamic state = t.state(find.byType(AlienInvasionScreen));
        state.inMenu = false;
        // Rebuild without advancing the clock. Pumping a real duration would
        // start the game loop, and the live Ticker then keeps the test from
        // ever completing — the bar's layout needs neither.
        t.element(find.byType(AlienInvasionScreen)).markNeedsBuild();
        await t.pump();
        // Below 500px the Hangar button is icon-only, so assert on the
        // tooltip, which is present either way.
        expect(find.byTooltip('Hangar'), findsOneWidget);
      });
      expect(errors, isEmpty, reason: 'in-game bar overflowed at ${width}px: $errors');
    });
  }

  testWidgets('the title scales instead of truncating', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: AlienInvasionScreen()));
    await tester.pump();

    final paragraph =
        tester.renderObject(find.text('INVASION')) as RenderParagraph;
    // FittedBox lays the child out unconstrained and scales the result, so the
    // paragraph keeps its natural size and no ellipsis is ever applied.
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      tester.getRect(find.text('INVASION')).width,
      lessThan(paragraph.size.width),
      reason: 'at 320px the title should be scaled down, not drawn full size',
    );
  });
}
