import 'package:intl/intl.dart';

/// Extensiones de ayuda para tipos numéricos (montos, pagos, rentas).
extension CurrencyExtension on num {
  /// Formatea un número como moneda estándar (ej: 1250 -> "$1,250.00")
  String toCurrency({String symbol = '\$', int decimalDigits = 2}) {
    final format = NumberFormat.currency(
      locale: 'en_US',
      symbol: symbol,
      decimalDigits: decimalDigits,
    );
    return format.format(this);
  }
}

/// Extensiones de ayuda para fechas de contratos y pagos.
extension DateFormattingExtension on DateTime {
  /// Formatea fecha corta (ej: "18/09/2026")
  String toShortDate() {
    return DateFormat('dd/MM/yyyy').format(this);
  }

  /// Formatea fecha con mes abreviado (ej: "18 Sep 2026")
  String toMediumDate() {
    return DateFormat('dd MMM yyyy').format(this);
  }

  /// Formatea fecha completa legible (ej: "18 de septiembre, 2026")
  String toFullDate() {
    return DateFormat('d \'de\' MMMM, yyyy').format(this);
  }
}

/// Extensiones de ayuda para Strings (validaciones y formato)
extension StringHelpersExtension on String {
  /// Capitaliza la primera letra de un texto
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Comprueba si la cadena tiene un formato de correo electrónico válido
  bool get isValidEmail {
    final emailRegex = RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
    return emailRegex.hasMatch(trim());
  }
}
