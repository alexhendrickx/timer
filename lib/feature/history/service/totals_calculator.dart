import '../../../core/services/database/app_database.dart';
import '../../../core/utils/duration_utils.dart';

/// A group's time + (optionally) money for one activity over a period.
/// [exactSeconds] is the unrounded sum; [roundedSeconds] is the view-only
/// sum-then-round total (spec D4); [amount] is `null` when the activity has
/// no `hourlyRate` set — omitted, never shown as 0.
class ActivityTotal {
  const ActivityTotal({
    required this.activityId,
    required this.name,
    required this.exactSeconds,
    required this.roundedSeconds,
    this.amount,
  });

  final int activityId;
  final String name;
  final int exactSeconds;
  final int roundedSeconds;
  final double? amount;
}

/// Sums a group of sessions for one activity and rounds once at the end
/// (sum-then-round, spec D4) — never rounds per-session.
class TotalsCalculator {
  TotalsCalculator._();

  static ActivityTotal forGroup(
    List<Session> sessions,
    Activity activity, {
    int stepSeconds = 900,
  }) {
    final exact = sessions.fold<int>(0, (a, s) => a + s.durationSeconds);
    final rounded = roundToNearest(exact, stepSeconds);
    final rate = activity.hourlyRate;
    return ActivityTotal(
      activityId: activity.id,
      name: activity.name,
      exactSeconds: exact,
      roundedSeconds: rounded,
      amount: rate == null ? null : (rounded / 3600) * rate,
    );
  }
}
