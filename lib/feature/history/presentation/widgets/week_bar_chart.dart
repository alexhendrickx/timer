import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/duration_utils.dart';
import '../../service/history_aggregator.dart';

const List<String> _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// One bar per day of the selected week (dataviz: single series → one hue,
/// no legend needed; thin bar, rounded top, recessive baseline; a direct
/// value label above each bar since 7 marks is small enough to label all).
/// Zero-safe: an all-zero week renders flat bars at the baseline, never
/// crashes on divide-by-zero.
class WeekBarChart extends StatelessWidget {
  const WeekBarChart({super.key, required this.buckets, this.onTapDay});

  final List<DayBucket> buckets;
  final ValueChanged<DateTime>? onTapDay;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = buckets.fold<int>(
      0,
      (m, b) => b.exactSeconds > m ? b.exactSeconds : m,
    );
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in buckets)
            Expanded(
              child: GestureDetector(
                onTap: onTapDay == null ? null : () => onTapDay!(b.date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        b.exactSeconds > 0 ? formatHoursMinutes(b.exactSeconds) : '',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      _Bar(fraction: maxSeconds == 0 ? 0 : b.exactSeconds / maxSeconds),
                      const SizedBox(height: 6),
                      Container(height: 1, color: AppColors.hairline),
                      const SizedBox(height: 4),
                      Text(
                        _weekdayLabels[b.date.weekday - 1],
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    const maxHeight = 100.0;
    final height = (fraction.clamp(0.0, 1.0) * maxHeight).clamp(2.0, maxHeight);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}
