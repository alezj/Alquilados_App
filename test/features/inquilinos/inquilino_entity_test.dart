import 'package:flutter_test/flutter_test.dart';
import 'package:alquilados_app/features/inquilinos/domain/entities/inquilino.dart';

void main() {
  group('Inquilino Entity Tests', () {
    test('instantiates with default syncState pending', () {
      const inquilino = Inquilino(
        id: 1,
        nombreApellido: 'Carlos Mendoza',
        correo: 'carlos@test.com',
        fechaInicioContrato: '2024-01-15',
        fechaPagos: 15,
      );

      expect(inquilino.id, 1);
      expect(inquilino.nombreApellido, 'Carlos Mendoza');
      expect(inquilino.correo, 'carlos@test.com');
      expect(inquilino.fechaInicioContrato, '2024-01-15');
      expect(inquilino.fechaPagos, 15);
      expect(inquilino.syncState, 'pending');
      expect(inquilino.syncedAt, isNull);
    });

    test('supports custom syncState and syncedAt values', () {
      final now = DateTime.now().toIso8601String();
      final inquilino = Inquilino(
        id: 2,
        nombreApellido: 'Ana López',
        correo: 'ana@test.com',
        fechaInicioContrato: '2024-02-20',
        fechaPagos: 20,
        syncState: 'synced',
        syncedAt: now,
      );

      expect(inquilino.syncState, 'synced');
      expect(inquilino.syncedAt, now);
    });
  });
}
