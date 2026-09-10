import 'package:flutter/foundation.dart';

import 'capabilities.dart';
import 'display_info.dart';
import 'fold_posture.dart';
import 'hinge.dart';

/// A single, complete description of the device's physical state.
@immutable
class FoldableState {
  /// Creates a device state.
  const FoldableState({
    this.posture = FoldPosture.unknown,
    this.hinge = Hinge.none,
    this.display = DisplayInfo.empty,
    this.capabilities = FoldableCapabilities.none,
    this.timestamp,
  });

  /// The state reported for a device that does not fold.
  static const FoldableState rigid = FoldableState();

  /// The device's physical posture. This is the value you should lay out
  /// against.
  final FoldPosture posture;

  /// Hinge readings. Use these for effects, not layout.
  final Hinge hinge;

  /// The display the app currently occupies.
  final DisplayInfo display;

  /// What this device can do.
  final FoldableCapabilities capabilities;

  /// When this state was produced.
  final DateTime? timestamp;

  /// Returns a copy with the given fields replaced.
  FoldableState copyWith({
    FoldPosture? posture,
    Hinge? hinge,
    DisplayInfo? display,
    FoldableCapabilities? capabilities,
    DateTime? timestamp,
  }) {
    return FoldableState(
      posture: posture ?? this.posture,
      hinge: hinge ?? this.hinge,
      display: display ?? this.display,
      capabilities: capabilities ?? this.capabilities,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Equality that ignores [timestamp] and [Hinge.angle], so consecutive
  /// states that differ only by an angle wiggle compare equal.
  ///
  /// This is what the posture stream deduplicates on.
  bool sameLayoutAs(FoldableState other) =>
      other.posture == posture &&
      other.display == display &&
      other.capabilities == capabilities &&
      other.hinge.status == hinge.status &&
      other.hinge.orientation == hinge.orientation;

  @override
  bool operator ==(Object other) =>
      other is FoldableState &&
      other.posture == posture &&
      other.hinge == hinge &&
      other.display == display &&
      other.capabilities == capabilities &&
      other.timestamp == timestamp;

  @override
  int get hashCode =>
      Object.hash(posture, hinge, display, capabilities, timestamp);

  @override
  String toString() =>
      'FoldableState(posture: $posture, hinge: $hinge, display: $display)';
}
