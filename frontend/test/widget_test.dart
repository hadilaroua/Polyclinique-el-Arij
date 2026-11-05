import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('ArijApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ArijApp());
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('Polyclinique'), findsWidgets);
  });
}
