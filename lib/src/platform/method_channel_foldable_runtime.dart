
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Axis;
import 'package:flutter/services.dart';

import '../model/capabilities.dart';
import '../model/display_info.dart';
import '../model/foldable_state.dart';
import '../model/hinge.dart';
import '../model/posture_resolver.dart';
import '../model/posture_thresholds.dart';
import '../model/quirks.dart';
import 'foldable_runtime_platform.dart';

/// Decoded platform signals, before posture is derived.
///
/// The native side reports *facts* (a folding feature, a sensor reading) and
/// this package derives *meaning*. Keeping derivation in Dart means the rules
/// are identical on every platform and testable without a device.
@immutable
class _PlatformSignals {
  const _PlatformSignals({
    this.featureState,
    this.featureOrientation,
    this.rawAngle,
    this.display = DisplayInfo.empty,
  });

  final FoldingFeatureState? featureState;
  final Axis? featureOrientation;
  final double? rawAngle;
  final DisplayInfo display;
}

/// The Android implementation, over a method channel and an event channel.
class MethodChannelFoldableRuntime extends FoldableRuntimePlatform {
  /// Creates the channel-backed implementation.
  MethodChannelFoldableRuntime({
    PostureThresholds thresholds = PostureThresholds.standard,
  }) : _resolver = PostureResolver(thresholds: thresholds);

  /// The method channel used for one-shot calls.
  @visibleForTesting
  static const MethodChannel methodChannel =
      MethodChannel('dev.jeremiahseun/foldable_runtime');

  /// The event channel carrying device-state updates.
  @visibleForTesting
  static const EventChannel eventChannel =
      EventChannel('dev.jeremiahseun/foldable_runtime/events');

  final PostureResolver _resolver;

  Stream<FoldableState>? _states;
  FoldableCapabilities _capabilities = FoldableCapabilities.none;
  HingeNormalizer _normalizer = const HingeNormalizer(HingeQuirk.assumed);

  @override
  Stream<FoldableState> get states {
    return _states ??= eventChannel
        .receiveBroadcastStream()
        .map<FoldableState>(_decode)
        .handleError((Object error, StackTrace stack) {
      // A platform that stops reporting must not take the app down with it.
      debugPrint('foldable_runtime: state stream error: $error');
    });
  }

  @override
  Future<FoldableCapabilitiesResult> capabilities() async {
    final Map<Object?, Object?>? reply =
        await methodChannel.invokeMethod<Map<Object?, Object?>>('capabilities');
    if (reply == null) {
      return const FoldableCapabilitiesResult(
        capabilities: FoldableCapabilities.none,
      );
    }

    final raw = <String, bool>{
      for (final entry in reply.entries)
        if (entry.value is bool) entry.key.toString(): entry.value! as bool,
    };

    _capabilities = FoldableCapabilities(
      isFoldable: raw['isFoldable'] ?? false,
      hingeAngleSensor: raw['hingeAngleSensor'] ?? false,
      foldingFeature: raw['foldingFeature'] ?? false,
      outerDisplay: raw['outerDisplay'] ?? false,
      sceneAccessory: raw['sceneAccessory'] ?? false,
      rearDisplayTransfer: raw['rearDisplayTransfer'] ?? false,
      dualConcurrent: raw['dualConcurrent'] ?? false,
      specVersion: (reply['specVersion'] as int?) ?? 1,
      raw: raw,
    );

    final manufacturer = reply['manufacturer'] as String?;
    final model = reply['model'] as String?;
    _normalizer = HingeNormalizer(FoldableQuirks.lookup(manufacturer, model));

    return FoldableCapabilitiesResult(
      capabilities: _capabilities,
      manufacturer: manufacturer,
      model: model,
    );
  }

  @override
  Future<void> setAngleUpdatesEnabled(bool enabled) {
    return methodChannel.invokeMethod<void>(
      'setAngleUpdatesEnabled',
      <String, Object?>{'enabled': enabled},
    );
  }

  @override
  Future<void> dispose() async {
    _states = null;
  }

  FoldableState _decode(Object? event) {
    final map = (event as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
    final signals = _decodeSignals(map);

    final angle = _normalizer.normalize(signals.rawAngle);
    final posture = _resolver.resolve(
      featureState: signals.featureState,
      featureOrientation: signals.featureOrientation,
      angle: angle,
      hasOuterDisplay: _capabilities.outerDisplay,
    );

    return FoldableState(
      posture: posture,
      hinge: Hinge(
        angle: angle,
        rawAngle: signals.rawAngle,
        range: _normalizer.quirk.range,
        status: _resolver.statusFor(angle),
        orientation: signals.featureOrientation,
      ),
      display: signals.display,
      capabilities: _capabilities,
      timestamp: DateTime.now(),
    );
  }

  _PlatformSignals _decodeSignals(Map<Object?, Object?> map) {
    final featureState = switch (map['featureState'] as String?) {
      'flat' => FoldingFeatureState.flat,
      'halfOpened' => FoldingFeatureState.halfOpened,
      _ => null,
    };
    final orientation = switch (map['featureOrientation'] as String?) {
      'horizontal' => Axis.horizontal,
      'vertical' => Axis.vertical,
      _ => null,
    };

    final features = <FoldableDisplayFeature>[];
    final rawFeatures = map['features'] as List<Object?>? ?? const <Object?>[];
    for (final raw in rawFeatures) {
      final f = raw as Map<Object?, Object?>?;
      if (f == null) continue;
      features.add(
        FoldableDisplayFeature(
          bounds: Rect.fromLTRB(
            (f['left'] as num? ?? 0).toDouble(),
            (f['top'] as num? ?? 0).toDouble(),
            (f['right'] as num? ?? 0).toDouble(),
            (f['bottom'] as num? ?? 0).toDouble(),
          ),
          isSeparating: f['isSeparating'] as bool? ?? false,
          occlusion: switch (f['occlusion'] as String?) {
            'none' => FeatureOcclusion.none,
            'full' => FeatureOcclusion.full,
            _ => FeatureOcclusion.unknown,
          },
          orientation: orientation,
        ),
      );
    }

    final width = (map['windowWidth'] as num?)?.toDouble();
    final height = (map['windowHeight'] as num?)?.toDouble();

    return _PlatformSignals(
      featureState: featureState,
      featureOrientation: orientation,
      rawAngle: (map['hingeAngle'] as num?)?.toDouble(),
      display: DisplayInfo(
        active: switch (map['activeDisplay'] as String?) {
          'inner' => ActiveDisplay.inner,
          'outer' => ActiveDisplay.outer,
          'cover' => ActiveDisplay.cover,
          'rear' => ActiveDisplay.rear,
          _ => ActiveDisplay.unknown,
        },
        features: features,
        logicalSize:
            width != null && height != null ? Size(width, height) : null,
      ),
    );
  }
}
