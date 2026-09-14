import 'dart:async';

import 'package:flutter/foundation.dart';

import 'model/capabilities.dart';
import 'model/fold_posture.dart';
import 'model/foldable_state.dart';
import 'model/posture_thresholds.dart';
import 'platform/hinge_devices_platform.dart';
import 'platform/method_channel_hinge_devices.dart';
import 'platform/unsupported_hinge_devices.dart';

/// The entry point to the foldable runtime.
///
/// ```dart
/// final device = FoldableDevice.instance;
/// await device.initialize();
/// device.postureStream.listen((posture) { ... });
/// ```
///
/// Every stream is safe on non-foldable devices: they simply emit a single
/// rigid state and nothing further.
class FoldableDevice {
  FoldableDevice._(this._platform);

  static FoldableDevice? _instance;

  /// The shared instance.
  static FoldableDevice get instance => _instance ??= FoldableDevice._(
        _defaultPlatform(),
      );

  /// Replaces the platform implementation.
  ///
  /// Part of the public testing surface — `package:hinge_devices/testing.dart`
  /// and your own tests both call it. Deliberately *not* `@visibleForTesting`:
  /// that annotation means "reachable only from `test/`", and a package that
  /// ships a testing library necessarily calls it from `lib/`.
  static void setPlatformForTesting(HingeDevicesPlatform platform) {
    _instance?.dispose();
    _instance = FoldableDevice._(platform);
  }

