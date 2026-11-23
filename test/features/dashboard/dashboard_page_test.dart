import 'package:alquilados_app/core/shared/widgets/app_card.dart';
import 'package:alquilados_app/features/app_shell.dart';
import 'package:alquilados_app/features/dashboard/domain/dashboard_collections.dart';
import 'package:alquilados_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:alquilados_app/features/pagos/presentation/providers/pagos_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const payments = [
    Pago(
      id: 1,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-11-03',
      monto: 200,
      estado: 'Pagado',
      periodo: '2026-10',
    ),
    Pago(
      id: 2,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-10-29',
      monto: 90,
      estado: 'pagado',
      periodo: '2026-11',
    ),
    Pago(
      id: 3,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-11-22',
      monto: 10,
    ),
    Pago(
      id: 4,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-11-30',
      monto: 30,
    ),
    Pago(
      id: 5,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-12-01',
      monto: 99,
    ),
    Pago(
      id: 6,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-11-25',
      monto: 20,
      estado: 'Atrasado',
    ),
    Pago(
      id: 7,
      idInquilino: '1',
      inquilinoNombre: 'A',
      fechaPago: '2026-11-23',
      monto: 10,
    ),
  ];

  test(
    'separa lo cobrado por fecha del avance del período y los vencimientos',
    () {
      final summary = DashboardCollections.fromPayments(
        today: DateTime.utc(2026, 11, 23),
        payments: payments,
      );
      expect(summary.collected, 200);
      expect(summary.outstanding, 70);
      expect(summary.expected, 160);
      expect(summary.collectionProgress, closeTo(0.5625, 0.0001));
      expect(summary.overdue, 2);
      expect(summary.upcoming, 2);
    },
  );

  testWidgets('el Dashboard abre Pagos con el mismo filtro que usa la alerta', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final providers = ProviderContainer(
      overrides: [
        dashboardSummaryProvider.overrideWith(
          (ref) async => {'ocupadas': 6, 'totalPropiedades': 8},
        ),
        pagosProvider.overrideWith((ref) async => payments),
        hoyPagosProvider.overrideWithValue(DateTime.utc(2026, 11, 23)),
      ],
    );
    addTearDown(providers.dispose);
    providers.read(pagosFiltroProvider.notifier).setBusqueda('otra búsqueda');
    providers.read(pagosFiltroProvider.notifier).setYearMonth('2026-01');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: const Scaffold(body: DashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cobrado este mes'), findsOneWidget);
    final overdue = find.text('Pagos vencidos');
    await tester.ensureVisible(overdue);
    await tester.pumpAndSettle();
    await tester.tap(overdue);
    await tester.pumpAndSettle();

    expect(providers.read(appShellTabProvider), 2);
    final filter = providers.read(pagosFiltroProvider);
    expect(filter.estado, FiltroEstadoPago.vencido);
    expect(filter.yearMonth, isNull);
    expect(filter.busqueda, isEmpty);
    expect(
      (await providers.read(pagosFiltradosProvider.future))
          .map((pago) => pago.id),
      [3, 6],
    );

    final upcoming = find.text('Próximos 7 días');
    await tester.ensureVisible(upcoming);
    await tester.pumpAndSettle();
    await tester.tap(upcoming);
    await tester.pumpAndSettle();
    expect(
      (await providers.read(pagosFiltradosProvider.future))
          .map((pago) => pago.id),
      [4, 7],
    );
    final createPayment = find.text('Registrar pago');
    await tester.ensureVisible(createPayment);
    await tester.pumpAndSettle();
    await tester.tap(createPayment);
    expect(providers.read(appShellTabProvider), 2);
    expect(providers.read(openCreatePagoSheetProvider), isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale, stacked) in [
    (380.0, 1.0, true),
    (430.0, 1.0, true),
    (800.0, 1.0, false),
    (800.0, 2.0, true),
  ]) {
    testWidgets('Dashboard shortcuts at width $width and text scale $scale', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: DashboardQuickActions(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final (icon, title) in [
        (Icons.home_work_rounded, 'Alquileres'),
        (Icons.payment_rounded, 'Registrar pago'),
      ]) {
        final iconFinder = find.byIcon(icon).first;
        final card = find.ancestor(
          of: iconFinder,
          matching: find.byType(AppCard),
        );
        final label = find.descendant(of: card, matching: find.text(title));
        expect(label, findsOneWidget);

        final iconBounds = tester.getRect(iconFinder);
        final labelBounds = tester.getRect(label);
        if (stacked) {
          expect(labelBounds.top, greaterThan(iconBounds.bottom));
          expect(labelBounds.center.dx, closeTo(iconBounds.center.dx, 0.1));
        } else {
          expect(labelBounds.left, greaterThan(iconBounds.right));
          expect(labelBounds.top, lessThan(iconBounds.bottom));
        }
      }
    });
  }
}
