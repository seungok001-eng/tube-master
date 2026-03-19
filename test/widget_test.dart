import 'package:flutter_test/flutter_test.dart';
import 'package:tube_master/main.dart';

void main() {
  testWidgets('Tube Master app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TubeMasterApp());
    expect(find.byType(TubeMasterApp), findsOneWidget);
  });
}
