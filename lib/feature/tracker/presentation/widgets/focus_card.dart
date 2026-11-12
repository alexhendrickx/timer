/// The activity's share of all tracked time today, clamped to `0.0..1.0`.
/// `totalTodaySeconds == 0` returns `0.0` (no divide-by-zero).
double ringFraction(int activitySeconds, int totalTodaySeconds) {
  if (totalTodaySeconds <= 0) return 0.0;
  final fraction = activitySeconds / totalTodaySeconds;
  return fraction.clamp(0.0, 1.0);
}
