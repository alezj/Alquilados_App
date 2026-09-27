import 'package:flutter_test/flutter_test.dart';
import 'package:alquilados_app/features/propiedades/data/models/propiedad_model.dart';
import 'package:alquilados_app/features/inquilinos/data/models/inquilino_model.dart';
import 'package:alquilados_app/features/pagos/data/models/pago_model.dart';

void main() {
  group('Models Serialization Tests', () {
    test('PropiedadModel.fromJson parses fields correctly', () {
      final json = {
        'id': 1,
        'nombre': 'Casa Bella',
        'direccion': 'Av. Libertador 123',
        'estado': 1,
        'precioMensual': 450.5,
        'notas': 'Sin mascotas',
      };

      final model = PropiedadModel.fromJson(json);

      expect(model.id, 1);
      expect(model.nombre, 'Casa Bella');
      expect(model.direccion, 'Av. Libertador 123');
      expect(model.estado, 1);
      expect(model.precioMensual, 450.5);
      expect(model.notas, 'Sin mascotas');
    });

    test('PropiedadModel.fromJson handles string and fallback conversions', () {
      final json = {
        'id': '2',
        'nombre': null,
        'direccion': null,
        'estado': '3',
        'precioMensual': '500.0',
        'notas': null,
      };

      final model = PropiedadModel.fromJson(json);

      expect(model.id, 2);
      expect(model.nombre, '');
      expect(model.direccion, '');
      expect(model.estado, 3);
      expect(model.precioMensual, 500.0);
      expect(model.notas, '');
    });

    test('InquilinoModel.fromJson parses fields correctly', () {
      final json = {
        'id': 10,
        'nombreApellido': 'Juan Perez',
        'correo': 'juan@example.com',
        'fechaInicioContrato': '2026-01-01',
        'fechaPagos': 5,
      };

      final model = InquilinoModel.fromJson(json);

      expect(model.id, 10);
      expect(model.nombreApellido, 'Juan Perez');
      expect(model.correo, 'juan@example.com');
      expect(model.fechaInicioContrato, '2026-01-01');
      expect(model.fechaPagos, 5);
    });

    test('InquilinoModel.fromJson falls back to email if correo is null', () {
      final json = {
        'id': '11',
        'nombreApellido': 'Maria Lopez',
        'email': 'maria@example.com',
        'fechaInicioContrato': '2026-02-01',
        'fechaPagos': '10',
      };

      final model = InquilinoModel.fromJson(json);

      expect(model.id, 11);
      expect(model.correo, 'maria@example.com');
      expect(model.fechaPagos, 10);
    });

    test('PagoModel.fromJson parses fields correctly', () {
      final json = {
        'id': 100,
        'idInquilino': '10',
        'fechaPago': '2026-03-01',
        'monto': 350.0,
      };

      final model = PagoModel.fromJson(json);

      expect(model.id, 100);
      expect(model.idInquilino, '10');
      expect(model.fechaPago, '2026-03-01');
      expect(model.monto, 350.0);
    });
  });
}
