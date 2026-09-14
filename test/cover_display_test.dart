import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

import 'fake_platform.dart';

/// Android exposes no public API for "am I on the cover screen", and on
/// Flip-class hardware both panels are often the same logical display that
/// resizes, so enumeration cannot see it either. A Z Flip 5 reported
/// `outerDisplay: false` and `activeDisplay: unknown` while running on its
/// Flex Window.
///
/// The deduction that fixes it: a device that is shut and still drawing must
/// be drawing on an outer panel. That is inference from a real signal rather
/// than a size heuristic, and it is correct on the very first launch.
void main() {
  group('capability copyWith', () {
    test('a learned capability lands in the raw map too', () {
      const base = FoldableCapabilities(
        isFoldable: true,
        raw: <String, bool>{'isFoldable': true, 'outerDisplay': false},
      );
      final learned = base.copyWith(outerDisplay: true);

      expect(learned.outerDisplay, isTrue);
      expect(
        learned['outerDisplay'],
        isTrue,
        reason: 'raw reads must agree with typed reads',
      );
      expect(learned.isFoldable, isTrue, reason: 'untouched fields survive');
    });

    test('specVersion is preserved', () {
      const base = FoldableCapabilities(specVersion: 7);
      expect(base.copyWith(outerDisplay: true).specVersion, 7);
    });
  });

  group('posture for a shut device', () {
    late FakeFoldableRuntime fake;

    setUp(() {
      fake = FakeFoldableRuntime();
      FoldableDevice.setPlatformForTesting(fake);
    });

    tearDown(FoldableDevice.resetForTesting);

    test('flipClosed is reported once an outer display is known', () async {
      final device = FoldableDevice.instance;
      final seen = <FoldPosture>[];
      final sub = device.postureStream.listen(seen.add);
      await Future<void>.delayed(Duration.zero);

      fake.emit(
        const FoldableState(
          posture: FoldPosture.flipClosed,
          capabilities: FoldableCapabilities(
            isFoldable: true,
            outerDisplay: true,
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(seen, [FoldPosture.flipClosed]);
      expect(seen.single.coarse, CoarsePosture.closed);
    });
  });

  group('thresholds drive the deduction', () {
    test('the resolver exposes its thresholds for reuse', () {
      const resolver = PostureResolver(
        thresholds: PostureThresholds(closedAtOrBelow: 20),
      );
      expect(resolver.thresholds.closedAtOrBelow, 20);

      // The same boundary that decides "closed" decides "this must be an
      // outer panel", so they can never disagree.
      expect(resolver.resolve(angle: 20), FoldPosture.closed);
      expect(resolver.resolve(angle: 21), FoldPosture.halfOpened);
    });
  });
}
