import 'dart:async';

import 'package:flutter/widgets.dart';

import '../foldable_device.dart';
import '../model/capabilities.dart';
import '../model/display_info.dart';
import '../model/fold_posture.dart';
import '../model/foldable_state.dart';
import '../model/hinge.dart';
import '../platform/foldable_runtime_platform.dart';

/// A scriptable platform implementation for tests.
///
/// Install it with [installFoldableTestPlatform], drive it with
/// [FoldableTestPlatform.setPosture].
class FoldableTestPlatform extends FoldableRuntimePlatform {
  /// Creates a test platform with the given capabilities.
  FoldableTestPlatform({
    this.capabilityOverride = const FoldableCapabilities(
      isFoldable: true,
      hingeAngleSensor: true,
      foldingFeature: true,
      outerDisplay: true,
      raw: <String, bool>{
        'isFoldable': true,
        'hingeAngleSensor': true,
        'foldingFeature': true,
        'outerDisplay': true,
      },
    ),
  });

  /// The capabilities reported to the device under test.
  final FoldableCapabilities capabilityOverride;

  final StreamController<FoldableState> _controller =
      StreamController<FoldableState>.broadcast();

  /// Whether angle updates have been requested.
  bool angleUpdatesEnabled = false;

  @override
  Stream<FoldableState> get states => _controller.stream;

  @override
  Future<FoldableCapabilitiesResult> capabilities() async =>
      FoldableCapabilitiesResult(
        capabilities: capabilityOverride,
        manufacturer: 'test',
        model: 'foldable',
      );

  @override
  Future<void> setAngleUpdatesEnabled(bool enabled) async {
    angleUpdatesEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  /// Emits a state for [posture], filling in a plausible hinge angle and
  /// display feature so widgets under test see a realistic device.
  void setPosture(FoldPosture posture, {double? angle, Size? windowSize}) {
    _controller.add(stateFor(posture, angle: angle, windowSize: windowSize));
  }

  /// Emits an arbitrary state.
  void emit(FoldableState state) => _controller.add(state);

  /// Builds the state this kit would emit for [posture].
  FoldableState stateFor(
    FoldPosture posture, {
    double? angle,
    Size? windowSize,
  }) {
    final resolved = angle ?? _defaultAngle(posture);
    final size = windowSize ?? const Size(800, 900);
    final orientation = switch (posture) {
      FoldPosture.tabletop => Axis.horizontal,
      FoldPosture.book => Axis.vertical,
      _ => null,
    };

    return FoldableState(
      posture: posture,
      hinge: Hinge(
        angle: resolved,
        rawAngle: resolved,
        range: HingeAngleRange.zeroTo180,
        status: switch (posture) {
          FoldPosture.closed || FoldPosture.flipClosed => HingeStatus.closed,
          FoldPosture.flat => HingeStatus.fullyOpen,
          FoldPosture.unknown => HingeStatus.unknown,
          _ => HingeStatus.partiallyOpen,
        },
        orientation: orientation,
      ),
      display: DisplayInfo(
        active: posture.isClosed ? ActiveDisplay.cover : ActiveDisplay.inner,
        logicalSize: size,
        features: orientation == null
            ? const <FoldableDisplayFeature>[]
            : <FoldableDisplayFeature>[
                FoldableDisplayFeature(
                  bounds: orientation == Axis.horizontal
                      ? Rect.fromLTRB(
                          0,
                          size.height / 2 - 1,
                          size.width,
                          size.height / 2 + 1,
                        )
                      : Rect.fromLTRB(
                          size.width / 2 - 1,
                          0,
                          size.width / 2 + 1,
                          size.height,
                        ),
                  isSeparating: true,
                  occlusion: FeatureOcclusion.full,
                  orientation: orientation,
                ),
              ],
      ),
      capabilities: capabilityOverride,
      timestamp: DateTime.now(),
    );
  }

  double _defaultAngle(FoldPosture posture) => switch (posture) {
        FoldPosture.closed || FoldPosture.flipClosed => 0,
        FoldPosture.flat => 180,
        FoldPosture.unknown => 180,
        _ => 90,
      };
}

/// Installs a [FoldableTestPlatform] and returns it.
///
/// Call `addTearDown(FoldableDevice.resetForTesting)` or reset it yourself.
FoldableTestPlatform installFoldableTestPlatform({
  FoldableCapabilities? capabilities,
}) {
  final platform = capabilities == null
      ? FoldableTestPlatform()
      : FoldableTestPlatform(capabilityOverride: capabilities);
  FoldableDevice.setPlatformForTesting(platform);
  return platform;
}
