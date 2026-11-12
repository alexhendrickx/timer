import '../../settings/data/reminder_settings.dart';

/// Abstracts the OS notification layer so [ReminderScheduler] stays
/// platform-free and testable. [NotificationsService] (core/services) is the
/// real iOS + macOS implementation.
abstract class NotificationsPort {
  Future<void> scheduleAt(DateTime time, String title, String body);
  Future<void> cancelAll();
}

/// Schedules the next gentle break reminder while a timer runs, re-arming
/// one interval later each time a break fires, and cancels on stop. Platform-
/// free: the UI decides how to show a due break via [onBreakDue].
class ReminderScheduler {
  ReminderScheduler({
    required this.settings,
    required this.notifications,
    required this.onBreakDue,
    this.onNextScheduled,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReminderSettings settings;
  final NotificationsPort notifications;
  final void Function(DateTime firedAt) onBreakDue;

  /// Notified with the next break's due time whenever one is (re-)armed, so
  /// a caller that wants to fire [onBreakFired] in real time (main.dart, via
  /// a `Timer`) knows when to. Optional: tests drive [onBreakFired] by hand
  /// and never need this.
  final void Function(DateTime nextAt)? onNextScheduled;

  final DateTime Function() _now;

  bool _running = false;

  /// Schedules the first break at [start] + the current interval.
  void onTimerStarted(DateTime start) {
    _running = true;
    _scheduleNext(start);
  }

  /// A break fired at [firedAt]: notify, then re-schedule one interval later.
  void onBreakFired(DateTime firedAt) {
    onBreakDue(firedAt);
    _scheduleNext(firedAt);
  }

  /// Cancels any pending reminder.
  void onTimerStopped() {
    _running = false;
    notifications.cancelAll();
  }

  /// Re-arms from now with the current interval, if a timer is running.
  void onSettingsChanged() {
    if (!_running) return;
    _scheduleNext(_now());
  }

  void _scheduleNext(DateTime from) {
    final nextAt = from.add(settings.interval);
    notifications.scheduleAt(
      nextAt,
      'Time to stand',
      'You have been tracking for a while — take a short break.',
    );
    onNextScheduled?.call(nextAt);
  }
}
