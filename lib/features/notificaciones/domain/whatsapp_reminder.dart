import 'package:intl/intl.dart';

class WhatsAppReminder {
  /// Requiere código de país explícito; no adivina el destino del mensaje.
  static String? normalizePhone(String phone) {
    final input = phone.trim();
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(input)) return null;
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(digits) ? digits : null;
  }

  static Uri build({
    required String phone,
    required String tenantName,
    required DateTime dueDate,
    required int graceDays,
    required double amount,
    required DateTime now,
  }) {
    final number = normalizePhone(phone);
    if (number == null)
      throw const FormatException(
        'Registra un teléfono con código de país, por ejemplo +1 809 555 0123.',
      );
    final overdue = DateTime(
      dueDate.year,
      dueDate.month,
      dueDate.day + graceDays + 1,
    );
    final today = DateTime(now.year, now.month, now.day);
    final date = DateFormat('dd/MM/yyyy').format(dueDate);
    final status = !today.isBefore(overdue)
        ? 'La prórroga de $graceDays día(s) ha vencido y el pago sigue pendiente.'
        : 'Te recordamos el pago de alquiler con fecha $date.';
    final message =
        'Hola $tenantName. $status Importe: RD\$${NumberFormat('#,##0.00').format(amount)}. '
        'Vencimiento: $date. Si ya realizaste el pago, por favor comparte tu comprobante. Gracias.';
    return Uri.https('wa.me', '/$number', {'text': message});
  }
}
