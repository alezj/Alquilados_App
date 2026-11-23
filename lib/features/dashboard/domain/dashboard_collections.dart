import '../../pagos/domain/entities/pago.dart';

class DashboardCollections {
  DashboardCollections.fromPayments({
    required this.today,
    required Iterable<Pago> payments,
  }) {
    final month = today.toIso8601String().substring(0, 7);
    for (final payment in payments) {
      final date = payment.fechaCalendario;
      final dateMonth = date?.toIso8601String().substring(0, 7);
      final period = payment.periodo?.trim();
      final scheduledMonth =
          period != null &&
              RegExp(r'^\d{4}-(0[1-9]|1[0-2])(?:$|-)').hasMatch(period)
          ? period.substring(0, 7)
          : dateMonth;

      if (payment.estadoNormalizado == 'pagado' && payment.monto.isFinite) {
        if (dateMonth == month) collected += payment.monto;
        if (scheduledMonth == month) collectedForPeriod += payment.monto;
      } else if (payment.porCobrar &&
          scheduledMonth == month &&
          payment.monto.isFinite) {
        outstanding += payment.monto;
      }

      if (payment.estaVencido(today)) overdue++;
      if (payment.venceEnSieteDias(today)) upcoming++;
    }
  }

  final DateTime today;
  double collected = 0;
  double collectedForPeriod = 0;
  double outstanding = 0;
  int overdue = 0;
  int upcoming = 0;

  double get expected => collectedForPeriod + outstanding;

  double? get collectionProgress =>
      expected > 0 ? (collectedForPeriod / expected).clamp(0.0, 1.0) : null;
}
