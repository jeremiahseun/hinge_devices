/// Test helpers for exercising every posture without foldable hardware.
///
/// ```dart
/// testWidgets('renders a tabletop layout', (tester) async {
///   final device = installFoldableTestPlatform();
///   addTearDown(FoldableDevice.resetForTesting);
///
///   await tester.pumpWidget(const MyApp());
///   await pumpFoldable(tester, device, FoldPosture.tabletop);
///
///   expect(find.byType(TabletopLayout), findsOneWidget);
/// });
/// ```
library;

export 'src/testing/foldable_test_kit.dart';
export 'src/testing/pump_foldable.dart';
