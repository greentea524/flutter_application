// Regression tests for the Alien Invasion fire rate (#16).
//
// The gun used to be paced by an on-screen bullet cap
// (`bullets.length <= 6 - bulletsPerShot`) rather than by its cooldown, which
// made the cadence a function of how far shots had travelled — and, because
// the cap tightened as the weapon levelled up, made upgrading your weapon
// shoot *slower*. These tests pin the two properties that fixes it: the
// cadence tracks the cooldown, and a level 3 weapon delivers three times the
// bullets of level 1 rather than the same number.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application/screens/alien_invasion_screen.dart';

/// Launches past the hangar and hands back the running game's state.
///
/// The state class is private, so its public fields are reached dynamically.
Future<dynamic> _launch(WidgetTester tester, {Size size = const Size(1200, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(const MaterialApp(home: AlienInvasionScreen()));
  final launch = find.text('LAUNCH MISSION');
  await tester.ensureVisible(launch);
  await tester.tap(launch);
  await tester.pump();
  return tester.state(find.byType(AlienInvasionScreen));
}

/// Advances [ms] of fake time in frame-sized slices.
///
/// The screen's loop only steps once `_lag` reaches 16.67ms, so a lone 16ms
/// pump advances the clock without ever running a game frame.
Future<void> _pumpMs(WidgetTester tester, int ms) async {
  var left = ms;
  while (left > 0) {
    final step = left < 17 ? left : 17;
    await tester.pump(Duration(milliseconds: step));
    left -= step;
  }
}

/// Returns focus to the game's KeyboardListener.
///
/// Tapping any button (LAUNCH MISSION, Restart) takes focus with it, and the
/// screen only reads keys while its own node holds focus.
Future<void> _focusGame(WidgetTester tester) async {
  tester.widget<KeyboardListener>(find.byType(KeyboardListener)).focusNode.requestFocus();
  await tester.pump();
}

/// Holds the trigger for [seconds] of fake time and reports bullets fired.
///
/// Aliens are cleared each frame so nothing is destroyed and no drop or wave
/// advance can perturb the count — this measures the gun alone.
Future<int> _holdFire(WidgetTester tester, dynamic s, int weaponLevel, {int seconds = 20}) async {
  s.weaponLevel = weaponLevel;
  s.bulletsShot = 0;
  s.spacePressed = true;
  final int frames = (seconds * 1000 / 16).round();
  for (int i = 0; i < frames; i++) {
    s.aliens.clear();
    s.bosses.clear();
    await tester.pump(const Duration(milliseconds: 16));
  }
  s.spacePressed = false;
  return s.bulletsShot as int;
}

void main() {
  testWidgets('sustained fire tracks the 200ms cooldown, not bullet travel', (
    WidgetTester tester,
  ) async {
    // Under the 768px mobile threshold on purpose (but not so narrow that the
    // hangar UI overflows, which is a separate pre-existing layout problem). `_logicalHeight` is 900 below 768px wide and 600
    // above it, and the taller playfield is what made the old bullet cap bite:
    // a shot needs ~2.1s to clear 900px, so only ~57 could be fired in 20s.
    final dynamic s = await _launch(tester, size: const Size(760, 900));

    const int seconds = 20;
    final int lvl1 = await _holdFire(tester, s, 1, seconds: seconds);

    // 20s at one volley per 200ms is ~100 shots. The cadence must come from
    // the cooldown, not from how far the previous bullets have travelled.
    expect(
      lvl1,
      greaterThan(85),
      reason: 'level 1 fired $lvl1 in ${seconds}s on a tall playfield; '
          'at a 200ms cooldown it should be ~100',
    );
    expect(lvl1, lessThanOrEqualTo(105));
  });

  testWidgets('a level 3 weapon delivers 3x the bullets, not the same number', (
    WidgetTester tester,
  ) async {
    final dynamic s = await _launch(tester);

    const int seconds = 20;
    final int lvl1 = await _holdFire(tester, s, 1, seconds: seconds);
    final int lvl3 = await _holdFire(tester, s, 3, seconds: seconds);

    // The regression this guards: the bullet cap pinned throughput at a flat
    // ~60 bullets per 20s at every weapon level, so upgrading bought nothing.
    expect(
      lvl3,
      greaterThan(lvl1 * 2.5),
      reason: 'level 3 fired $lvl3 vs level 1 $lvl1 — upgrading must raise throughput',
    );
  });

  testWidgets('a tap during the cooldown still fires once the gun is ready', (
    WidgetTester tester,
  ) async {
    final dynamic s = await _launch(tester);
    await _focusGame(tester);
    s.aliens.clear();
    s.bosses.clear();
    s.bulletsShot = 0;

    // One press, released straight away. Starts the 200ms cooldown.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await _pumpMs(tester, 51);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await _pumpMs(tester, 17);
    expect(s.bulletsShot, 1, reason: 'the first press should fire');

    // A quick tap well inside the cooldown, released before it expires.
    await _pumpMs(tester, 68);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await _pumpMs(tester, 17);
    expect(s.bulletsShot, 1, reason: 'it cannot fire yet — the gun is still cooling');

    // Once the cooldown ends the latched request must be spent, even though
    // nothing is held down any more.
    await _pumpMs(tester, 170);
    expect(
      s.bulletsShot,
      2,
      reason: 'the tap made during the cooldown was dropped instead of latched',
    );

    // ...and exactly once. A latch that is not cleared would keep firing.
    await _pumpMs(tester, 500);
    expect(s.bulletsShot, 2, reason: 'the latch fired more than once');
  });

  testWidgets("restarting cancels the previous run's cooldown timer", (
    WidgetTester tester,
  ) async {
    final dynamic s = await _launch(tester);
    await _focusGame(tester);
    s.aliens.clear();
    s.bosses.clear();

    // Shot A at ~t=34ms, so the old run's cooldown would end at ~t=234ms.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await _pumpMs(tester, 51);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(s.canShoot, isFalse);

    final restart = find.text('Restart');
    await tester.ensureVisible(restart);
    await tester.tap(restart);
    await tester.pump();
    await _focusGame(tester);
    expect(s.canShoot, isTrue, reason: 'a restart re-arms the gun');

    // Wait, then fire shot B at ~t=190ms — its own cooldown runs to ~t=390ms,
    // which straddles the old timer's ~t=234ms deadline.
    await _pumpMs(tester, 119);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await _pumpMs(tester, 17);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(s.canShoot, isFalse);

    // Cross the OLD deadline. A live timer from the previous run would land
    // here and hand the new run a free shot mid-cooldown.
    await _pumpMs(tester, 102);
    expect(
      s.canShoot,
      isFalse,
      reason: "a timer from the previous run re-enabled shooting early",
    );
  });
}
