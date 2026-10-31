/// Duration rounding and formatting helpers.
///
/// Rounding is a *view* only — the exact per-session seconds are always stored.
/// Totals are rounded to the nearest half-hour (sum-then-round, see spec D4).

const int _halfHourSeconds = 1800;

/// Rounds [totalSeconds] to the nearest 1800s (half hour). Ties (900, 2700, …)
/// round **up** — Dart's `double.round()` rounds half away from zero, and the
/// input is clamped to ≥ 0, so halves always go up. Non-positive input → 0.
int roundToHalfHourSeconds(int totalSeconds) {
  if (totalSeconds <= 0) return 0;
  return (totalSeconds / _halfHourSeconds).round() * _halfHourSeconds;
}

/// `H:MM:SS` for the live timer, e.g. 8073 → `2:14:33`. Non-positive → `0:00:00`.
String formatHms(int seconds) {
  if (seconds <= 0) return '0:00:00';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// `H:MM` for totals, e.g. 34200 → `9:30`. Non-positive → `0:00`.
String formatHoursMinutes(int seconds) {
  if (seconds <= 0) return '0:00';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}
