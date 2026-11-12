import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_utils.dart';
import '../../service/history_aggregator.dart';

/// A calendar grid shaded by each day's tracked time (dataviz: sequential —
/// one hue, light→dark — from [AppColors.hairline] (no time) up to
/// [AppColors.accent] (the busiest day in the month). The 5-step scale is
/// shown as a small legend below the grid so the shading is never read by
/// color alone. Zero-safe: an all-zero month renders every cell at the
/// lightest step.
class MonthHeatmap extends StatelessWidget {
  const MonthHeatmap({
    super.key,
    required this.buckets,
    required this.monthStart,
    this.onTapDay,
  });

  final List<DayBucket> buckets;
  final DateTime monthStart;
  final ValueChanged<DateTime>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = buckets.fold<int>(
      0,
      (m, b) => b.exactSeconds > m ? b.exactSeconds : m,
    );
    // Monday-first grid: pad leading cells so day 1 lands under its weekday.
    final leadingBlanks = monthStart.weekday - 1;
    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox(),
      for (final b in buckets)
        _DayCell(
          bucket: b,
          fraction: maxSeconds == 0 ? 0 : b.exactSeconds / maxSeconds,
          onTap: onTapDay == null ? null : () => onTapDay!(b.date),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: cells,
        ),
        const SizedBox(height: 12),
        _Legend(maxSeconds: maxSeconds),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.bucket,
    required this.fraction,
    this.onTap,
  });

  final DayBucket bucket;
  final double fraction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: '${bucket.date.day}: ${formatHoursMinutes(bucket.exactSeconds)}',
        child: Container(
          decoration: BoxDecoration(
            color: _shade(fraction),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            '${bucket.date.day}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fraction > 0.5
                      ? AppColors.background
                      : AppColors.textSecondary,
                ),
          ),
        ),
      ),
    );
  }
}

/// [AppColors.hairline] (no time) → [AppColors.accent] (busiest day).
Color _shade(double fraction) {
  return Color.lerp(AppColors.hairline, AppColors.accent, fraction.clamp(0.0, 1.0))!;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.maxSeconds});

  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    const steps = 5;
    return Row(
      children: [
        Text(
          'Less',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i <= steps; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _shade(i / steps),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          maxSeconds > 0 ? 'More (${formatHoursMinutes(maxSeconds)})' : 'More',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