  /// Resets the singleton, dropping any platform subscription.
  ///
  /// Call from `tearDown`. Public for the same reason as
  /// [setPlatformForTesting].
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  static HingeDevicesPlatform _defaultPlatform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return MethodChannelHingeDevices();
    }
    return const UnsupportedHingeDevices();
  }

  final HingeDevicesPlatform _platform;

  final StreamController<FoldableState> _controller =
      StreamController<FoldableState>.broadcast();

  // StreamController.stream hands back a new wrapper object on every read, so
  // it is memoized here: StreamBuilder compares streams by identity and would
  // otherwise resubscribe on every rebuild.
  late final Stream<FoldableState> _stream = _controller.stream;

  StreamSubscription<FoldableState>? _subscription;
  FoldableState? _current;
  FoldableState? _override;
  Future<FoldableCapabilities>? _capabilities;
  int _angleSubscribers = 0;

  /// The most recent state, or `null` before the first event.
  ///
  /// Prefer [stateStream]; this exists for imperative code that cannot await.
  FoldableState? get currentState => _override ?? _current;

  /// The device's capabilities. Queried once and cached.
  Future<FoldableCapabilities> get capabilities =>
      _capabilities ??= _platform.capabilities().then((r) => r.capabilities);

  /// Reads live platform diagnostics.
  ///
  /// Deliberately a call rather than a cached getter: the useful values — how
  /// many readings the hinge sensor has delivered, how many distinct angles it
  /// has ever produced, whether it sweeps or only reports at detents — are all
  /// about what has happened since the app started. Reading them from the
  /// capability snapshot reported zero forever.
  ///
  /// Contents are platform-specific and not part of the stable API. This
  /// exists so `tool/report_device.dart` can produce a useful bug report.
  Future<Map<String, Object?>> diagnostics() => _platform.diagnostics();

  /// Whether angle updates are currently streaming.
  bool get angleUpdatesEnabled => _angleSubscribers > 0;

  /// How many callers currently hold an angle-update request.
  ///
  /// Public so a debug menu can show it: a stuck count is the symptom of an
  /// unbalanced [enableAngleUpdates]/[disableAngleUpdates] pair.
  int get angleSubscriberCount => _angleSubscribers;

  /// Every state change, deduplicated on layout-relevant fields.
  ///
  /// A state whose only difference is a hinge-angle wiggle does not appear
  /// here — that would rebuild your layout sixty times a second. Use
  /// [hingeAngleStream] for continuous values.
  ///
  /// The returned stream has a stable identity across calls, so a widget that
  /// reads it on every build does not resubscribe — and therefore does not
  /// drop the event that caused the rebuild. Late subscribers read the last
  /// value from [currentState] rather than being replayed, the same way
  /// `MediaQuery` hands you a value and then notifies you of changes.
  Stream<FoldableState> get stateStream {
    // Subscribe synchronously. Awaiting anything here opens a window where
    // platform events arrive before the listener exists and are dropped.
    _ensureListening();
    return _stream;
  }

  /// Posture changes only, deduplicated.
  Stream<FoldPosture> get postureStream =>
      stateStream.map((s) => s.posture).distinct();

  /// Continuous hinge angle in normalised degrees.
  ///
  /// Requires [enableAngleUpdates]. Intended for effects — parallax, reveal
  /// animations, progressive disclosure — not for layout. Driving layout from
  /// a continuous angle produces visible thrash; both Android and Apple
  /// document the folding feature as the layout signal.
  Stream<double> get hingeAngleStream => stateStream
      .map((s) => s.hinge.angle)
      .where((a) => a != null)
      .cast<double>();

  /// Starts listening to the platform and resolves once capabilities are
  /// known.
  ///
  /// Optional: every stream initialises lazily. Call it during app start to
  /// avoid a first-frame gap on foldables.
  Future<void> initialize() async {
    _ensureListening();
    await capabilities;
  }

  /// Turns the hinge-angle sensor stream on.
  ///
  /// Off by default. On Android this raises the sensor's sampling rate; the
  /// hinge sensor is an on-change sensor so the cost is small, but it is not
  /// zero and it is the only part of this package that touches battery.
  ///
  /// Requests are reference counted. Two widgets can each enable updates and
  /// the first one disposing will not cut the sensor out from under the
  /// second — pair every call with exactly one [disableAngleUpdates].
  Future<void> enableAngleUpdates() async {
    _angleSubscribers++;
    if (_angleSubscribers > 1) return;
    await _platform.setAngleUpdatesEnabled(true);
  }

  /// Releases one angle-update request.
  ///
  /// The sensor rate drops back only once every holder has released.
  Future<void> disableAngleUpdates() async {
    if (_angleSubscribers == 0) return;
    _angleSubscribers--;
    if (_angleSubscribers > 0) return;
    await _platform.setAngleUpdatesEnabled(false);
  }

  /// Forces a state for local development and tests.
  ///
  /// Wire this to a debug menu to exercise every posture without owning the
  /// hardware. Pass `null` to hand control back to the platform.
  ///
  /// ```dart
  /// FoldableDevice.instance.debugOverride(
  ///   const FoldableState(posture: FoldPosture.tabletop),
  /// );
  /// ```
  void debugOverride(FoldableState? state) {
    _override = state;
    if (state != null) {
      _controller.add(state);
    } else if (_current != null) {
      _controller.add(_current!);
    }
  }

  /// Adjusts the angle thresholds used for the angle-only posture fallback.
  ///
  /// Only takes effect for platform implementations created afterwards, so
  /// call it before [initialize].
  static void configureThresholds(PostureThresholds thresholds) {
    _instance?.dispose();
    _instance = FoldableDevice._(
      defaultTargetPlatform == TargetPlatform.android
          ? MethodChannelHingeDevices(thresholds: thresholds)
          : const UnsupportedHingeDevices(),
    );
  }

  void _ensureListening() {
    if (_subscription != null) return;
    // Warm the capability cache without blocking: the decoder needs the
    // device's quirk entry and outer-display flag, but it has safe defaults
    // and self-corrects on the next event once capabilities resolve.
    unawaited(capabilities);
    _subscription = _platform.states.listen(
      (state) {
        _current = state;
        if (_override != null) return;
        _controller.add(state);
      },
      onError: (Object error) {
        debugPrint('hinge_devices: $error');
      },
    );
  }

  /// Releases the platform subscription.
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _platform.dispose();
    await _controller.close();
  }
}
