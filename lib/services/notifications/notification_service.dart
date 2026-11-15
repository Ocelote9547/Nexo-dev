import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final loc = tz.getLocation(DateTime.now().timeZoneName);
        tz.setLocalLocation(loc);
      } catch (_) {
        // keep default
      }
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'birthdays_sound',
            'Cumpleaños (con sonido)',
            description: 'Avisos de cumpleaños con sonido',
            importance: Importance.high,
            playSound: true,
          ));
      await androidImpl
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'birthdays_silent',
            'Cumpleaños (sin sonido)',
            description: 'Avisos de cumpleaños sin sonido',
            importance: Importance.high,
            playSound: false,
          ));
    } catch (_) {
      // En entornos de prueba (sin canales de plataforma de Android),
      // la inicialización puede fallar. Se marca como inicializado para
      // evitar reintentos y las operaciones posteriores devolverán valores
      // seguros (sin permiso, sin programar).
    }
    _initialized = true;
  }

  /// Comprueba si el permiso de notificaciones está concedido.
  Future<bool> hasPermission() async {
    await init();
    try {
      final status = await ph.Permission.notification.status;
      return status == ph.PermissionStatus.granted;
    } catch (_) {
      return false;
    }
  }

  /// Solicita el permiso de notificaciones en Android 13+.
  /// Devuelve el estado resultante del permiso.
  Future<ph.PermissionStatus> requestPermission() async {
    await init();
    try {
      final status = await ph.Permission.notification.status;
      if (status == ph.PermissionStatus.granted) return status;
      final result = await ph.Permission.notification.request();
      return result;
    } catch (_) {
      return ph.PermissionStatus.denied;
    }
  }

  /// Abre los ajustes de la aplicación en Android para gestionar permisos.
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  /// Identificador determinista y persistente a partir del UUID del cumpleaños.
  int notificationIdFor(String dateId) {
    final bytes = utf8.encode(dateId);
    final digest = sha256.convert(bytes);
    return digest.bytes.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
  }

  bool _isLeapYear(int year) =>
      (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

  /// Programa avisos para los próximos 5 años de un cumpleaños (mes/día).
  /// Cada año usa un identificador distinto pero derivado del mismo dateId.
  /// Devuelve false si no hay permiso para mostrar notificaciones.
  Future<bool> scheduleBirthdayNotifications({
    required String dateId,
    required String contactName,
    required int month,
    required int day,
    required int advanceDays,
    required bool sound,
  }) async {
    await init();
    if (!(await hasPermission())) return false;
    final now = DateTime.now();
    for (var offset = 0; offset < 5; offset++) {
      final year = now.year + offset;
      var effectiveDay = day;
      if (month == 2 && day == 29 && !_isLeapYear(year)) {
        effectiveDay = 28;
      }
      final birthday = DateTime(year, month, effectiveDay);
      var notify = birthday.subtract(Duration(days: advanceDays));
      if (notify.isBefore(now)) continue;
      final id = notificationIdFor('${dateId}_$year');
      await scheduleBirthday(
        id: id,
        title: 'Cumpleaños de $contactName',
        body: 'Hoy es el cumpleaños de $contactName',
        when: notify,
        sound: sound,
      );
    }
    return true;
  }

  /// Cancela todos los avisos programados para un cumpleaños (cualquier año).
  Future<void> cancelBirthdayNotifications(String dateId) async {
    await init();
    final now = DateTime.now();
    for (var offset = 0; offset < 5; offset++) {
      final year = now.year + offset;
      final id = notificationIdFor('${dateId}_$year');
      await cancel(id);
    }
  }

  Future<void> scheduleBirthday({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    bool sound = true,
  }) async {
    await init();
    final scheduled = tz.TZDateTime.from(when, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          sound ? 'birthdays_sound' : 'birthdays_silent',
          sound ? 'Cumpleaños (con sonido)' : 'Cumpleaños (silencioso)',
          importance: Importance.high,
          playSound: sound,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }
}
