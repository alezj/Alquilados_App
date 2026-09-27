import 'package:flutter_test/flutter_test.dart';
import 'package:alquilados_app/features/propiedades/domain/entities/propiedad.dart';

void main() {
  group('Propiedad Entity Tests', () {
    test('instantiates with default syncState pending', () {
      const propiedad = Propiedad(
        id: 1,
        nombre: 'Villa Palmera',
        direccion: 'Av. Circunvalación 10',
        estado: 1,
        precioMensual: 1500.0,
        notas: 'Excelente ubicación',
      );

      expect(propiedad.id, 1);
      expect(propiedad.nombre, 'Villa Palmera');
      expect(propiedad.direccion, 'Av. Circunvalación 10');
      expect(propiedad.estado, 1);
      expect(propiedad.precioMensual, 1500.0);
      expect(propiedad.notas, 'Excelente ubicación');
      expect(propiedad.syncState, 'pending');
      expect(propiedad.syncedAt, isNull);
    });

    test('supports custom syncState and syncedAt values', () {
      final now = DateTime.now().toIso8601String();
      final propiedad = Propiedad(
        id: 2,
        nombre: 'Torre Vista',
        direccion: 'Calle Sol 22',
        estado: 2,
        precioMensual: 2200.0,
        notas: 'Amueblada',
        syncState: 'synced',
        syncedAt: now,
      );

      expect(propiedad.syncState, 'synced');
      expect(propiedad.syncedAt, now);
    });
  });
}
