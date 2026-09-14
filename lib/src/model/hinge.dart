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

/// How finely a device's hinge sensor actually reports.
///
/// Nothing in Android's API says whether `TYPE_HINGE_ANGLE` sweeps through
/// intermediate values or only fires at fixed positions, and no vendor
/// documents it — but it decides whether a continuous angle-driven effect is
/// buildable at all. A Galaxy Z Flip 5 reports exactly three values, so an
/// effect that maps hinge angle onto a slider has three states on that
/// device, not a smooth range.
///
/// Check this before building an angle-driven experience, the same way you
/// check [FoldableCapabilities.hingeAngleSensor] before assuming an angle
/// exists at all.
enum HingeResolution {
  /// The sensor sweeps: intermediate angles are reported as the device moves.
  continuous,

  /// The sensor only reports at fixed positions. Angle is still usable as a
  /// coarse signal, but not for continuous effects.
  detents,

  /// Not yet known for this device. Treat as [continuous] only if you degrade
  /// gracefully; the safe assumption is that it may be [detents].
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
    this.resolution = HingeResolution.unknown,
    this.detentValues = const <double>[],
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

  /// How finely this device's sensor reports.
  final HingeResolution resolution;

  /// The fixed positions this device reports, when [resolution] is
  /// [HingeResolution.detents]. Empty otherwise.
  final List<double> detentValues;

  /// Whether a continuous angle-driven effect is worth building here.
  ///
  /// False on a device that only reports at detents — prefer posture-driven
  /// UI there, or accept that your effect will snap between a few positions.
  bool get supportsContinuousEffects =>
      resolution == HingeResolution.continuous;

  /// Returns a copy with the given fields replaced.
  Hinge copyWith({
    double? angle,
    double? rawAngle,
    HingeAngleRange? range,
    HingeStatus? status,
    Axis? orientation,
    HingeResolution? resolution,
    List<double>? detentValues,
  }) {
    return Hinge(
      angle: angle ?? this.angle,
      rawAngle: rawAngle ?? this.rawAngle,
      range: range ?? this.range,
      status: status ?? this.status,
      orientation: orientation ?? this.orientation,
      resolution: resolution ?? this.resolution,
      detentValues: detentValues ?? this.detentValues,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Hinge &&
      other.angle == angle &&
      other.rawAngle == rawAngle &&
      other.range == range &&
      other.status == status &&
      other.orientation == orientation &&
      other.resolution == resolution &&
      listEquals(other.detentValues, detentValues);

  @override
  int get hashCode => Object.hash(
        angle,
        rawAngle,
        range,
        status,
        orientation,
        resolution,
        Object.hashAll(detentValues),
      );

  @override
  String toString() =>
      'Hinge(angle: $angle, status: $status, resolution: ${resolution.name})';
}
