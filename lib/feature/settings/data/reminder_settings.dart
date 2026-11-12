import 'package:shared_preferences/shared_preferences.dart';

/// The user's break-reminder interval, persisted via `shared_preferences`.
/// Defaults to 90 minutes; [ReminderScheduler] re-arms from it on change.
class ReminderSettings {
  ReminderSettings({this.interval = const Duration(minutes: 90)});

  static const _key = 'reminder_interval_minutes';

  Duration interval;

  /// Loads the persisted interval, falling back to the current value when
  /// nothing has been saved yet.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_key);
    if (minutes != null) {
      interval = Duration(minutes: minutes);
    }
  }

  /// Persists the current interval.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, interval.inMinutes);
  }
}
