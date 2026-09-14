import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hinge_devices/effects.dart';
import 'package:hinge_devices/hinge_devices.dart';

import 'fake_platform.dart';

/// Regression tests for the hinge angle that only updated when the layout
/// changed.
///
/// Two `HingeAngleBuilder`s were enough to break it: the first one disposing
/// turned the sensor off for the second, so readings only resumed when a
/// posture change remounted a builder.
void main() {
  late FakeHingeDevices fake;

  setUp(() {
    fake = FakeHingeDevices();
    FoldableDevice.setPlatformForTesting(fake);
  });

  tearDown(FoldableDevice.resetForTesting);

  test('angle requests are reference counted', () async {
    final device = FoldableDevice.instance;

    await device.enableAngleUpdates();
    await device.enableAngleUpdates();
    expect(device.angleSubscriberCount, 2);
    expect(fake.angleEnabled, isTrue);

    await device.disableAngleUpdates();
    expect(
      fake.angleEnabled,
      isTrue,
      reason: 'one holder released, another still needs the sensor',
    );

    await device.disableAngleUpdates();
    expect(fake.angleEnabled, isFalse);
  });

  test('releasing more than was taken does not go negative', () async {
    final device = FoldableDevice.instance;
    await device.disableAngleUpdates();
    await device.disableAngleUpdates();
    expect(device.angleSubscriberCount, 0);

    await device.enableAngleUpdates();
    expect(fake.angleEnabled, isTrue);
  });

  testWidgets('two builders keep the sensor alive independently', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            HingeAngleBuilder(
              autoEnable: true,
              builder: (_, a) => Text('a${a.toStringAsFixed(0)}'),
            ),
            HingeAngleBuilder(
              autoEnable: true,
              builder: (_, a) => Text('b${a.toStringAsFixed(0)}'),
            ),
          ],
        ),
      ),
    );
    await t.pump();
    expect(FoldableDevice.instance.angleSubscriberCount, 2);

    // Drop one builder — the surviving one must still receive readings.
    await t.pumpWidget(
      MaterialApp(
        home: HingeAngleBuilder(
          autoEnable: true,
          builder: (_, a) => Text('b${a.toStringAsFixed(0)}'),
        ),
      ),
    );
    await t.pump();
    expect(fake.angleEnabled, isTrue);

    fake.emit(const FoldableState(hinge: Hinge(angle: 42)));
    await t.pump();
    await t.pump();
    expect(find.text('b42'), findsOneWidget);
  });

  testWidgets('angle updates stream without any posture change', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: HingeAngleBuilder(
          autoEnable: true,
          throttle: Duration.zero,
          builder: (_, a) => Text(a.toStringAsFixed(0)),
        ),
      ),
    );
    await t.pump();

    for (final angle in <double>[30, 60, 90]) {
      fake.emit(
        FoldableState(
          posture: FoldPosture.tabletop, // posture never changes
          hinge: Hinge(angle: angle),
        ),
      );
      await t.pump();
      await t.pump();
      expect(find.text(angle.toStringAsFixed(0)), findsOneWidget);
    }
  });
}
