import 'package:flutter_test/flutter_test.dart';

import '../model/fold_posture.dart';
import '../model/foldable_state.dart';
import 'foldable_test_kit.dart';

/// Puts the device under test into [posture] and pumps until it renders.
///
/// Two pumps are required and easy to get wrong by hand: the first flushes the
/// microtask that delivers the stream event, the second renders the frame that
/// event scheduled.
Future<void> pumpFoldable(
  WidgetTester tester,
  FoldableTestPlatform platform,
  FoldPosture posture, {
  double? angle,
}) async {
  platform.setPosture(posture, angle: angle);
  await tester.pump();
  await tester.pump();
}

/// Emits [state] and pumps until it renders.
Future<void> pumpFoldableState(
  WidgetTester tester,
  FoldableTestPlatform platform,
  FoldableState state,
) async {
  platform.emit(state);
  await tester.pump();
  await tester.pump();
}

/// Runs [body] once for every posture, so a golden or layout test covers the
/// whole matrix without repeating itself.
Future<void> forEachPosture(
  WidgetTester tester,
  FoldableTestPlatform platform,
  Future<void> Function(FoldPosture posture) body, {
  Iterable<FoldPosture> postures = FoldPosture.values,
}) async {
  for (final posture in postures) {
    await pumpFoldable(tester, platform, posture);
    await body(posture);
  }
}
