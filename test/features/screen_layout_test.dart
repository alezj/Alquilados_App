import 'package:alquilados_app/core/theme/app_theme.dart';
import 'package:alquilados_app/features/alquileres/domain/entities/alquiler.dart';
import 'package:alquilados_app/features/alquileres/presentation/pages/alquileres_page.dart';
import 'package:alquilados_app/features/alquileres/presentation/providers/alquileres_provider.dart';
import 'package:alquilados_app/features/inquilinos/domain/entities/inquilino.dart';
import 'package:alquilados_app/features/inquilinos/presentation/pages/inquilinos_page.dart';
import 'package:alquilados_app/features/inquilinos/presentation/providers/inquilinos_provider.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:alquilados_app/features/pagos/presentation/pages/pagos_page.dart';
import 'package:alquilados_app/features/pagos/presentation/providers/pagos_provider.dart';
import 'package:alquilados_app/features/propiedades/domain/entities/propiedad.dart';
import 'package:alquilados_app/features/propiedades/presentation/pages/propiedades_page.dart';
import 'package:alquilados_app/features/propiedades/presentation/providers/propiedades_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const propertyName = 'Apartamento de la avenida principal';
  const tenantName = 'Inquilino con un nombre largo de prueba';
  for (final (route, label) in const <(Widget, String)>[
    (AlquileresPage(), propertyName),
    (InquilinosPage(), tenantName),
    (PagosPage(), tenantName),
    (PropiedadesPage(), propertyName),
  ]) {
    testWidgets('${route.runtimeType} adapta sus tarjetas a texto grande', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hoyPagosProvider.overrideWithValue(DateTime.utc(2026, 11, 23)),
            alquileresProvider.overrideWith(
              (ref) async => const [
                Alquiler(
                  id: 1,
                  propiedadId: 1,
                  inquilinoId: 1,
                  fechaInicio: '2026-01-01',
                  importe: 23000,
                  montoPago: 23000,
                  cantidadDepositos: 2,
                  diaPago: 20,
                  estado: 'Activo',
                  cantidadMeses: 12,
                  propiedadNombre: propertyName,
                  inquilinoNombre: tenantName,
                ),
              ],
            ),
            inquilinosProvider.overrideWith(
              (ref) async => const [
                Inquilino(
                  id: 1,
                  nombreApellido: tenantName,
                  correo: 'usuario@example.com',
                  fechaPagos: 20,
                ),
              ],
            ),
            pagosProvider.overrideWith(
              (ref) async => const [
                Pago(
                  id: 1,
                  idInquilino: '1',
                  inquilinoNombre: tenantName,
                  fechaPago: '2026-11-20',
                  monto: 23000,
                ),
              ],
            ),
            propiedadesProvider.overrideWith(
              (ref) async => const [
                Propiedad(
                  id: 1,
                  nombre: propertyName,
                  direccion: 'Calle Central',
                  estado: 2,
                  precioMensual: 23000,
                  notas: '',
                ),
              ],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.65)),
              child: child!,
            ),
            home: route,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
