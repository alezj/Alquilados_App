/// Un pago pendiente con vencimiento por calendario, independiente de la red.
class PaymentReminder {
  const PaymentReminder({
    required this.paymentId,
    required this.tenantName,
    required this.dueDate,
    required this.graceDays,
  });
  final int paymentId;
  final String tenantName;
  final DateTime dueDate;
  final int graceDays;

  DateTime get overdueDate =>
      DateTime(dueDate.year, dueDate.month, dueDate.day + graceDays + 1);

  static PaymentReminder? fromRow(Map<String, dynamic> row) {
    if (![
      'pendiente',
      'vencido',
    ].contains(row['estado']?.toString().toLowerCase())) {
      return null;
    }
    if (row['alquiler_estado']?.toString().toLowerCase() != 'activo')
      return null;
    final date = DateTime.tryParse(row['fecha_pago']?.toString() ?? '');
    if (date == null) return null;
    return PaymentReminder(
      paymentId: (row['id'] as num).toInt(),
      tenantName: row['inquilino_nombre']?.toString() ?? 'Inquilino',
      dueDate: DateTime(date.year, date.month, date.day),
      graceDays: ((row['diasProrroga'] as num?)?.toInt() ?? 0).clamp(0, 365),
    );
  }
}

enum PaymentNoticeKind { due, overdue }

class PaymentNotice {
  const PaymentNotice(this.day, this.kind, this.payments);
  final DateTime day;
  final PaymentNoticeKind kind;
  final List<PaymentReminder> payments;
  int get id => (day.year * 10000 + day.month * 100 + day.day) * 2 + kind.index;
  String get key => '$id';
  DateTime get scheduledAt => DateTime(day.year, day.month, day.day, 9);
  String get title => kind == PaymentNoticeKind.due
      ? 'Hoy es día de pago'
      : 'Prórroga de pago vencida';
  String get body {
    final names = payments.map((p) => p.tenantName).toSet().take(3).join(', ');
    return '${payments.length} pago(s) pendiente(s): $names. Revisa los pagos para avisar por WhatsApp.';
  }
}

/// Agrupa todos los pagos de cada día para no perder avisos por el límite de iOS.
/// Incluye una recuperación de atrasos hoy; las 60 próximas agrupaciones se
/// renuevan al abrir la app o cambiar los datos.
List<PaymentNotice> buildPaymentNotices(
  List<PaymentReminder> payments,
  DateTime now,
) {
  final today = DateTime(now.year, now.month, now.day);
  final groups = <String, List<PaymentReminder>>{};
  final dates = <String, DateTime>{};
  final kinds = <String, PaymentNoticeKind>{};
  void add(DateTime day, PaymentNoticeKind kind, PaymentReminder payment) {
    final key = '${day.toIso8601String()}:${kind.name}';
    (groups[key] ??= []).add(payment);
    dates[key] = day;
    kinds[key] = kind;
  }

  for (final payment in payments) {
    if (!payment.dueDate.isBefore(today))
      add(payment.dueDate, PaymentNoticeKind.due, payment);
    final overdue = payment.overdueDate;
    add(
      overdue.isBefore(today) ? today : overdue,
      PaymentNoticeKind.overdue,
      payment,
    );
  }
  final notices =
      groups.entries
          .map(
            (entry) => PaymentNotice(
              dates[entry.key]!,
              kinds[entry.key]!,
              entry.value,
            ),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  return notices.take(60).toList();
}
