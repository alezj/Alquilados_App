import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:alquilados_app/main.dart';

void main() {
  testWidgets('Las políticas se pueden consultar desde el inicio de sesión', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const ProviderScope(child: AlquiladosApp()));
    await tester.pumpAndSettle();

    final policies = find.text('Políticas');
    await tester.ensureVisible(policies);
    await tester.pumpAndSettle();
    await tester.tap(policies);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Política de Privacidad'));
    await tester.pumpAndSettle();
    expect(find.text('Política de Privacidad'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AlquiladosApp renders the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: AlquiladosApp()));
    await tester.pumpAndSettle();
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(find.text('Ambiente'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Johancel');
    await tester.pumpAndSettle();
    expect(find.text('Ambiente'), findsOneWidget);
    expect(find.text('Pruebas (Alquilados_Test)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'otro');
    await tester.pumpAndSettle();
    expect(find.text('Ambiente'), findsNothing);
  });
}
