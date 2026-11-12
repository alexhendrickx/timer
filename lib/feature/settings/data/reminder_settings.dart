import 'package:shared_preferences/shared_preferences.dart';

/// The user's break-reminder interval, persisted via `shared_preferences`.
/// Defaults to 90 minutes; [ReminderScheduler] re-arms from it on change.
class ReminderSettings {
  ReminderSettings({Duration interval = const Duration(minutes: 90)})
      : _interval = interval;

  static const _key = 'reminder_interval_minutes';

  Duration _interval;

  Duration get interval => _interval;
  set interval(Duration value) => _interval = value;

  /// Loads the persisted interval, falling back to the current value when
  /// nothing has been saved yet.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_key);
    if (minutes != null) {
      _interval = Duration(minutes: minutes);
    }
  }

  /// Persists the current interval.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _interval.inMinutes);
  }
}
