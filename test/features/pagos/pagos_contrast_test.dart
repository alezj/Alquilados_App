import 'package:alquilados_app/core/theme/app_theme.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:alquilados_app/features/pagos/presentation/pages/pago_detalle_page.dart';
import 'package:alquilados_app/features/pagos/presentation/pages/pagos_page.dart';
import 'package:alquilados_app/features/pagos/presentation/providers/pagos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payment = Pago(
    id: 1,
    idInquilino: '1',
    inquilinoNombre: 'Inquilino de prueba',
    fechaPago: '2026-11-23',
    monto: 100,
  );

  for (final brightness in Brightness.values) {
    testWidgets('Pagos mantiene el contraste en ${brightness.name}', (
      tester,
    ) async {
      final theme = brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme;
      final colors = theme.colorScheme;

      Future<void> show(Widget page) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hoyPagosProvider.overrideWithValue(DateTime.utc(2026, 11, 23)),
              pagosProvider.overrideWith((ref) async => const [payment]),
              pagoDetalleProvider.overrideWith((ref, id) async => payment),
            ],
            child: MaterialApp(theme: theme, home: page),
          ),
        );
        await tester.pumpAndSettle();
      }

      void expectContrast(Finder text, Color background) {
        final color = tester
            .renderObject<RenderParagraph>(text)
            .text
            .style!
            .color!;
        final first = color.computeLuminance();
        final second = background.computeLuminance();
        final contrast = first >= second
            ? (first + .05) / (second + .05)
            : (second + .05) / (first + .05);
        expect(contrast, greaterThanOrEqualTo(4.5), reason: text.toString());
      }

      Finder chipLabel(Type chip, String label) =>
          find.descendant(of: find.byType(chip), matching: find.text(label));

      await show(const PagosPage());
      expectContrast(
        find.text('Pagos y Facturas'),
        theme.appBarTheme.backgroundColor!,
      );
      expectContrast(chipLabel(FilterChip, 'Todos'), colors.primaryContainer);
      expectContrast(chipLabel(FilterChip, 'Pendientes'), colors.surface);
      expectContrast(
        chipLabel(ChoiceChip, 'Pendiente'),
        colors.primaryContainer,
      );
      expectContrast(chipLabel(ChoiceChip, 'Pagado'), colors.surface);
      expectContrast(
        find.text(payment.inquilinoNombre),
        theme.cardTheme.color!,
      );

        await tester.tap(find.text('Filtrar mes'));
        await tester.pumpAndSettle();
        expectContrast(
          find.text('Selecciona un mes'),
          theme.bottomSheetTheme.modalBackgroundColor!,
        );
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();

        await show(const PagoDetallePage(id: 1));
      expectContrast(
        find.text('Detalle del pago'),
        theme.appBarTheme.backgroundColor!,
      );
      expectContrast(
        find.text('Cambiar estado'),
        theme.scaffoldBackgroundColor,
      );
      expectContrast(
        chipLabel(ChoiceChip, 'Pendiente'),
        colors.primaryContainer,
      );
      expectContrast(chipLabel(ChoiceChip, 'Pagado'), colors.surface);
    });
  }
}
