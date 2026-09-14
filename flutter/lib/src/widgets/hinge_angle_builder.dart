import 'dart:async';

import 'package:flutter/widgets.dart';

import '../foldable_device.dart';

/// Rebuilds on every hinge-angle change, for effects.
///
/// Enable angle updates before use, or pass `autoEnable: true`:
///
/// ```dart
/// HingeAngleBuilder(
///   autoEnable: true,
///   builder: (context, angle) => Opacity(
///     opacity: (angle / 180).clamp(0.0, 1.0),
///     child: child,
///   ),
/// )
/// ```
///
/// Do not lay out with this. Angle is a continuous signal and using it to pick
/// between layouts produces thrash at the boundaries; that is what
/// `FoldableBuilder` and posture are for.
class HingeAngleBuilder extends StatefulWidget {
  /// Creates an angle-driven builder.
  const HingeAngleBuilder({
    required this.builder,
    this.autoEnable = false,
    this.throttle = const Duration(milliseconds: 16),
    this.fallbackAngle = 180,
    super.key,
  });

  /// Called with the current normalised angle in degrees.
  final Widget Function(BuildContext context, double angle) builder;

  /// Whether to turn angle updates on while this widget is mounted, and off
  /// again when it is disposed.
  final bool autoEnable;

  /// Minimum interval between rebuilds. One frame at 60Hz by default.
  final Duration throttle;

  /// The angle used on devices with no hinge sensor.
  ///
  /// Defaults to fully flat, so an effect written against this degrades to its
  /// open state on ordinary phones rather than collapsing to zero.
  final double fallbackAngle;

  @override
  State<HingeAngleBuilder> createState() => _HingeAngleBuilderState();
}

class _HingeAngleBuilderState extends State<HingeAngleBuilder> {
  StreamSubscription<double>? _subscription;
  late double _angle = widget.fallbackAngle;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (widget.autoEnable) {
      unawaited(FoldableDevice.instance.enableAngleUpdates());
    }
    _subscription = FoldableDevice.instance.hingeAngleStream.listen(_onAngle);
  }

  void _onAngle(double angle) {
    final now = DateTime.now();
    if (now.difference(_lastEmit) < widget.throttle) return;
    _lastEmit = now;
    if (!mounted || angle == _angle) return;
    setState(() => _angle = angle);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (widget.autoEnable) {
      unawaited(FoldableDevice.instance.disableAngleUpdates());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _angle);
}
