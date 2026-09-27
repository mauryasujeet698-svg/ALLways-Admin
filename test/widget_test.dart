import 'package:flutter_test/flutter_test.dart';
import 'package:allways_admin/main.dart';

void main() {
  testWidgets('Admin login renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminLoginPage()),
    );
    await tester.pump();
    expect(find.text('ALLways Admin'), findsOneWidget);
  });
}
