import 'package:flutter/painting.dart' show Axis;

import 'fold_posture.dart';
import 'hinge.dart';
import 'posture_thresholds.dart';

/// The folding-feature state a platform reports, independent of angle.
enum FoldingFeatureState {
  /// The device presents one continuous surface.
  flat,

  /// The device is partially folded.
  halfOpened,
}

/// Derives posture from the signals a platform provides.
///
/// Display-feature geometry wins over angle. Both Android's and Apple's own
/// guidance is that layout follows the folding feature — angle is for effects
/// — and this resolver encodes that ordering. Angle is only consulted to
/// detect [FoldPosture.closed] (which no folding feature reports) and as a
/// fallback when no folding feature is present at all.
class PostureResolver {
  /// Creates a resolver.
  const PostureResolver({this.thresholds = PostureThresholds.standard});

  /// The angle boundaries used for the angle-only fallback.
  final PostureThresholds thresholds;

  /// Resolves a posture.
  ///
  /// [featureState] and [featureOrientation] come from the platform's folding
  /// feature; [angle] is the normalised hinge angle, or `null` when the device
  /// has no sensor. [hasOuterDisplay] selects between [FoldPosture.closed] and
  /// [FoldPosture.flipClosed].
  FoldPosture resolve({
    FoldingFeatureState? featureState,
    Axis? featureOrientation,
    double? angle,
    bool hasOuterDisplay = false,
  }) {
    // Closed is angle-only, and *only* when no folding feature is reported.
    //
    // A folded device reports no folding feature at all, so the presence of
    // one is proof the device is open. Trusting a low angle over a live
    // folding feature is how a Flip that has just been opened stays stuck on
    // its closed layout: the activity is recreated during the transition and
    // the last sensor reading is still the closed one.
    if (featureState == null &&
        angle != null &&
        angle <= thresholds.closedAtOrBelow) {
      return hasOuterDisplay ? FoldPosture.flipClosed : FoldPosture.closed;
    }

    if (featureState != null) {
      return switch (featureState) {
        FoldingFeatureState.flat => FoldPosture.flat,
        FoldingFeatureState.halfOpened => switch (featureOrientation) {
            // A horizontal fold splits the window top/bottom: tabletop.
            Axis.horizontal => FoldPosture.tabletop,
            // A vertical fold splits it left/right: book.
            Axis.vertical => FoldPosture.book,
            null => FoldPosture.halfOpened,
          },
      };
    }

    if (angle != null) {
      if (angle >= thresholds.flatAtOrAbove) return FoldPosture.flat;
      return FoldPosture.halfOpened;
    }

    return FoldPosture.unknown;
  }

  /// Derives the coarse [HingeStatus] that mirrors Apple's `hinge.status`.
  HingeStatus statusFor(double? angle) {
    if (angle == null) return HingeStatus.unknown;
    if (angle <= thresholds.closedAtOrBelow) return HingeStatus.closed;
    if (angle >= thresholds.flatAtOrAbove) return HingeStatus.fullyOpen;
    return HingeStatus.partiallyOpen;
  }
}
