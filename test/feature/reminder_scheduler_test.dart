import 'package:flutter_test/flutter_test.dart';
import 'package:timer/feature/settings/data/reminder_settings.dart';
import 'package:timer/feature/tracker/service/reminder_scheduler.dart';

class _FakeNotificationsPort implements NotificationsPort {
  DateTime? lastScheduledAt;
  bool cancelledAll = false;

  @override
  Future<void> scheduleAt(DateTime time, String title, String body) async {
    lastScheduledAt = time;
  }

  @override
  Future<void> cancelAll() async {
    cancelledAll = true;
  }
}

void main() {
  late _FakeNotificationsPort fakePort;
  late ReminderSettings settings;
  late DateTime now;
  late ReminderScheduler scheduler;

  setUp(() {
    fakePort = _FakeNotificationsPort();
    settings = ReminderSettings(interval: const Duration(minutes: 90));
    now = DateTime(2026, 11, 2, 9, 0);
    scheduler = ReminderScheduler(
      settings: settings,
      notifications: fakePort,
      onBreakDue: (_) {},
      now: () => now,
    );
  });

  test('start schedules a break one interval later', () {
    scheduler.onTimerStarted(DateTime(2026, 11, 2, 9, 0));
    expect(fakePort.lastScheduledAt, DateTime(2026, 11, 2, 10, 30));
  });

  test('firing re-arms another interval later', () {
    scheduler.onBreakFired(DateTime(2026, 11, 2, 10, 30));
    expect(fakePort.lastScheduledAt, DateTime(2026, 11, 2, 12, 0));
  });

  test('stop cancels pending reminders', () {
    scheduler.onTimerStopped();
    expect(fakePort.cancelledAll, true);
  });

  test('settings change re-arms from now with the new interval', () {
    scheduler.onTimerStarted(DateTime(2026, 11, 2, 9, 0));
    settings.interval = const Duration(minutes: 30);
    now = DateTime(2026, 11, 2, 9, 10);
    scheduler.onSettingsChanged();
    expect(fakePort.lastScheduledAt, DateTime(2026, 11, 2, 9, 40));
  });
}
