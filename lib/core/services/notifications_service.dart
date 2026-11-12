import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../feature/tracker/service/reminder_scheduler.dart';

const _minInterval = Duration(minutes: 1);

/// Clamps a break interval to a sane minimum (≥ 1 minute) so a zero/negative
/// setting never schedules a reminder in the past or spins immediately.
Duration clampInterval(Duration d) => d < _minInterval ? _minInterval : d;

/// [NotificationsPort] implementation backed by `flutter_local_notifications`
/// for iOS + macOS — the fallback shown when a break fires while the app is
/// backgrounded.
class NotificationsService implements NotificationsPort {
  NotificationsService() : _plugin = FlutterLocalNotificationsPlugin();

  static const _notificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin;

  /// Requests iOS + macOS permission and wires up the plugin. Call once at
  /// startup; a denied permission never blocks tracking or the in-app
  /// overlay (Review Focus) — it only means this fallback stays silent.
  Future<void> init() async {
    const settings = InitializationSettings(
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  @override
  Future<void> scheduleAt(DateTime time, String title, String body) async {
    final scheduled = tz.TZDateTime.from(time, tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }
    await _plugin.zonedSchedule(
      _notificationId,
      title,
      body,
      scheduled,
      const NotificationDetails(
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}
