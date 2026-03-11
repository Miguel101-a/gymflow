import 'package:flutter_test/flutter_test.dart';
import 'package:gymflow/main.dart';

void main() {
  testWidgets('GymFlow app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const GymFlowApp());
    expect(find.text('GymFlow'), findsOneWidget);
  });
}
