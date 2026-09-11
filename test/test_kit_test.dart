import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime/foldable_runtime.dart';
import 'package:foldable_runtime/testing.dart';

void main() {
  tearDown(FoldableDevice.resetForTesting);

  testWidgets('pumpFoldable drives every posture', (t) async {
    final platform = installFoldableTestPlatform();

    await t.pumpWidget(
      MaterialApp(
        home: FoldableBuilder(builder: (_, s) => Text(s.posture.name)),
      ),
    );

    await forEachPosture(t, platform, (posture) async {
      expect(find.text(posture.name), findsOneWidget);
    });
  });

  testWidgets('synthesised states carry a plausible display feature',
      (t) async {
    final platform = installFoldableTestPlatform();
    late FoldableState observed;

    await t.pumpWidget(
      MaterialApp(
        home: FoldableBuilder(
          builder: (_, s) {
            observed = s;
            return const SizedBox();
          },
        ),
      ),
    );

    await pumpFoldable(t, platform, FoldPosture.book);
    expect(observed.display.isSeparating, isTrue);
    expect(observed.display.features.single.bounds.width, 2);
    expect(observed.hinge.angle, 90);

    await pumpFoldable(t, platform, FoldPosture.tabletop);
    expect(observed.display.features.single.bounds.height, 2);

    await pumpFoldable(t, platform, FoldPosture.flipClosed);
    expect(observed.display.active, ActiveDisplay.cover);
    expect(observed.hinge.status, HingeStatus.closed);
  });
}
