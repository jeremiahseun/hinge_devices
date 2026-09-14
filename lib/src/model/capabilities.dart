import 'package:flutter/foundation.dart';

/// What this device can actually do.
///
/// Branch on capabilities, never on brand, model or OS version. Unknown
/// capabilities from a newer platform implementation remain readable through
/// [raw], so an app built against this version keeps working on hardware that
/// does not exist yet.
@immutable
class FoldableCapabilities {
  /// Creates a capability set.
  const FoldableCapabilities({
    this.isFoldable = false,
    this.hingeAngleSensor = false,
    this.foldingFeature = false,
    this.outerDisplay = false,
    this.sceneAccessory = false,
    this.rearDisplayTransfer = false,
    this.dualConcurrent = false,
    this.specVersion = 1,
    this.raw = const <String, bool>{},
  });

  /// Everything off — the correct answer for the overwhelming majority of
  /// devices, and the value returned on unsupported platforms.
  static const FoldableCapabilities none = FoldableCapabilities();

  /// Whether this device folds at all.
  final bool isFoldable;

  /// Whether a hinge-angle sensor is present. Independent of
  /// [foldingFeature]: a device may have one, both, or neither.
  final bool hingeAngleSensor;

  /// Whether the platform reports folding-feature geometry.
  final bool foldingFeature;

  /// Whether a cover or outer display exists.
  final bool outerDisplay;

  /// Whether the app can render to a second display while the main UI stays
  /// on the inner one.
  final bool sceneAccessory;

  /// Whether the app can be transferred to a rear display.
  final bool rearDisplayTransfer;

  /// Whether both displays can be driven at once.
  final bool dualConcurrent;

  /// The capability-spec version the platform implementation reported.
  final int specVersion;

  /// Every capability the platform reported, including ones this version of
  /// the package has no typed field for.
  final Map<String, bool> raw;

  /// Returns a copy with the given fields replaced.
  FoldableCapabilities copyWith({
    bool? isFoldable,
    bool? hingeAngleSensor,
    bool? foldingFeature,
    bool? outerDisplay,
    bool? sceneAccessory,
    bool? rearDisplayTransfer,
    bool? dualConcurrent,
  }) {
    return FoldableCapabilities(
      isFoldable: isFoldable ?? this.isFoldable,
      hingeAngleSensor: hingeAngleSensor ?? this.hingeAngleSensor,
      foldingFeature: foldingFeature ?? this.foldingFeature,
      outerDisplay: outerDisplay ?? this.outerDisplay,
      sceneAccessory: sceneAccessory ?? this.sceneAccessory,
      rearDisplayTransfer: rearDisplayTransfer ?? this.rearDisplayTransfer,
      dualConcurrent: dualConcurrent ?? this.dualConcurrent,
      specVersion: specVersion,
      raw: <String, bool>{
        ...raw,
        if (outerDisplay != null) 'outerDisplay': outerDisplay,
        if (isFoldable != null) 'isFoldable': isFoldable,
      },
    );
  }

  /// Reads a capability by name, falling back to [raw] for unknown keys.
  bool operator [](String key) => switch (key) {
        'isFoldable' => isFoldable,
        'hingeAngleSensor' => hingeAngleSensor,
        'foldingFeature' => foldingFeature,
        'outerDisplay' => outerDisplay,
        'sceneAccessory' => sceneAccessory,
        'rearDisplayTransfer' => rearDisplayTransfer,
        'dualConcurrent' => dualConcurrent,
        _ => raw[key] ?? false,
      };

  @override
  bool operator ==(Object other) =>
      other is FoldableCapabilities &&
      other.isFoldable == isFoldable &&
      other.hingeAngleSensor == hingeAngleSensor &&
      other.foldingFeature == foldingFeature &&
      other.outerDisplay == outerDisplay &&
      other.sceneAccessory == sceneAccessory &&
      other.rearDisplayTransfer == rearDisplayTransfer &&
      other.dualConcurrent == dualConcurrent &&
      other.specVersion == specVersion &&
      mapEquals(other.raw, raw);

  @override
  int get hashCode => Object.hash(
        isFoldable,
        hingeAngleSensor,
        foldingFeature,
        outerDisplay,
        sceneAccessory,
        rearDisplayTransfer,
        dualConcurrent,
        specVersion,
      );

  @override
  String toString() => 'FoldableCapabilities(isFoldable: $isFoldable, '
      'hingeAngleSensor: $hingeAngleSensor, foldingFeature: $foldingFeature)';
}
