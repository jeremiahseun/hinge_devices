import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/effects.dart';
import 'package:foldable_runtime/foldable_runtime.dart';

import 'fake_platform.dart';

void main() {
  late FakeFoldableRuntime fake;

  setUp(() {
    fake = FakeFoldableRuntime();
    FoldableDevice.setPlatformForTesting(fake);
  });

  tearDown(FoldableDevice.resetForTesting);

  testWidgets('FoldableBuilder renders the initial state first', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: FoldableBuilder(
          builder: (_, state) => Text(
            state.posture.name,
            textDirection: TextDirection.ltr,
          ),
        ),
      ),
    );
    expect(find.text('unknown'), findsOneWidget);
  });

  testWidgets('FoldableBuilder rebuilds on posture change', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: FoldableBuilder(builder: (_, state) => Text(state.posture.name)),
      ),
    );
    await t.pump();

    fake.emit(const FoldableState(posture: FoldPosture.tabletop));
    // Two pumps: the first flushes the microtask that delivers the stream
    // event, the second renders the frame it scheduled.
    await t.pump();
    await t.pump();
    expect(find.text('tabletop'), findsOneWidget);
  });

  testWidgets('Foldable.of returns a rigid device with no ancestor', (t) async {
    late FoldableState observed;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            observed = Foldable.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(observed, FoldableState.rigid);
  });

  testWidgets('Foldable.maybeOf distinguishes missing scope', (t) async {
    late FoldableState? observed;
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            observed = Foldable.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(observed, isNull);
  });

  testWidgets('Foldable provides state to descendants', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Foldable(
          child: Builder(
            builder: (context) => Text(Foldable.of(context).posture.name),
          ),
        ),
      ),
    );
    await t.pump();

    fake.emit(const FoldableState(posture: FoldPosture.book));
    await t.pump();
    await t.pump();
    expect(find.text('book'), findsOneWidget);
  });

  testWidgets('HingeAngleBuilder falls back to flat with no sensor', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: HingeAngleBuilder(
          builder: (_, angle) => Text(angle.toStringAsFixed(0)),
        ),
      ),
    );
    expect(find.text('180'), findsOneWidget);
  });

  testWidgets('HingeAngleBuilder toggles angle updates with its lifetime',
      (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: HingeAngleBuilder(
          autoEnable: true,
          builder: (_, angle) => Text(angle.toStringAsFixed(0)),
        ),
      ),
    );
    await t.pump();
    expect(fake.angleEnabled, isTrue);

    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pump();
    expect(fake.angleEnabled, isFalse);
  });
}
