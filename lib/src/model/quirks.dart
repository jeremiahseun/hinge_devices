import 'package:flutter/foundation.dart';

import 'hinge.dart';

/// A per-device correction applied to raw hinge readings.
///
/// Vendors disagree about hinge convention: most report `0` closed to `180`
/// flat, some report a `0`-`360` sweep, and at least one inverts the scale.
/// Corrections live in data rather than in code because they change faster
/// than this package's release cadence.
@immutable
class HingeQuirk {
  /// Creates a quirk entry.
  const HingeQuirk({
    required this.range,
    this.inverted = false,
    this.offset = 0,
    this.resolution = HingeResolution.unknown,
    this.detentValues = const <double>[],
  });

  /// The convention this device reports in.
  final HingeAngleRange range;

  /// Whether the device reports `180` closed and `0` flat.
  final bool inverted;

  /// A constant added to the raw reading before normalisation.
  final double offset;

  /// Whether this device's sensor sweeps or only reports at fixed positions.
  final HingeResolution resolution;

  /// The fixed positions a detent-reporting device produces.
  final List<double> detentValues;

  /// The assumed behaviour when a device is not in the quirks table.
  ///
  /// Resolution is [HingeResolution.unknown] rather than
  /// [HingeResolution.continuous] on purpose: assuming a smooth sweep and
  /// being wrong produces an effect that visibly snaps, which is worse than
  /// not offering the effect.
  static const HingeQuirk assumed =
      HingeQuirk(range: HingeAngleRange.zeroTo180);
}

/// Normalises raw hinge readings to `0` closed, `180` flat.
class HingeNormalizer {
  /// Creates a normaliser for a device.
  const HingeNormalizer(this.quirk);

  /// The correction for the current device.
  final HingeQuirk quirk;

  /// Normalises [raw] to the canonical `0`-`180` scale.
  ///
  /// Returns `null` for a `null` input so a missing sensor never becomes a
  /// misleading `0`.
  double? normalize(double? raw) {
    if (raw == null) return null;
    var value = raw + quirk.offset;

    switch (quirk.range) {
      case HingeAngleRange.zeroTo360:
        // Past 180 the device is folding back on itself; mirror it so the
        // canonical scale stays monotonic from closed to flat.
        if (value > 180) value = 360 - value;
      case HingeAngleRange.zeroTo180:
      case HingeAngleRange.unknown:
        break;
    }

    if (quirk.inverted) value = 180 - value;
    return value.clamp(0.0, 180.0);
  }
}

/// The shipped quirks table, keyed by `manufacturer/model` lowercased.
///
/// Entries are contributed from device reports (see `tool/report_device.dart`).
/// Override or extend at runtime with [FoldableQuirks.register].
class FoldableQuirks {
  FoldableQuirks._();

  /// Quirks shipped with the package, measured on real hardware.
  ///
  /// See `doc/devices.md` for how each entry was obtained. Entries live in
  /// data rather than in logic because they change faster than this package's
  /// release cadence, and because the people who own the hardware are the
  /// ones who can measure it.
  static final Map<String, HingeQuirk> _shipped = <String, HingeQuirk>{
    // Galaxy Z Flip 5. Measured 2026-09-14: the sensor reports exactly three
    // values across the device's whole range, however slowly it is folded.
    // Continuous angle-driven effects are not buildable here.
    'samsung/sm-f731n': const HingeQuirk(
      range: HingeAngleRange.zeroTo180,
      resolution: HingeResolution.detents,
      detentValues: <double>[0, 90, 180],
    ),
  };

  static final Map<String, HingeQuirk> _table = <String, HingeQuirk>{};

  /// Registers or replaces a quirk for a device key.
  ///
  /// The key is `manufacturer/model`, lowercased, e.g. `samsung/sm-f956b`.
  static void register(String deviceKey, HingeQuirk quirk) {
    _table[deviceKey.toLowerCase()] = quirk;
  }

  /// Looks up a device, falling back to a manufacturer-wide entry and then to
  /// [HingeQuirk.assumed].
  static HingeQuirk lookup(String? manufacturer, String? model) {
    if (manufacturer == null) return HingeQuirk.assumed;
    final manufacturerKey = manufacturer.toLowerCase();
    final deviceKey = '$manufacturerKey/${model?.toLowerCase() ?? ''}';
    // Runtime registrations win over shipped entries, so an app can correct
    // a bad entry without waiting for a release.
    return _table[deviceKey] ??
        _table['$manufacturerKey/*'] ??
        _shipped[deviceKey] ??
        _shipped['$manufacturerKey/*'] ??
        HingeQuirk.assumed;
  }

  /// Removes all registered quirks. Test-only.
  @visibleForTesting
  static void reset() => _table.clear();
}
