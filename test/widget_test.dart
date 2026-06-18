import 'package:flutter_test/flutter_test.dart';

import 'package:gestao_bovinos_app/app.dart';

void main() {
  testWidgets('App renders the app bar title', (WidgetTester tester) async {
    await tester.pumpWidget(const GestaoBovinosApp());

    expect(find.text('Gestão de Rebanho'), findsOneWidget);
  });
}
