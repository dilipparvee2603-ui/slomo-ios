import 'package:flutter_test/flutter_test.dart';
import 'package:slomo_creator_pro/main.dart';

void main() {
  testWidgets('App smoke test launches Home Screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SloMoCreatorApp());
    expect(find.text('Slo-Mo Creator Pro'), findsOneWidget);
    expect(find.text('IMPORT VIDEO'), findsOneWidget);
  });
}
