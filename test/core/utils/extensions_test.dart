import 'package:alquilados_app/core/utils/extensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyExtension — toCurrency', () {
    test('formatea entero positivo', () {
      expect(1250.toCurrency(), r'$1,250.00');
    });

    test('formatea cero', () {
      expect(0.toCurrency(), r'$0.00');
    });

    test('formatea decimal con centavos', () {
      expect(3500.50.toCurrency(), r'$3,500.50');
    });

    test('respeta símbolo personalizado', () {
      expect(1000.toCurrency(symbol: '€'), '€1,000.00');
    });

    test('respeta decimalDigits personalizado', () {
      expect(1234.5678.toCurrency(decimalDigits: 0), r'$1,235');
    });

    test('formatea número negativo', () {
      expect((-500).toCurrency(), r'-$500.00');
    });

    test('formatea número grande', () {
      expect(1000000.toCurrency(), r'$1,000,000.00');
    });
  });

  group('DateFormattingExtension', () {
    final date = DateTime(2026, 9, 18);

    test('toShortDate → dd/MM/yyyy', () {
      expect(date.toShortDate(), '18/09/2026');
    });

    test('toMediumDate → dd MMM yyyy', () {
      expect(date.toMediumDate(), '18 Sep 2026');
    });

    test('toFullDate contiene el año y el día', () {
      // El mes depende del locale del entorno de test; sólo verificamos
      // que el resultado contenga el año y el día numérico esperados.
      final result = date.toFullDate();
      expect(result, contains('2026'));
      expect(result, contains('18'));
    });

    test('toShortDate para enero (mes de un dígito)', () {
      final jan = DateTime(2026, 1, 5);
      expect(jan.toShortDate(), '05/01/2026');
    });
  });

  group('StringHelpersExtension', () {
    test('capitalize — string normal', () {
      expect('alquilado'.capitalize(), 'Alquilado');
    });

    test('capitalize — string vacío', () {
      expect(''.capitalize(), '');
    });

    test('capitalize — ya mayúscula', () {
      expect('Propiedad'.capitalize(), 'Propiedad');
    });

    test('capitalize — una sola letra', () {
      expect('a'.capitalize(), 'A');
    });

    test('isValidEmail — correo válido simple', () {
      expect('usuario@alquilados.com'.isValidEmail, isTrue);
    });

    test('isValidEmail — correo válido con plus y punto', () {
      expect('test.email+alias@gmail.com'.isValidEmail, isTrue);
    });

    test('isValidEmail — sin arroba', () {
      expect('correo_invalido'.isValidEmail, isFalse);
    });

    test('isValidEmail — sin usuario', () {
      expect('@falta_usuario.com'.isValidEmail, isFalse);
    });

    test('isValidEmail — cadena vacía', () {
      expect(''.isValidEmail, isFalse);
    });

    test('isValidEmail — solo espacios', () {
      expect('   '.isValidEmail, isFalse);
    });
  });
}
