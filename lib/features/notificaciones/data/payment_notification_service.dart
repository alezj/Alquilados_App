import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/storage/secure_storage_service.dart';
import '../../sync/data/datasources/local_database_service.dart';
import '../domain/payment_reminder.dart';

class PaymentNotificationService {
  PaymentNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    FlutterSecureStorage? preferences,
    LocalDatabaseService? database,
    Future<String> Function()? timezoneName,
    DateTime Function()? now,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _preferences = preferences ?? const FlutterSecureStorage(),
       _database = database ?? LocalDatabaseService(),
       _timezoneName =
           timezoneName ??
           (() async => (await FlutterTimezone.getLocalTimezone()).identifier),
       _now = now ?? DateTime.now;
  static final instance = PaymentNotificationService();
  final FlutterLocalNotificationsPlugin _plugin;
  final FlutterSecureStorage _preferences;
  final LocalDatabaseService _database;
  final Future<String> Function() _timezoneName;
  final DateTime Function() _now;
  StreamSubscription<void>? _subscription;
  bool _initialized = false;
  Timer? _debounce;
  Future<void> _queue = Future.value();
  String? lastError;
  bool openPaymentsRequested = false;
  VoidCallback? onOpenPayments;

  bool get supported =>
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);

  Future<bool> isEnabled() async =>
      supported &&
      await _preferences.read(key: 'payment_notifications_enabled') == 'true';

  Future<void> initialize() async {
    if (!supported || _initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _timezoneName()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_payment_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) {
        openPaymentsRequested = true;
        onOpenPayments?.call();
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    openPaymentsRequested = launch?.didNotificationLaunchApp ?? false;
    _initialized = true;
    _subscription = _database.changes.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 500),
        () => unawaited(refresh()),
      );
    });
  }

  Future<void> activateOnFirstLogin() async {
    if (!supported) return;
    try {
      if (await _preferences.read(key: 'payment_notifications_enabled') ==
          null) {
        await setEnabled(true);
      } else {
        await refresh();
      }
    } catch (error) {
      lastError = 'No se pudieron activar los avisos de pago: $error';
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (!supported) return false;
    await initialize();
    if (enabled) {
      final bool allowed;
      if (defaultTargetPlatform == TargetPlatform.android) {
        allowed =
            await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      } else {
        allowed =
            await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
      if (!allowed) {
        await _preferences.write(
          key: 'payment_notifications_enabled',
          value: 'false',
        );
        await cancel();
        return false;
      }
    }
    await _preferences.write(
      key: 'payment_notifications_enabled',
      value: '$enabled',
    );
    if (enabled) {
      await refresh();
    } else {
      await cancel();
    }
    return enabled;
  }

  /// Serializa reprogramaciones para que un pago marcado como pagado cancele
  /// también un aviso que estuviera programándose en ese momento.
  Future<void> refresh() {
    _queue = _queue.then((_) => _refresh()).catchError((Object error) {
      lastError = 'No se pudieron actualizar los avisos de pago: $error';
    });
    return _queue;
  }

  Future<void> _refresh() async {
    if (!supported) return;
    await initialize();
    if (!await isEnabled()) return;
    final storage = SecureStorageService();
    final session = await storage.getSessionContext();
    if (session == null || !await storage.hasToken()) {
      await _plugin.cancelAll();
      return;
    }
    // También refresca la zona si el usuario viajó o cambió ajustes del teléfono.
    tz.setLocalLocation(tz.getLocation(await _timezoneName()));
    final now = tz.TZDateTime.from(_now(), tz.local);
    final rows = await _database.getPaymentReminderRows();
    final payments = rows
        .map(PaymentReminder.fromRow)
        .whereType<PaymentReminder>()
        .toList();
    final notices = buildPaymentNotices(payments, now);
    final pending = await _plugin.pendingNotificationRequests();
    final pendingIds = pending.map((p) => p.id).toSet();
    final wanted = notices.map((n) => n.id).toSet();
    for (final notification in pending) {
      if (!wanted.contains(notification.id))
        await _plugin.cancel(id: notification.id);
    }
    final userId = await storage.getUserData() ?? '';
    for (final notice in notices) {
      final historyKey = '$userId:${notice.key}';
      final planned = tz.TZDateTime(
        tz.local,
        notice.day.year,
        notice.day.month,
        notice.day.day,
        9,
      );
      final late = !planned.isAfter(now);
      if (late &&
          !pendingIds.contains(notice.id) &&
          await _database.wasNoticeScheduled(historyKey))
        continue;
      final scheduled = late ? now.add(const Duration(seconds: 5)) : planned;
      await _plugin.zonedSchedule(
        id: notice.id,
        title: notice.title,
        body: notice.body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'payment_reminders',
            'Avisos de pagos',
            channelDescription: 'Día de pago y vencimiento de prórroga',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'payments',
      );
      await _database.recordNoticeScheduled(historyKey);
    }
    lastError = null;
  }

  Future<void> dispose() async {
    _debounce?.cancel();
    await _subscription?.cancel();
    await _queue;
  }

  Future<void> cancel() async {
    if (!supported) return;
    _debounce?.cancel();
    // Las operaciones en curso terminan antes de borrar avisos de otra sesión.
    await _queue;
    try {
      await initialize();
      await _plugin.cancelAll();
    } catch (error) {
      lastError = 'No se pudieron cancelar los avisos: $error';
    }
    // Conserva una apertura desde notificación durante el login.
  }
}
