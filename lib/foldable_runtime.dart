/// A unified posture, hinge and display model for foldable devices.
///
/// Start with [FoldableDevice.instance] or wrap your app in [Foldable] and
/// read state with `Foldable.of(context)`.
///
/// Hinge-angle effects live in `package:foldable_runtime/effects.dart` — they
/// are a separate import because angle is an effects signal, not a layout one.
library;

export 'src/foldable_device.dart';
export 'src/model/capabilities.dart';
export 'src/model/display_info.dart';
export 'src/model/fold_posture.dart';
export 'src/model/foldable_state.dart';
export 'src/model/hinge.dart';
export 'src/model/posture_resolver.dart' show FoldingFeatureState, PostureResolver;
export 'src/model/posture_thresholds.dart';
export 'src/model/quirks.dart';
export 'src/platform/foldable_runtime_platform.dart';
export 'src/platform/unsupported_foldable_runtime.dart';
export 'src/widgets/foldable_builder.dart';
