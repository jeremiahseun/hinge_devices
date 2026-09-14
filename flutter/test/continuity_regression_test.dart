import 'package:flutter/painting.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:hinge_devices/hinge_devices.dart';

/// Regression tests for the two ways posture has gone wrong on a physical
/// Galaxy Z Flip.
///
/// 1. It stayed closed after the device was opened, because the hinge reading
///    was stale across the activity recreation that unfolding causes.
/// 2. It reported an open posture while the app was running on the cover
///    screen, because an over-correction for (1) let a folding feature
///    outrank a perfectly fresh closed angle.
///
/// The rule that satisfies both: a closed angle wins, and staleness is fixed
/// at the sensor rather than papered over in the resolver. A reading held
/// across an unregister is cleared, so a stale angle arrives as null — and
/// null never resolves to closed.
void main() {
  const resolver = PostureResolver();

  group('running on the cover screen', () {
    test('a fresh closed angle outranks a reported folding feature', () {
      expect(
        resolver.resolve(
          featureState: FoldingFeatureState.flat,
          angle: 0,
          hasOuterDisplay: true,
        ),
        FoldPosture.flipClosed,
        reason: 'a shut Flip must not render its opened layout',
      );
    });

    test('flipClosed is reported when the device has a cover display', () {
      expect(
        resolver.resolve(angle: 0, hasOuterDisplay: true),
        FoldPosture.flipClosed,
      );
    });

    test('closed is reported when it does not', () {
      expect(resolver.resolve(angle: 0), FoldPosture.closed);
    });
  });

  group('opening the device', () {
    test('a cleared reading does not resolve to closed', () {
      // The sensor clears lastAngle when it is unregistered, so a stale
      // reading reaches the resolver as null rather than as zero.
      expect(
        resolver.resolve(featureState: FoldingFeatureState.flat),
        FoldPosture.flat,
      );
    });

    test('a null angle with no feature stays unknown, never closed', () {
      expect(resolver.resolve(), FoldPosture.unknown);
    });

    test('the full close-then-open sequence resolves correctly', () {
      // 1. Shut, app on the cover screen.
      var posture = resolver.resolve(
        featureState: FoldingFeatureState.flat,
        angle: 0,
        hasOuterDisplay: true,
      );
      expect(posture, FoldPosture.flipClosed);

      // 2. Opening. The sensor stays registered through the configuration
      //    change, so the reading is current rather than cleared or stale.
      posture = resolver.resolve(
        featureState: FoldingFeatureState.halfOpened,
        featureOrientation: Axis.horizontal,
        angle: 95,
        hasOuterDisplay: true,
      );
      expect(posture, FoldPosture.tabletop);

      // 3. Fully open.
      posture = resolver.resolve(
        featureState: FoldingFeatureState.flat,
        angle: 180,
        hasOuterDisplay: true,
      );
      expect(posture, FoldPosture.flat);
    });

    test('a full detach clears the reading rather than holding it', () {
      // Worst case: the activity is destroyed, the sensor is unregistered,
      // and the folding feature arrives first. Unknown is a recoverable
      // answer; closed is not.
      expect(
        resolver.resolve(hasOuterDisplay: true),
        FoldPosture.unknown,
      );
    });
  });
}
