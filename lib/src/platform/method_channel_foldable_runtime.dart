
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

  // Learned once, kept for the session. See _learnOuterDisplay.
  bool _learnedOuterDisplay = false;
  double _largestWindowArea = 0;

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
      diagnostics: <String, Object?>{
        for (final entry in reply.entries)
          if (entry.value is! bool) entry.key.toString(): entry.value,
      },
    );
  }

  @override
  Future<Map<String, Object?>> diagnostics() async {
    final reply =
        await methodChannel.invokeMethod<Map<Object?, Object?>>('diagnostics');
    return <String, Object?>{
      for (final entry in reply?.entries ?? const <MapEntry<Object?, Object?>>[])
        entry.key.toString(): entry.value,
      'learnedOuterDisplay': _learnedOuterDisplay,
      'largestWindowArea': _largestWindowArea,
    };
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
    final capabilities = _learnOuterDisplay(angle, signals.display.logicalSize);

    final posture = _resolver.resolve(
      featureState: signals.featureState,
      featureOrientation: signals.featureOrientation,
      angle: angle,
      hasOuterDisplay: capabilities.outerDisplay,
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
      display: _resolveDisplay(signals.display, angle),
      capabilities: capabilities,
      timestamp: DateTime.now(),
    );
  }

  /// Works out whether this device has an outer display, by deduction rather
  /// than by asking.
  ///
  /// Android exposes no public API for "is this the cover screen", and on
  /// Flip-class hardware the two panels are frequently the same logical
  /// display that resizes, so enumeration cannot see it either. But a device
  /// that is shut and still drawing our UI must be drawing it somewhere — and
  /// the only somewhere is an outer panel. That is a deduction from a real
  /// signal, not a heuristic, and unlike a size comparison it is correct on
  /// the very first launch.
  ///
  /// Latched for the session: a device does not grow or lose a panel.
  FoldableCapabilities _learnOuterDisplay(double? angle, Size? window) {
    if (window != null) {
      final area = window.width * window.height;
      if (area > _largestWindowArea) _largestWindowArea = area;
    }

    final isShut =
        angle != null && angle <= _resolver.thresholds.closedAtOrBelow;
    if (isShut) _learnedOuterDisplay = true;

    return _learnedOuterDisplay && !_capabilities.outerDisplay
        ? _capabilities.copyWith(outerDisplay: true)
        : _capabilities;
  }

  /// Fills in [ActiveDisplay] when the platform could not name it.
  DisplayInfo _resolveDisplay(DisplayInfo display, double? angle) {
    if (display.active != ActiveDisplay.unknown) return display;

    final window = display.logicalSize;
    if (window == null) return display;

    final isShut =
        angle != null && angle <= _resolver.thresholds.closedAtOrBelow;
    if (!isShut) {
      // Only claim the inner panel once a smaller one has been seen too;
      // otherwise an ordinary phone would report itself as a foldable's
      // inner display.
      return _learnedOuterDisplay
          ? DisplayInfo(
              active: ActiveDisplay.inner,
              features: display.features,
              logicalSize: window,
            )
          : display;
    }

    final area = window.width * window.height;
    return DisplayInfo(
      // A Flex Window is a fraction of the inner panel; a Fold-class outer
      // screen is a whole phone screen in its own right.
      active: area * 2 < _largestWindowArea
          ? ActiveDisplay.cover
          : ActiveDisplay.outer,
      features: display.features,
      logicalSize: window,
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
