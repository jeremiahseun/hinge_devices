import 'package:flutter/foundation.dart';

import '../model/capabilities.dart';
import '../model/foldable_state.dart';

/// The contract every platform implementation fulfils.
///
/// Implementations must never throw: a device that reports nothing returns
/// [FoldableState.rigid] and empty capabilities. Adding this package to an
/// app must not be able to break it.
abstract class HingeDevicesPlatform {
  /// Const constructor for subclasses.
  const HingeDevicesPlatform();

  /// A stream of complete device states, as the platform produces them.
  ///
  /// Implementations emit raw states; deduplication and throttling happen in
  /// [FoldableDevice], so every implementation stays trivial.
  Stream<FoldableState> get states;

  /// Reads capabilities once. Callers cache the result.
  Future<FoldableCapabilitiesResult> capabilities();

  /// Reads live platform diagnostics.
  ///
  /// Separate from [capabilities] because capabilities are cached on first
  /// read, and the useful diagnostics — how many readings the sensor has
  /// delivered, how many distinct values it has ever produced — are all about
  /// what has happened since.
  Future<Map<String, Object?>> diagnostics() async => const <String, Object?>{};

  /// Turns the hinge-angle stream on or off.
  ///
  /// Angle updates are opt-in because they are the only part of this package
  /// that can measurably cost battery.
  Future<void> setAngleUpdatesEnabled(bool enabled);

  /// Releases platform resources.
  Future<void> dispose();
}

/// The result of a capability query, including device identity used for
/// quirk lookup.
@immutable
class FoldableCapabilitiesResult {
  /// Creates a capability result.
  const FoldableCapabilitiesResult({
    required this.capabilities,
    this.manufacturer,
    this.model,
    this.diagnostics = const <String, Object?>{},
  });

  /// The device's capabilities.
  final FoldableCapabilities capabilities;

  /// Device manufacturer, for quirk lookup.
  final String? manufacturer;

  /// Device model, for quirk lookup.
  final String? model;

  /// Non-capability platform values useful when diagnosing a device — sensor
  /// event counts, vendor identifiers. Contents are platform-specific and not
  /// part of the stable API.
  final Map<String, Object?> diagnostics;
}
