import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis;

/// The angular convention a device's hinge sensor reports in.
enum HingeAngleRange {
  /// `0` closed to `180` flat — the common case.
  zeroTo180,

  /// `0` closed to `360` fully reversed.
  zeroTo360,

  /// Convention not known; [Hinge.angle] falls back to the raw value.
  unknown,
}

/// A coarse hinge state, mirroring Apple's `hinge.status`.
enum HingeStatus {
  /// Hinge is shut.
  closed,

  /// Hinge is somewhere between shut and flat.
  partiallyOpen,

  /// Hinge is fully open.
  fullyOpen,

  /// No hinge signal available.
  unknown,
}

/// Hinge readings for the current device.
///
/// [angle] is `null` on devices without a hinge-angle sensor, which is most
/// devices — always null-check it rather than defaulting to `0`.
@immutable
class Hinge {
  /// Creates a hinge reading.
  const Hinge({
    this.angle,
    this.rawAngle,
    this.range = HingeAngleRange.unknown,
    this.status = HingeStatus.unknown,
    this.orientation,
  });

  /// A hinge with no readings, for devices with no sensor.
  static const Hinge none = Hinge();

  /// Normalised angle in degrees: `0` fully closed, `180` fully flat.
  ///
  /// `null` when the device has no hinge-angle sensor.
  final double? angle;

  /// The untouched platform value, before normalisation. Useful when filing
  /// a device-quirk report.
  final double? rawAngle;

  /// The convention [rawAngle] was reported in.
  final HingeAngleRange range;

  /// Coarse hinge state.
  final HingeStatus status;

  /// The fold's axis, when a folding feature reports one.
  final Axis? orientation;

  /// Returns a copy with the given fields replaced.
  Hinge copyWith({
    double? angle,
    double? rawAngle,
    HingeAngleRange? range,
    HingeStatus? status,
    Axis? orientation,
  }) {
    return Hinge(
      angle: angle ?? this.angle,
      rawAngle: rawAngle ?? this.rawAngle,
      range: range ?? this.range,
      status: status ?? this.status,
      orientation: orientation ?? this.orientation,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Hinge &&
      other.angle == angle &&
      other.rawAngle == rawAngle &&
      other.range == range &&
      other.status == status &&
      other.orientation == orientation;

  @override
  int get hashCode =>
      Object.hash(angle, rawAngle, range, status, orientation);

  @override
  String toString() => 'Hinge(angle: $angle, status: $status)';
}
