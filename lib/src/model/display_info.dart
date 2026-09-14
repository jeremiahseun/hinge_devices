import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis;

/// Which physical display the app is currently rendering on.
enum ActiveDisplay {
  /// The large, inner display of a book-style foldable.
  inner,

  /// The outer display used while the device is folded.
  outer,

  /// A small cover display, e.g. a Flip-class Flex Window.
  cover,

  /// A rear-facing display, reachable via display transfer.
  rear,

  /// Not reported by this platform.
  unknown,
}

/// What a display feature does to the pixels underneath it.
enum FeatureOcclusion {
  /// Content behind the feature is still visible.
  none,

  /// The feature hides content behind it.
  full,

  /// Not reported.
  unknown,
}

/// A physical discontinuity in the display — a hinge or a fold.
@immutable
class FoldableDisplayFeature {
  /// Creates a display feature.
  const FoldableDisplayFeature({
    required this.bounds,
    required this.isSeparating,
    this.occlusion = FeatureOcclusion.unknown,
    this.orientation,
  });

  /// The feature's bounds in logical pixels, relative to the app window.
  final Rect bounds;

  /// Whether the feature splits the window into two logical areas that should
  /// be laid out independently.
  final bool isSeparating;

  /// Whether content behind the feature is visible.
  final FeatureOcclusion occlusion;

  /// The feature's axis, when reported.
  final Axis? orientation;

  @override
  bool operator ==(Object other) =>
      other is FoldableDisplayFeature &&
      other.bounds == bounds &&
      other.isSeparating == isSeparating &&
      other.occlusion == occlusion &&
      other.orientation == orientation;

  @override
  int get hashCode => Object.hash(bounds, isSeparating, occlusion, orientation);

  @override
  String toString() =>
      'FoldableDisplayFeature($bounds, separating: $isSeparating)';
}

/// Information about the display the app currently occupies.
@immutable
class DisplayInfo {
  /// Creates display information.
  const DisplayInfo({
    this.active = ActiveDisplay.unknown,
    this.features = const <FoldableDisplayFeature>[],
    this.logicalSize,
  });

  /// An empty description, for devices that report nothing.
  static const DisplayInfo empty = DisplayInfo();

  /// Which physical display is in use.
  final ActiveDisplay active;

  /// Display features intersecting the app window.
  final List<FoldableDisplayFeature> features;

  /// The window's logical size, when reported by the platform.
  final Size? logicalSize;

  /// True when any feature splits the window into independent panes.
  bool get isSeparating => features.any((f) => f.isSeparating);

  @override
  bool operator ==(Object other) =>
      other is DisplayInfo &&
      other.active == active &&
      other.logicalSize == logicalSize &&
      listEquals(other.features, features);

  @override
  int get hashCode =>
      Object.hash(active, logicalSize, Object.hashAll(features));

  @override
  String toString() =>
      'DisplayInfo(active: $active, features: ${features.length})';
}
