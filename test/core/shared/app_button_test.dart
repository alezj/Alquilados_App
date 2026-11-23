import 'package:alquilados_app/core/shared/widgets/app_button.dart';
import 'package:alquilados_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('El botón ajusta la etiqueta ampliada en ${brightness.name}', (
      tester,
    ) async {
      var presses = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 210,
                child: AppButton(
                  text: 'Recordar por WhatsApp',
                  icon: Icons.chat_outlined,
                  onPressed: () => presses++,
                ),
              ),
            ),
          ),
        ),
      );

      final label = find.text('Recordar por WhatsApp');
      expect(tester.getSize(label).height, greaterThan(42));
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(presses, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
