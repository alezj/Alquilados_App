import 'package:alquilados_app/core/utils/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Extensions Tests', () {
    test('toCurrency formatea números correctamente', () {
      expect(1250.toCurrency(), '\$1,250.00');
      expect(0.toCurrency(), '\$0.00');
      expect(3500.50.toCurrency(), '\$3,500.50');
    });

    test('toShortDate formatea fecha a dd/MM/yyyy', () {
      final date = DateTime(2026, 9, 18);
      expect(date.toShortDate(), '18/09/2026');
    });

    test('capitalize convierte primera letra en mayúscula', () {
      expect('alquilado'.capitalize(), 'Alquilado');
      expect(''.capitalize(), '');
    });

    test('isValidEmail valida correos correctamente', () {
      expect('usuario@alquilados.com'.isValidEmail, isTrue);
      expect('test.email+alias@gmail.com'.isValidEmail, isTrue);
      expect('correo_invalido'.isValidEmail, isFalse);
      expect('@falta_usuario.com'.isValidEmail, isFalse);
      expect(''.isValidEmail, isFalse);
    });
  });
}
