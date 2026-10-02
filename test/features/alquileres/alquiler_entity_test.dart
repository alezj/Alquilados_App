import 'package:flutter_test/flutter_test.dart';

import 'package:alquilados_app/features/alquileres/domain/entities/alquiler.dart';

void main() {
  group('Alquiler entity', () {
    test('lee montoPago cuando existe y lo usa como monto que paga el inquilino', () {
      final alquiler = Alquiler.fromMap({
        'id': 1,
        'propiedad_id': 3,
        'inquilino_id': 7,
        'fecha_inicio': '2026-09-01',
        'fecha_fin': '2027-08-31',
        'importe': 45000.0,
        'montoPago': 32000.0,
        'cantidadDepositos': 2,
        'diaPago': 15,
        'estado': 'Activo',
      });

      expect(alquiler.montoPago, 32000.0);
      expect(alquiler.importe, 45000.0);
      expect(alquiler.cantidadDepositos, 2);
      expect(alquiler.diaPago, 15);
    });

    test('usa importe como respaldo si montoPago no viene informado', () {
      final alquiler = Alquiler.fromMap({
        'id': 2,
        'propiedad_id': 4,
        'inquilino_id': 8,
        'fecha_inicio': '2026-08-15',
        'fecha_fin': '2027-08-14',
        'importe': 28000.0,
        'cantidadDepositos': 1,
        'diaPago': 30,
        'estado': 'Pendiente',
      });

      expect(alquiler.montoPago, 28000.0);
      expect(alquiler.cantidadDepositos, 1);
      expect(alquiler.diaPago, 30);
    });
  });
}
