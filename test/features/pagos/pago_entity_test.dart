import 'package:flutter_test/flutter_test.dart';

import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';

void main() {
  group('Pago entity', () {
    const pago = Pago(
      id: 1,
      idInquilino: '2',
      inquilinoNombre: 'Juan Pérez',
      fechaPago: '2026-09-15',
      monto: 1500.0,
      estado: 'pagado',
    );

    test('se crea correctamente con valores obligatorios', () {
      expect(pago.id, 1);
      expect(pago.idInquilino, '2');
      expect(pago.fechaPago, '2026-09-15');
      expect(pago.monto, 1500.0);
      expect(pago.estado, 'pagado');
    });

    test('estado por defecto es pendiente', () {
      const pagoDefault = Pago(
        id: 2,
        idInquilino: '1',
        inquilinoNombre: 'María García',
        fechaPago: '2026-09-01',
        monto: 800.0,
      );
      expect(pagoDefault.estado, 'pendiente');
    });

    test('syncState por defecto es pending', () {
      expect(pago.syncState, 'pending');
    });

    test('syncedAt por defecto es null', () {
      expect(pago.syncedAt, isNull);
    });

    test('acepta syncState y syncedAt personalizados', () {
      const sincronizado = Pago(
        id: 3,
        idInquilino: '5',
        inquilinoNombre: 'Carlos López',
        fechaPago: '2026-08-01',
        monto: 2000.0,
        estado: 'pagado',
        syncState: 'synced',
        syncedAt: '2026-08-02T10:00:00.000',
      );
      expect(sincronizado.syncState, 'synced');
      expect(sincronizado.syncedAt, '2026-08-02T10:00:00.000');
    });

    test('monto puede ser decimal', () {
      const pagoDecimal = Pago(
        id: 4,
        idInquilino: '3',
        inquilinoNombre: 'Ana Martínez',
        fechaPago: '2026-09-10',
        monto: 1234.56,
      );
      expect(pagoDecimal.monto, 1234.56);
    });

    test('estado vencido es válido', () {
      const pagoVencido = Pago(
        id: 5,
        idInquilino: '7',
        inquilinoNombre: 'Luis Rodríguez',
        fechaPago: '2026-07-01',
        monto: 900.0,
        estado: 'vencido',
      );
      expect(pagoVencido.estado, 'vencido');
    });
  });

  group('Pago — casos edge', () {
    test('monto cero es válido', () {
      const pagoGratis = Pago(
        id: 6,
        idInquilino: '1',
        inquilinoNombre: 'Pedro Sánchez',
        fechaPago: '2026-09-01',
        monto: 0,
      );
      expect(pagoGratis.monto, 0);
    });

    test('idInquilino puede ser cualquier string', () {
      const pago = Pago(
        id: 7,
        idInquilino: 'INQ-999',
        inquilinoNombre: 'Laura Fernández',
        fechaPago: '2026-09-01',
        monto: 500,
      );
      expect(pago.idInquilino, 'INQ-999');
      expect(pago.inquilinoNombre, 'Laura Fernández');
    });
  });
}
