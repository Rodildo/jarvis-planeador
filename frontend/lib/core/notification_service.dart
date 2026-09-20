import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorios locales de Jarvis: el chequeo matutino de energía (diario,
/// hora fija) y el chequeo de mitad de día (una sola vez, 6h después de
/// confirmar el día). No depende de un servidor push: todo se agenda en el
/// propio dispositivo con `flutter_local_notifications`.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _morningNotificationId = 1;
  static const int _middayNotificationId = 2;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  GoRouter? _router;

  /// Se registra desde ChatProvider para reabrir el flujo de chequeo de
  /// energía cuando el usuario toca la notificación de mitad de día.
  VoidCallback? onMiddayTap;

  Future<void> init(GoRouter router) async {
    _router = router;

    tz.initializeTimeZones();
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } catch (_) {
      // Si no se puede resolver la zona horaria del dispositivo, seguimos
      // con la zona por defecto en vez de romper el arranque de la app.
    }

    // Debe existir como drawable (no mipmap): flutter_local_notifications
    // busca el ícono ahí y falla en el dispositivo real si no lo encuentra.
    const androidSettings = AndroidInitializationSettings('ic_notification');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _handleTap,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Se llama una vez al arrancar la app (si hay notificationResponse en el
  /// tap que abrió la app, ya que onDidReceiveNotificationResponse no se
  /// dispara para un cold start).
  Future<void> handleAppLaunchFromNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      _handleTap(details!.notificationResponse!);
    }
  }

  void _handleTap(NotificationResponse response) {
    if (response.payload == 'midday') {
      onMiddayTap?.call();
    }
    _router?.go('/chat');
  }

  Future<void> scheduleMorningReminder() {
    return _plugin.zonedSchedule(
      id: _morningNotificationId,
      title: 'Buenos días, jefe',
      body: '¿Cómo está la batería hoy? Reporta tu energía del 1 al 5.',
      scheduledDate: _nextInstanceOfLocalTime(8, 0),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_check_channel',
          'Chequeo matutino',
          channelDescription: 'Recordatorio diario para reportar tu nivel de energía',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'morning',
    );
  }

  Future<void> scheduleMiddayCheck(Duration delay) {
    return _plugin.zonedSchedule(
      id: _middayNotificationId,
      title: 'Chequeo de mitad de día',
      body: 'Han pasado 6 horas. ¿Cómo está tu energía ahora?',
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'midday_check_channel',
          'Chequeo de 6 horas',
          channelDescription: 'Seguimiento de energía a mitad del día',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'midday',
    );
  }

  Future<void> cancelMiddayCheck() => _plugin.cancel(id: _middayNotificationId);

  tz.TZDateTime _nextInstanceOfLocalTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
