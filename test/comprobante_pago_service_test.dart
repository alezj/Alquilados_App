import 'package:alquilados_app/features/inquilinos/domain/entities/inquilino.dart';
import 'package:alquilados_app/features/pagos/domain/entities/comprobante_pago.dart';
import 'package:alquilados_app/features/pagos/domain/entities/pago.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildComprobantePago crea un comprobante no fiscal con los datos del pago', () {
    final pago = Pago(
      id: 42,
      idInquilino: '7',
      fechaPago: '2026-09-15',
      monto: 1250.0,
      estado: 'pagado',
      syncState: 'synced',
      syncedAt: '2026-09-15T12:00:00Z',
    );

    final inquilino = Inquilino(
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
    expect(comprobante.titulo, 'COMPROBANTE NO FISCAL');
    expect(comprobante.inquilinoNombre, 'Ana García');
    expect(comprobante.montoFormateado, '\$1,250.00');
    expect(comprobante.rows.first['label'], 'Número');
  });
}
