import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Billetera Flutter Smoke Test', (WidgetTester tester) async {
    // Construimos un widget básico para validar que el motor de renderizado y testing funcione.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Billetera App'),
          ),
        ),
      ),
    );

    expect(find.text('Billetera App'), findsOneWidget);
    expect(find.text('No existe este texto'), findsNothing);
  });
}
