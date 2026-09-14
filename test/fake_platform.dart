import 'dart:async';

import 'package:foldable_runtime/foldable_runtime.dart';

/// An in-memory platform implementation for tests and the example app's
/// simulator.
class FakeFoldableRuntime extends FoldableRuntimePlatform {
  FakeFoldableRuntime({this.capabilityResult = _defaultCapabilities});

  static const FoldableCapabilitiesResult _defaultCapabilities =
      FoldableCapabilitiesResult(
    capabilities: FoldableCapabilities(
      isFoldable: true,
      hingeAngleSensor: true,
      foldingFeature: true,
    ),
    manufacturer: 'fake',
    model: 'fold-1',
  );

  final FoldableCapabilitiesResult capabilityResult;
  final StreamController<FoldableState> controller =
      StreamController<FoldableState>.broadcast();

  bool angleEnabled = false;
  int capabilityCalls = 0;
  bool disposed = false;

  void emit(FoldableState state) => controller.add(state);

  @override
  Stream<FoldableState> get states => controller.stream;

  @override
  Future<FoldableCapabilitiesResult> capabilities() async {
    capabilityCalls++;
    return capabilityResult;
  }

  @override
  Future<Map<String, Object?>> diagnostics() async =>
      const <String, Object?>{'fake': true};

  @override
  Future<void> setAngleUpdatesEnabled(bool enabled) async {
    angleEnabled = enabled;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}
