import 'package:alquilados_app/features/notificaciones/domain/payment_reminder.dart';
import 'package:alquilados_app/features/notificaciones/domain/whatsapp_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PaymentReminder payment(int id, DateTime day, {int grace = 3}) =>
      PaymentReminder(
        paymentId: id,
        tenantName: 'José $id',
        dueDate: day,
        graceDays: grace,
      );

  test('la prórroga incluye todos los días y avisa al día siguiente', () {
    final p = payment(1, DateTime(2026, 11, 15));
    expect(p.overdueDate, DateTime(2026, 11, 19));
  });
  test('cero días de prórroga avisa al día siguiente del vencimiento', () {
    expect(
      payment(1, DateTime(2026, 11, 15), grace: 0).overdueDate,
      DateTime(2026, 11, 16),
    );
  });
  test('maneja cambio de mes, año y año bisiesto', () {
    expect(
      payment(1, DateTime(2026, 12, 31)).overdueDate,
      DateTime(2027, 1, 4),
    );
    expect(
      payment(1, DateTime(2028, 2, 28), grace: 1).overdueDate,
      DateTime(2028, 3, 1),
    );
  });
  test('un pago pagado o contrato cancelado no produce recordatorio', () {
    final row = {
      'id': 1,
      'fecha_pago': '2026-11-15',
      'estado': 'pagado',
      'alquiler_estado': 'Activo',
    };
    expect(PaymentReminder.fromRow(row), isNull);
    row['estado'] = 'pendiente';
    row['alquiler_estado'] = 'Cancelado';
    expect(PaymentReminder.fromRow(row), isNull);
    row['alquiler_estado'] = 'Activo';
    row['fecha_pago'] = 'fecha inválida';
    expect(PaymentReminder.fromRow(row), isNull);
  });
  test(
    'agrupa todos los inquilinos del día sin exceder el límite del sistema',
    () {
      final notices = buildPaymentNotices(
        List.generate(200, (i) => payment(i, DateTime(2026, 11, 15))),
        DateTime(2026, 11, 11),
      );
      expect(notices, hasLength(2));
      expect(notices.first.payments, hasLength(200));
      expect(notices.first.scheduledAt, DateTime(2026, 11, 15, 9));
    },
  );
  test('recupera atrasos hoy y conserva los vencimientos futuros', () {
    final notices = buildPaymentNotices([
      payment(1, DateTime(2026, 10, 15)),
      payment(2, DateTime(2026, 12, 15)),
    ], DateTime(2026, 11, 11, 12));
    expect(notices.first.kind, PaymentNoticeKind.overdue);
    expect(notices.first.day, DateTime(2026, 11, 11));
    expect(
      notices.where((n) => n.kind == PaymentNoticeKind.due).single.day,
      DateTime(2026, 12, 15),
    );
  });
  test(
    'retiene las 60 agrupaciones más cercanas y no pierde pagos del mismo día',
    () {
      final notices = buildPaymentNotices(
        List.generate(100, (i) => payment(i, DateTime(2027, 1, i + 1))),
        DateTime(2026, 11, 11),
      );
      expect(notices, hasLength(60));
      expect(notices.map((n) => n.id).toSet(), hasLength(60));
      expect(notices.first.day, DateTime(2027, 1, 1));
    },
  );
  test(
    'WhatsApp valida destino internacional y codifica el mensaje con tildes',
    () {
      final uri = WhatsAppReminder.build(
        phone: '+1 (809) 555-0123',
        tenantName: 'José & Ana',
        dueDate: DateTime(2026, 11, 15),
        graceDays: 3,
        amount: 12000,
        now: DateTime(2026, 11, 15),
      );
      expect(uri.host, 'wa.me');
      expect(uri.path, '/18095550123');
      expect(uri.queryParameters['text'], contains('José & Ana'));
      expect(uri.queryParameters['text'], contains('12,000.00'));
      expect(uri.queryParameters['text'], isNot(contains('ha vencido')));
      expect(WhatsAppReminder.normalizePhone('809'), isNull);
      expect(WhatsAppReminder.normalizePhone('18095550123&text=otro'), isNull);
    },
  );
  test(
    'WhatsApp cambia a mensaje de prórroga vencida solo al superar el plazo',
    () {
      Uri message(DateTime now) => WhatsAppReminder.build(
        phone: '+18095550123',
        tenantName: 'José',
        dueDate: DateTime(2026, 11, 15),
        graceDays: 3,
        amount: 12000,
        now: now,
      );
      expect(
        message(DateTime(2026, 11, 18, 23)).queryParameters['text'],
        isNot(contains('ha vencido')),
      );
      expect(
        message(DateTime(2026, 11, 19)).queryParameters['text'],
        contains('ha vencido'),
      );
    },
  );
}
