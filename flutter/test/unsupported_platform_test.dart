import 'package:flutter_test/flutter_test.dart';
import 'package:hinge_devices/hinge_devices.dart';

void main() {
  // The single most important guarantee this package makes: adding it to an
  // app that will never run on a foldable must not be able to break anything.
  test('reports a rigid device and never emits', () async {
    FoldableDevice.setPlatformForTesting(const UnsupportedHingeDevices());
    addTearDown(FoldableDevice.resetForTesting);

    final device = FoldableDevice.instance;
    final capabilities = await device.capabilities;

    expect(capabilities.isFoldable, isFalse);
    expect(capabilities.hingeAngleSensor, isFalse);
    // The state stream stays open forever on every platform, so assert that
    // nothing arrives rather than that it closes.
    final received = <FoldableState>[];
    final sub = device.stateStream.listen(received.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();
    expect(received, isEmpty);

    // Every call is a safe no-op rather than a platform exception.
    await device.enableAngleUpdates();
    await device.disableAngleUpdates();
    await device.initialize();
  });

  test('unknown capabilities remain readable through raw', () {
    const caps = FoldableCapabilities(
      isFoldable: true,
      raw: <String, bool>{'isFoldable': true, 'triFold': true},
    );
    expect(caps['isFoldable'], isTrue);
    expect(caps['triFold'], isTrue, reason: 'forward-compatible read');
    expect(caps['inventedCapability'], isFalse);
  });
}
