// Prints a device report you can paste into a GitHub issue so a hinge quirk
// can be added to the table.
//
//   flutter run -t tool/report_device.dart
//
// We will never own every foldable ever made. This is how the quirks table
// gets filled in by the people who do.
import 'package:flutter/material.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

void main() => runApp(const _ReportApp());

class _ReportApp extends StatelessWidget {
  const _ReportApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Device report')),
        body: FoldableBuilder(
          builder: (context, state) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_report(state)),
          ),
        ),
      ),
    );
  }

  String _report(FoldableState state) {
    final buffer = StringBuffer()
      ..writeln('### foldable_runtime device report')
      ..writeln()
      ..writeln('posture: ${state.posture.name}')
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
      ..writeln('Fold the device slowly through every position and paste the')
      ..writeln('reading at closed, 90 degrees, and fully flat.');
    return buffer.toString();
  }
}
