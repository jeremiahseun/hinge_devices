import 'package:flutter/foundation.dart';

/// Angle boundaries used to derive posture when no folding feature is
/// available.
///
/// Hinge conventions differ between vendors, so these are never hard-coded
/// into the derivation logic. Override them per app, or per device via a
/// quirks entry.
@immutable
class PostureThresholds {
  /// Creates a threshold set. Angles are in normalised degrees where
  /// `0` is fully closed and `180` is fully flat.
  const PostureThresholds({
    this.closedAtOrBelow = 15,
    this.flatAtOrAbove = 165,
  }) : assert(
          closedAtOrBelow < flatAtOrAbove,
          'closedAtOrBelow must be less than flatAtOrAbove',
        );

  /// Angles at or below this value are treated as closed.
  final double closedAtOrBelow;

  /// Angles at or above this value are treated as flat.
  final double flatAtOrAbove;

  /// The default thresholds: closed below 15 degrees, flat above 165.
  static const PostureThresholds standard = PostureThresholds();

  /// Returns a copy with the given fields replaced.
  PostureThresholds copyWith({double? closedAtOrBelow, double? flatAtOrAbove}) {
    return PostureThresholds(
      closedAtOrBelow: closedAtOrBelow ?? this.closedAtOrBelow,
      flatAtOrAbove: flatAtOrAbove ?? this.flatAtOrAbove,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PostureThresholds &&
      other.closedAtOrBelow == closedAtOrBelow &&
      other.flatAtOrAbove == flatAtOrAbove;

  @override
  int get hashCode => Object.hash(closedAtOrBelow, flatAtOrAbove);

  @override
  String toString() =>
      'PostureThresholds(closed<=$closedAtOrBelow, flat>=$flatAtOrAbove)';
}
