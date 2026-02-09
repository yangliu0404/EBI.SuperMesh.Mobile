import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_portal/main.dart';

void main() {
  testWidgets('MeshPortal app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MeshPortalApp());
    expect(find.text('Welcome to MeshPortal'), findsOneWidget);
    expect(find.text('Your Supply Chain at a Glance'), findsOneWidget);
  });
}
