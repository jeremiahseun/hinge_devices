// Prints a device report you can paste into a GitHub issue so a hinge quirk
// can be added to the table.
//
//   flutter run -t tool/report_device.dart
//
// Fold the device slowly through its whole range while this is open. The
// numbers that matter are the distinct-value and continuity lines: no vendor
// documents whether a hinge sensor sweeps or only reports at detents, and the
// answer decides whether angle-driven effects are worth building on a device.
//
// We will never own every foldable ever made. This is how the quirks table
// gets filled in by the people who do.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

void main() {
  // Run the sensor at the effects rate so the report reflects the best the
  // device can do, not the posture-only rate.
  FoldableDevice.instance.enableAngleUpdates();
  runApp(const _ReportApp());
}

class _ReportApp extends StatelessWidget {
  const _ReportApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: _ReportPage());
  }
}

class _ReportPage extends StatefulWidget {
  const _ReportPage();

  @override
  State<_ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<_ReportPage> {
  Map<String, Object?> _diagnostics = const <String, Object?>{};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Diagnostics are live counters, so they have to be polled rather than
    // read once at startup.
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) async {
      final diagnostics = await FoldableDevice.instance.diagnostics();
      if (mounted) setState(() => _diagnostics = diagnostics);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device report')),
      body: FoldableBuilder(
        builder: (context, state) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_report(state)),
        ),
      ),
    );
  }

  String _report(FoldableState state) {
    final buffer = StringBuffer()
      ..writeln('### foldable_runtime device report')
      ..writeln()
      ..writeln('posture: ${state.posture.name} (${state.posture.coarse.name})')
      ..writeln('raw angle: ${state.hinge.rawAngle}')
      ..writeln('normalised angle: ${state.hinge.angle}')
      ..writeln('assumed range: ${state.hinge.range.name}')
      ..writeln('hinge status: ${state.hinge.status.name}')
      ..writeln('fold orientation: ${state.hinge.orientation}')
      ..writeln('active display: ${state.display.active.name}')
      ..writeln('window: ${state.display.logicalSize}')
      ..writeln('separating: ${state.display.isSeparating}')
      ..writeln()
      ..writeln('capabilities:');
    state.capabilities.raw.forEach((key, value) {
      buffer.writeln('  $key: $value');
    });

    buffer
      ..writeln()
      ..writeln('diagnostics (live):');
    if (_diagnostics.isEmpty) {
      buffer.writeln('  reading...');
    } else {
      _diagnostics.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    buffer
      ..writeln()
      ..writeln('Fold the device slowly through its whole range, then read')
      ..writeln('hingeDistinctValues and hingeContinuous above.')
      ..writeln()
      ..writeln('A sweeping sensor passes a few dozen distinct values in one')
      ..writeln('fold. One that only reports at detents stays in single')
      ..writeln('figures no matter how slowly you move it — that is a')
      ..writeln('hardware property worth recording, not a bug.');
    return buffer.toString();
  }
}
