import 'package:flutter/material.dart';
import 'package:foldable_runtime/effects.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

void main() {
  runApp(const ExampleApp());
}

/// Demonstrates posture-driven layout, hinge-driven effects, and the debug
/// simulator that makes both testable without foldable hardware.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'foldable_runtime',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// The example's single screen.
class HomePage extends StatefulWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _showSimulator = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Foldable Runtime'),
        actions: [
          IconButton(
            tooltip: 'Posture simulator',
            icon: Icon(_showSimulator ? Icons.science : Icons.science_outlined),
            onPressed: () => setState(() => _showSimulator = !_showSimulator),
          ),
        ],
      ),
      body: FoldableBuilder(
        builder: (context, state) => Column(
          children: [
            Expanded(child: _layoutFor(state)),
            const Divider(height: 1),
            _Diagnostics(state: state),
            if (_showSimulator) ...[
              const Divider(height: 1),
              _Simulator(state: state),
            ],
          ],
        ),
      ),
    );
  }

  // The whole point of the package: one switch, no brand checks.
  //
  // Note the tabletop and book cases are matched before falling back to the
  // coarse switch. Matching FoldPosture.closed on its own would silently drop
  // flipClosed and put a shut Flip on its opened layout, which is exactly why
  // CoarsePosture exists.
  Widget _layoutFor(FoldableState state) {
    if (state.posture == FoldPosture.tabletop) return const _TabletopLayout();
    if (state.posture == FoldPosture.book) return const _BookLayout();

    return switch (state.posture.coarse) {
      CoarsePosture.closed => const _CompactLayout(),
      CoarsePosture.halfOpen => const _TabletopLayout(),
      CoarsePosture.open => const _FullLayout(),
    };
  }
}

/// An always-visible readout of what the package is actually seeing.
///
/// Angle and posture come from different signals with different failure
/// modes, so showing both side by side is the fastest way to tell which one
/// has gone wrong on a real device.
class _Diagnostics extends StatelessWidget {
  const _Diagnostics({required this.state});

  final FoldableState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caps = state.capabilities;
    final angle = state.hinge.angle;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                state.posture.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                angle == null ? 'no angle' : '${angle.toStringAsFixed(1)}°',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                state.display.active.name,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // A live bar is easier to read than a number when you are folding
          // the device with one hand and watching with the other.
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (angle ?? 0) / 180,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'foldable ${caps.isFoldable} · sensor ${caps.hingeAngleSensor} · '
            'feature ${caps.foldingFeature} · outer ${caps.outerDisplay} · '
            'angle updates ${FoldableDevice.instance.angleUpdatesEnabled}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _FullLayout extends StatelessWidget {
  const _FullLayout();

  @override
  Widget build(BuildContext context) => const _Panel(
    label: 'Flat — full app',
    detail: 'One continuous surface. Lay out as you normally would.',
    icon: Icons.tablet_android,
  );
}

class _TabletopLayout extends StatelessWidget {
  const _TabletopLayout();

  @override
  Widget build(BuildContext context) {
    // Horizontal fold: content above, controls below.
    return const Column(
      children: [
        Expanded(
          child: _Panel(
            label: 'Content',
            detail: 'Above the fold',
            icon: Icons.play_circle,
          ),
        ),
        Expanded(
          child: _Panel(
            label: 'Controls',
            detail: 'Below the fold',
            icon: Icons.tune,
          ),
        ),
      ],
    );
  }
}

class _BookLayout extends StatelessWidget {
  const _BookLayout();

  @override
  Widget build(BuildContext context) {
    // Vertical fold: two pages side by side.
    return const Row(
      children: [
        Expanded(
          child: _Panel(label: 'Left page', detail: '', icon: Icons.menu_book),
        ),
        VerticalDivider(width: 1),
        Expanded(
          child: _Panel(label: 'Right page', detail: '', icon: Icons.article),
        ),
      ],
    );
  }
}

class _CompactLayout extends StatelessWidget {
  const _CompactLayout();

  @override
  Widget build(BuildContext context) => const _Panel(
    label: 'Closed — compact app',
    detail: 'Cover-screen sized. Same state, less room.',
    icon: Icons.smartphone,
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.label, required this.detail, required this.icon});

  final String label;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hinge angle drives an effect, never the layout above.
          // Hinge angle drives an effect, never the layout above. A full
          // quarter turn from flat to closed, so it is obvious at a glance
          // whether readings are actually streaming.
          HingeAngleBuilder(
            autoEnable: true,
            builder: (context, angle) => Transform.rotate(
              angle: (180 - angle) / 180 * 1.57,
              child: Icon(icon, size: 56, color: theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(label, style: theme.textTheme.titleLarge),
          if (detail.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

/// A debug menu wired to `FoldableDevice.debugOverride`.
///
/// This is the harness that makes the package developable without a foldable:
/// every posture is one tap away, on any device or emulator.
class _Simulator extends StatefulWidget {
  const _Simulator({required this.state});

  final FoldableState state;

  @override
  State<_Simulator> createState() => _SimulatorState();
}

class _SimulatorState extends State<_Simulator> {
  FoldPosture? _forced;
  double _angle = 180;

  void _force(FoldPosture? posture) {
    setState(() => _forced = posture);
    FoldableDevice.instance.debugOverride(
      posture == null
          ? null
          : FoldableState(
              posture: posture,
              hinge: Hinge(angle: _angle, status: HingeStatus.partiallyOpen),
              capabilities: widget.state.capabilities,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final caps = widget.state.capabilities;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'posture: ${widget.state.posture.name}   '
            'angle: ${widget.state.hinge.angle?.toStringAsFixed(0) ?? '—'}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            'foldable: ${caps.isFoldable}   '
            'hinge sensor: ${caps.hingeAngleSensor}   '
            'folding feature: ${caps.foldingFeature}   '
            'outer display: ${caps.outerDisplay}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            'active display: ${widget.state.display.active.name}   '
            'separating: ${widget.state.display.isSeparating}   '
            'angle updates: ${FoldableDevice.instance.angleUpdatesEnabled}',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final posture in FoldPosture.values)
                ChoiceChip(
                  label: Text(posture.name),
                  selected: _forced == posture,
                  onSelected: (_) =>
                      _force(_forced == posture ? null : posture),
                ),
              ActionChip(
                label: const Text('live'),
                onPressed: () => _force(null),
              ),
            ],
          ),
          if (_forced != null)
            Slider(
              value: _angle,
              max: 180,
              label: _angle.toStringAsFixed(0),
              onChanged: (v) {
                setState(() => _angle = v);
                _force(_forced);
              },
            ),
        ],
      ),
    );
  }
}
