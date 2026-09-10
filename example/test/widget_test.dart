import 'package:flutter_test/flutter_test.dart';
import 'package:foldable_runtime_example/main.dart';

void main() {
  testWidgets('renders the flat layout on a non-foldable device', (t) async {
    await t.pumpWidget(const ExampleApp());
    await t.pump();
    expect(find.text('Flat — full app'), findsOneWidget);
  });
}
