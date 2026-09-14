import 'package:flutter/widgets.dart';

import '../foldable_device.dart';
import '../model/foldable_state.dart';

/// Rebuilds when the device's posture, display or capabilities change.
///
/// This is the primary surface most apps need:
///
/// ```dart
/// FoldableBuilder(
///   builder: (context, state) => switch (state.posture) {
///     FoldPosture.tabletop => TabletopLayout(),
///     _ when state.posture.isClosed => CompactLayout(),
///     _ => FullLayout(),
///   },
/// )
/// ```
///
/// It does *not* rebuild on hinge-angle changes. Use `HingeAngleBuilder` from
/// `package:foldable_runtime/effects.dart` for those.
class FoldableBuilder extends StatelessWidget {
  /// Creates a posture-driven builder.
  const FoldableBuilder({
    required this.builder,
    this.initialState = FoldableState.rigid,
    super.key,
  });

  /// Called with the current device state.
  final Widget Function(BuildContext context, FoldableState state) builder;

  /// The state used before the first platform event arrives.
  ///
  /// Defaults to a rigid device, so the first frame renders your ordinary
  /// layout rather than an empty box.
  final FoldableState initialState;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FoldableState>(
      stream: FoldableDevice.instance.stateStream,
      initialData: FoldableDevice.instance.currentState ?? initialState,
      builder: (context, snapshot) =>
          builder(context, snapshot.data ?? initialState),
    );
  }
}

/// Provides [FoldableState] to a subtree, `MediaQuery`-style.
///
/// Wrap your app once, then read it anywhere with `Foldable.of(context)`.
class Foldable extends StatelessWidget {
  /// Creates a scope that provides device state to [child].
  const Foldable({required this.child, super.key});

  /// The subtree that can read the device state.
  final Widget child;

  /// The nearest device state, or [FoldableState.rigid] if there is no
  /// [Foldable] ancestor.
  ///
  /// Returning a rigid device rather than throwing is deliberate: a missing
  /// scope should degrade to "this device does not fold", never crash.
  static FoldableState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FoldableScope>();
    return scope?.state ?? FoldableState.rigid;
  }

  /// Like [of], but returns `null` when there is no ancestor scope, so callers
  /// can tell "no scope" apart from "not foldable".
  static FoldableState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FoldableScope>()?.state;
  }

  @override
  Widget build(BuildContext context) {
    return FoldableBuilder(
      builder: (context, state) => _FoldableScope(state: state, child: child),
    );
  }
}

class _FoldableScope extends InheritedWidget {
  const _FoldableScope({required this.state, required super.child});

  final FoldableState state;

  @override
  bool updateShouldNotify(_FoldableScope oldWidget) =>
      !oldWidget.state.sameLayoutAs(state);
}
