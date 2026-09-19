import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('ArijApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArijApp());
    expect(find.textContaining('Polyclinique Arij'), findsWidgets);
  });
}
