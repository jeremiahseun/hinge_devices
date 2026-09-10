import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

import 'fake_platform.dart';

void main() {
  late FakeFoldableRuntime fake;

  setUp(() {
    fake = FakeFoldableRuntime();
    FoldableDevice.setPlatformForTesting(fake);
  });

  tearDown(FoldableDevice.resetForTesting);

  test('capabilities are queried once and cached', () async {
    final device = FoldableDevice.instance;
    await device.capabilities;
    await device.capabilities;
    expect(fake.capabilityCalls, 1);
  });

  test('posture stream deduplicates repeated postures', () async {
    final device = FoldableDevice.instance;
    final seen = <FoldPosture>[];
    final sub = device.postureStream.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    fake
      ..emit(const FoldableState(posture: FoldPosture.flat))
      ..emit(const FoldableState(posture: FoldPosture.flat))
      ..emit(const FoldableState(posture: FoldPosture.tabletop))
      ..emit(const FoldableState(posture: FoldPosture.tabletop))
      ..emit(const FoldableState(posture: FoldPosture.flat));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, [FoldPosture.flat, FoldPosture.tabletop, FoldPosture.flat]);
  });

  test('angle changes do not produce posture events', () async {
    final device = FoldableDevice.instance;
    final seen = <FoldPosture>[];
    final sub = device.postureStream.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    for (var angle = 90.0; angle < 100; angle += 1) {
      fake.emit(
        FoldableState(
          posture: FoldPosture.tabletop,
          hinge: Hinge(angle: angle, status: HingeStatus.partiallyOpen),
        ),
      );
    }
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, [FoldPosture.tabletop]);
  });

  test('angle stream carries every reading', () async {
    final device = FoldableDevice.instance;
    final seen = <double>[];
    final sub = device.hingeAngleStream.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    fake
      ..emit(const FoldableState(hinge: Hinge(angle: 90)))
      ..emit(const FoldableState(hinge: Hinge(angle: 91)))
      ..emit(const FoldableState(hinge: Hinge(angle: 92)));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, [90, 91, 92]);
  });

  test('states with no angle are filtered out of the angle stream', () async {
    final device = FoldableDevice.instance;
    final seen = <double>[];
    final sub = device.hingeAngleStream.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    fake
      ..emit(const FoldableState())
      ..emit(const FoldableState(hinge: Hinge(angle: 90)));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, [90]);
  });

  test('angle updates are opt-in', () async {
    final device = FoldableDevice.instance;
    expect(fake.angleEnabled, isFalse);
    await device.enableAngleUpdates();
    expect(fake.angleEnabled, isTrue);
    await device.disableAngleUpdates();
    expect(fake.angleEnabled, isFalse);
  });

  test('debugOverride replaces platform state until cleared', () async {
    final device = FoldableDevice.instance;
    final seen = <FoldPosture>[];
    final sub = device.postureStream.listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    fake.emit(const FoldableState(posture: FoldPosture.flat));
    await Future<void>.delayed(Duration.zero);

    device.debugOverride(const FoldableState(posture: FoldPosture.tabletop));
    await Future<void>.delayed(Duration.zero);

    // Platform events are suppressed while an override is active.
    fake.emit(const FoldableState(posture: FoldPosture.closed));
    await Future<void>.delayed(Duration.zero);

    device.debugOverride(null);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, [FoldPosture.flat, FoldPosture.tabletop, FoldPosture.closed]);
  });

  // Regression: FoldableBuilder reads stateStream on every build. A getter
  // that returned a fresh stream each time would make StreamBuilder
  // resubscribe on every rebuild and drop the event that caused it.
  test('stateStream identity is stable across reads', () {
    final device = FoldableDevice.instance;
    expect(identical(device.stateStream, device.stateStream), isTrue);
  });

  test('currentState reflects the override', () async {
    final device = FoldableDevice.instance;
    await device.initialize();
    device.debugOverride(const FoldableState(posture: FoldPosture.book));
    expect(device.currentState?.posture, FoldPosture.book);
    device.debugOverride(null);
  });
}
