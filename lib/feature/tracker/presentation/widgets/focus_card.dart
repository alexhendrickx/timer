import 'package:flutter/material.dart';

import '../../../../core/services/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_utils.dart';

/// The activity's share of all tracked time today, clamped to `0.0..1.0`.
/// `totalTodaySeconds == 0` returns `0.0` (no divide-by-zero).
double ringFraction(int activitySeconds, int totalTodaySeconds) {
  if (totalTodaySeconds <= 0) return 0.0;
  final fraction = activitySeconds / totalTodaySeconds;
  return fraction.clamp(0.0, 1.0);
}

/// A Home grid tile: activity name + color, a progress ring showing its
/// share of today's tracked time, and today's total. One tap starts it.
class FocusCard extends StatelessWidget {
  const FocusCard({
    super.key,
    required this.activity,
    required this.todaySeconds,
    required this.fraction,
    required this.onTap,
  });

  final Activity activity;
  final int todaySeconds;
  final double fraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ringColor =
        activity.color != null ? Color(activity.color!) : AppColors.accent;
    return Card(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                activity.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Center(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 5,
                    backgroundColor: AppColors.hairline,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                ),
              ),
              Text(
                formatHoursMinutes(todaySeconds),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
