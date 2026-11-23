import 'package:shared_preferences/shared_preferences.dart';

/// The view-only rounding step (spec D4) used by totals, reports, and
/// exports, persisted via `shared_preferences`. Defaults to 900s (15 min).
/// Changing it never touches a stored session's `durationSeconds` — it only
/// changes how sums are rounded when displayed.
class RoundingSettings {
  RoundingSettings({this.stepSeconds = 900});

  static const _key = 'rounding_step_seconds';

  int stepSeconds;

  /// Loads the persisted step, falling back to the current value when
  /// nothing has been saved yet.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_key);
    if (seconds != null) {
      stepSeconds = seconds;
    }
  }

  /// Persists the current step.
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, stepSeconds);
  }
}
