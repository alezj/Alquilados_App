import 'package:alquilados_app/features/inquilinos/domain/entities/inquilino.dart';
import 'package:alquilados_app/features/pagos/domain/entities/comprobante_pago.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:alquilados_app/features/pagos/data/services/comprobante_pago_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildComprobantePago crea un comprobante no fiscal con los datos del pago', () {
    const pago = Pago(
      id: 42,
      idInquilino: '7',
      inquilinoNombre: 'Ana García',
      fechaPago: '2026-09-15',
      monto: 1250.0,
      estado: 'pagado',
      syncState: 'synced',
      syncedAt: '2026-09-15T12:00:00Z',
    );

    const inquilino = Inquilino(
      id: 7,
      nombreApellido: 'Ana García',
      correo: 'ana@ejemplo.com',
      fechaInicioContrato: '2026-01-01',
      fechaPagos: 15,
      syncState: 'synced',
      syncedAt: '2026-09-15T12:00:00Z',
    );

    final comprobante = ComprobantePagoData.fromPayment(pago, inquilino);

    expect(comprobante.isFiscal, isFalse);
    expect(comprobante.titulo, 'RECIBO DE PAGO');
    expect(comprobante.inquilinoNombre, 'Ana García');
    expect(comprobante.montoFormateado, '\$1,250.00');
    expect(comprobante.numeroRecibo, '42');
    expect(comprobante.fecha, '15/09/2026');
    expect(comprobante.telefono, 'ana@ejemplo.com');
    expect(comprobante.direccion, '—');
    expect(comprobante.subtotalFormateado, '\$1,250.00');
    expect(comprobante.retasoFormateado, '\$0.00');
    expect(comprobante.totalFormateado, '\$1,250.00');
    expect(comprobante.descripcionDetallada, isNotEmpty);
    expect(comprobante.fileName, contains('recibo_pago_42'));
  });

  test('genera un PDF sin errores', () async {
    const pago = Pago(
      id: 42,
      idInquilino: '7',
      inquilinoNombre: 'Ana García',
      fechaPago: '2026-09-15',
      monto: 1250.0,
      estado: 'pagado',
      syncState: 'synced',
      syncedAt: '2026-09-15T12:00:00Z',
    );

    const inquilino = Inquilino(
      id: 7,
      nombreApellido: 'Ana García',
      correo: 'ana@ejemplo.com',
      fechaInicioContrato: '2026-01-01',
      fechaPagos: 15,
      syncState: 'synced',
      syncedAt: '2026-09-15T12:00:00Z',
    );

    final comprobante = ComprobantePagoData.fromPayment(pago, inquilino);
    final service = ComprobantePagoService();
    final bytes = await service.generatePdfBytes(comprobante);

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
