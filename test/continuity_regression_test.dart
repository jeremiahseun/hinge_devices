import 'package:flutter/painting.dart' show Axis;
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

/// Regression tests for the Flip that stayed on its closed layout after being
/// opened.
///
/// The activity is recreated during the fold transition, so the last hinge
/// reading is still the closed one when the first post-open state arrives. A
/// folding feature is only ever reported by an open device, so its presence
/// must outrank a low angle.
void main() {
  const resolver = PostureResolver();

  test('a folding feature outranks a stale closed angle', () {
    expect(
      resolver.resolve(
        featureState: FoldingFeatureState.flat,
        angle: 0,
        hasOuterDisplay: true,
      ),
      FoldPosture.flat,
      reason: 'device reporting a folding feature cannot be shut',
    );
  });

  test('a stale closed angle does not mask a half-opened feature', () {
    expect(
      resolver.resolve(
        featureState: FoldingFeatureState.halfOpened,
        featureOrientation: Axis.horizontal,
        angle: 3,
        hasOuterDisplay: true,
      ),
      FoldPosture.tabletop,
    );
  });

  test('closed is still reported when no folding feature exists', () {
    expect(
      resolver.resolve(angle: 0, hasOuterDisplay: true),
      FoldPosture.flipClosed,
    );
    expect(resolver.resolve(angle: 0), FoldPosture.closed);
  });

  test('a null angle with no feature stays unknown', () {
    // The sensor clears its reading when it is unregistered rather than
    // holding a stale one, so null must not be read as closed.
    expect(resolver.resolve(), FoldPosture.unknown);
  });

  test('the full close-then-open sequence resolves correctly', () {
    // 1. Shut: no folding feature, angle at zero.
    var posture = resolver.resolve(angle: 0, hasOuterDisplay: true);
    expect(posture, FoldPosture.flipClosed);

    // 2. Opening, activity recreated: feature arrives before a fresh reading.
    posture = resolver.resolve(
      featureState: FoldingFeatureState.flat,
      angle: 0,
      hasOuterDisplay: true,
    );
    expect(posture, FoldPosture.flat, reason: 'this is the bug that shipped');

    // 3. Sensor catches up.
    posture = resolver.resolve(
      featureState: FoldingFeatureState.flat,
      angle: 180,
      hasOuterDisplay: true,
    );
    expect(posture, FoldPosture.flat);
  });
}
