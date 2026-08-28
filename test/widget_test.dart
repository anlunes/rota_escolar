import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rota_escolar/app/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RotaEscolarApp(),
      ),
    );

    expect(find.text('Rota Escolar'), findsOneWidget);
    expect(find.byIcon(Icons.directions_bus), findsOneWidget);
  });
}
