import 'package:alquilados_app/features/pagos/data/repositories/payment_catalog_repository.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:alquilados_app/features/pagos/presentation/providers/payment_mutations_provider.dart';
import 'package:alquilados_app/features/pagos/presentation/widgets/payment_form_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCatalog extends Mock implements PaymentCatalogRepository {}

class MockMutations extends Mock implements PaymentMutations {}

void main() {
  late MockCatalog catalog;
  late MockMutations mutations;

  setUp(() {
    catalog = MockCatalog();
    mutations = MockMutations();
    when(catalog.load).thenAnswer(
      (_) async => const PaymentCatalog(
        methods: {'Efectivo': false, 'Transferencia': true},
        banks: ['Banco de prueba'],
      ),
    );
    when(() => mutations.isOnline).thenReturn(false);
    when(mutations.availableTenants).thenAnswer(
      (_) async => [
        {'id': 1, 'nombre_apellido': 'Ana Pérez'},
        {'id': 2, 'nombre_apellido': 'José Cruz'},
      ],
    );
  });

  Future<void> open(WidgetTester tester, {Pago? pago}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentCatalogProvider.overrideWithValue(catalog),
          paymentMutationsProvider.overrideWithValue(mutations),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPaymentForm(context, pago: pago),
                child: const Text('Abrir formulario'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label, String value) async {
    final field = find
        .ancestor(
          of: find.text(label).first,
          matching: find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField,
          ),
        )
        .first;
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(value).last);
    await tester.pumpAndSettle();
  }

  testWidgets('exige banco al crear una transferencia', (tester) async {
    when(() => mutations.suggestedAmount(1)).thenAnswer((_) async => 250);
    when(
      () => mutations.create(
        idInquilino: '1',
        fechaPago: any(named: 'fechaPago'),
        monto: 250,
        estado: 'pendiente',
        method: (name: 'Transferencia', bank: 'Banco de prueba'),
      ),
    ).thenAnswer((_) async => 'Guardado');

    await open(tester);
    expect(find.text('Banco'), findsNothing);
    await choose(tester, 'Inquilino', 'Ana Pérez');
    await choose(tester, 'Forma de pago', 'Transferencia');
    expect(find.text('Banco'), findsOneWidget);

    await tester.ensureVisible(find.text('Guardar pago'));
    await tester.tap(find.text('Guardar pago'));
    await tester.pumpAndSettle();
    expect(find.text('Selecciona un banco.'), findsOneWidget);

    await tester.ensureVisible(find.text('Banco'));
    await choose(tester, 'Banco', 'Banco de prueba');
    await tester.ensureVisible(find.text('Guardar pago'));
    await tester.tap(find.text('Guardar pago'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo pago'), findsNothing);
  });

  testWidgets(
    'permite cambiar el inquilino y elimina el banco al pasar a efectivo',
    (tester) async {
      const payment = Pago(
        id: 7,
        idInquilino: '1',
        inquilinoNombre: 'Ana Pérez',
        fechaPago: '2026-11-25',
        monto: 250,
        metodoPago: 'Transferencia',
        banco: 'Banco de prueba',
      );
      when(
        () => mutations.update(
          payment,
          idInquilino: '2',
          fechaPago: '2026-11-25',
          monto: 250,
          estado: 'pendiente',
          method: (name: 'Efectivo', bank: null),
        ),
      ).thenAnswer((_) async => 'Guardado');

      await open(tester, pago: payment);
      expect(find.text('Ana Pérez'), findsWidgets);
      expect(find.text('Banco de prueba'), findsWidgets);
      await choose(tester, 'Inquilino', 'José Cruz');
      await choose(tester, 'Forma de pago', 'Efectivo');
      expect(find.text('Banco'), findsNothing);

      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(find.text('Editar pago'), findsNothing);
    },
  );
}
