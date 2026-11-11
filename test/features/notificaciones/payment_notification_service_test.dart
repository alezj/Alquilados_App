import 'dart:async';

import 'package:alquilados_app/core/storage/secure_storage_service.dart';
import 'package:alquilados_app/features/notificaciones/data/payment_notification_service.dart';
import 'package:alquilados_app/features/sync/data/datasources/local_database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class MockDatabase extends Mock implements LocalDatabaseService {}

class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockPlugin plugin;
  late MockDatabase database;
  late PaymentNotificationService service;
  late List<Map<String, dynamic>> rows;
  late Set<String> history;
  late Map<int, PendingNotificationRequest> pending;
  late List<tz.TZDateTime> scheduled;
  setUpAll(() {
    tz_data.initializeTimeZones();
    registerFallbackValue(tz.TZDateTime(tz.UTC, 2026));
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexactAllowWhileIdle);
  });
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterSecureStorage.setMockInitialValues({
      'payment_notifications_enabled': 'true',
      'auth_token_jwt': 'token',
      'auth_user_data_json': 'user-id',
      'auth_context':
          '{"environment":"test","tenant":"test_admin","username":"Johancel"}',
    });
    plugin = MockPlugin();
    database = MockDatabase();
    rows = [
      {
        'id': 1,
        'fecha_pago': '2026-11-12',
        'estado': 'pendiente',
        'alquiler_estado': 'Activo',
        'diasProrroga': 3,
        'inquilino_nombre': 'José',
      },
    ];
    history = {};
    pending = {};
    scheduled = [];
    when(() => database.changes).thenAnswer((_) => const Stream<void>.empty());
    when(() => database.getPaymentReminderRows()).thenAnswer((_) async => rows);
    when(() => database.wasNoticeScheduled(any()))
        .thenAnswer((i) async => history.contains(i.positionalArguments.first));
    when(() => database.recordNoticeScheduled(any())).thenAnswer((i) async {
      history.add(i.positionalArguments.first as String);
    });
    when(
      () => plugin.initialize(
        settings: any(named: 'settings'),
        onDidReceiveNotificationResponse: any(
          named: 'onDidReceiveNotificationResponse',
        ),
      ),
    ).thenAnswer((_) async => true);
    when(() => plugin.getNotificationAppLaunchDetails())
        .thenAnswer((_) async => null);
    when(() => plugin.pendingNotificationRequests())
        .thenAnswer((_) async => pending.values.toList());
    when(() => plugin.cancel(id: any(named: 'id'))).thenAnswer((i) async {
      pending.remove(i.namedArguments[#id]);
    });
    when(() => plugin.cancelAll()).thenAnswer((_) async {
      pending.clear();
    });
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((i) async {
      final id = i.namedArguments[#id] as int;
      pending[id] = PendingNotificationRequest(id, '', '', 'payments');
      scheduled.add(i.namedArguments[#scheduledDate] as tz.TZDateTime);
    });
    service = PaymentNotificationService(
      plugin: plugin,
      database: database,
      timezoneName: () async => 'America/Santo_Domingo',
      now: () => DateTime.utc(2026, 11, 11, 16),
    );
  });
  tearDown(() async {
    await service.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'programa las 9 locales y cancela ambos avisos cuando se paga',
    () async {
      await service.refresh();
      expect(service.lastError, isNull);
      expect(pending, hasLength(2));
      expect(scheduled.first.hour, 9);
      expect(scheduled.first.toUtc().hour, 13);
      rows = [];
      await service.refresh();
      expect(pending, isEmpty);
      verify(() => plugin.cancel(id: any(named: 'id'))).called(2);
    },
  );
  test(
    'el aviso de atraso ya entregado no se repite al abrir o refrescar',
    () async {
      rows.first['fecha_pago'] = '2026-10-12';
      await service.refresh();
      expect(scheduled, hasLength(1));
      pending.clear(); // El sistema ya entregó el aviso.
      await service.refresh();
      expect(scheduled, hasLength(1));
      expect(service.lastError, isNull);
    },
  );
  test('cerrar sesión cancela avisos del propietario anterior', () async {
    await service.refresh();
    await SecureStorageService().clearSession();
    await service.refresh();
    expect(pending, isEmpty);
    verify(() => plugin.cancelAll()).called(1);
  });
  test('permiso denegado no activa ni programa notificaciones', () async {
    final android = MockAndroidPlugin();
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);
    when(() => android.requestNotificationsPermission())
        .thenAnswer((_) async => false);
    expect(await service.setEnabled(true), isFalse);
    expect(await service.isEnabled(), isFalse);
    expect(scheduled, isEmpty);
  });
}
