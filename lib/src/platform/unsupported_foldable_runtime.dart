import '../model/capabilities.dart';
import '../model/foldable_state.dart';
import 'foldable_runtime_platform.dart';

/// The implementation used on every platform without foldable support.
///
/// It reports a rigid device and never emits. This is what makes the package
/// safe to add to a multi-platform app: web, desktop and iOS builds compile
/// and run with no native code at all.
class UnsupportedFoldableRuntime extends FoldableRuntimePlatform {
  /// Creates the no-op implementation.
  const UnsupportedFoldableRuntime();

  @override
  Stream<FoldableState> get states => const Stream<FoldableState>.empty();

  @override
  Future<FoldableCapabilitiesResult> capabilities() async =>
      const FoldableCapabilitiesResult(
        capabilities: FoldableCapabilities.none,
      );

  @override
  Future<void> setAngleUpdatesEnabled(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}
