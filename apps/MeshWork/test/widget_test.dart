import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_work/main.dart';

void main() {
  testWidgets('MeshWork app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MeshWorkApp());
    expect(find.text('Welcome to MeshWork'), findsOneWidget);
    expect(find.text('e-bi Employee Mobile Office'), findsOneWidget);
  });
}
