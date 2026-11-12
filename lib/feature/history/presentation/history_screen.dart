import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_utils.dart';
import '../../activities/data/activity_repository.dart';
import '../data/history_repository.dart';
import '../service/history_aggregator.dart';
import 'widgets/month_heatmap.dart';
import 'widgets/session_tile.dart';
import 'widgets/week_bar_chart.dart';

enum _HistoryMode { day, week, month }

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _weekStartOf(DateTime d) =>
    _dayOnly(d).subtract(Duration(days: d.weekday - 1));
DateTime _monthStartOf(DateTime d) => DateTime(d.year, d.month, 1);

/// Top-down history: today's day list → the week it's in → the month it's
/// in. An optional activity filter scopes all three views and feeds Reports.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.initialActivityId});

  /// Pre-selected when drilling in from a Home focus card.
  final int? initialActivityId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryMode _mode = _HistoryMode.day;
  DateTime _focusDate = _dayOnly(DateTime.now());
  late int? _activityId = widget.initialActivityId;
  final _aggregator = HistoryAggregator();

  void _drillTo(_HistoryMode mode, DateTime date) {
    setState(() {
      _mode = mode;
      _focusDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.read<HistoryRepository>();
    final activityRepo = context.read<ActivityRepository>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Text(switch (_mode) {
          _HistoryMode.day => 'Day',
          _HistoryMode.week => 'Week',
          _HistoryMode.month => 'Month',
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Reports',
            onPressed: () => context.push('/reports'),
          ),
        ],
      ),
      body: Column(
        children: [
          _Breadcrumbs(mode: _mode, focusDate: _focusDate, onTap: _drillTo),
          FutureBuilder<List<Activity>>(
            future: activityRepo.activeActivities(),
            builder: (context, snapshot) {
              final activities = snapshot.data ?? const [];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButton<int?>(
                  value: _activityId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All activities')),
                    for (final a in activities)
                      DropdownMenuItem(value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (id) => setState(() => _activityId = id),
                ),
              );
            },
          ),
          Expanded(
            child: switch (_mode) {
              _HistoryMode.day => _DayView(
                  history: history,
                  activityId: _activityId,
                  day: _focusDate,
                ),
              _HistoryMode.week => _WeekView(
                  history: history,
                  aggregator: _aggregator,
                  activityId: _activityId,
                  weekStart: _weekStartOf(_focusDate),
                  onTapDay: (d) => _drillTo(_HistoryMode.day, d),
                ),
              _HistoryMode.month => _MonthView(
                  history: history,
                  aggregator: _aggregator,
                  activityId: _activityId,
                  monthStart: _monthStartOf(_focusDate),
                  onTapDay: (d) => _drillTo(_HistoryMode.day, d),
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _Breadcrumbs extends StatelessWidget {
  const _Breadcrumbs({
    required this.mode,
    required this.focusDate,
    required this.onTap,
  });

  final _HistoryMode mode;
  final DateTime focusDate;
  final void Function(_HistoryMode, DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          TextButton(
            onPressed: () => onTap(_HistoryMode.day, focusDate),
            child: Text(
              '${focusDate.year}-${focusDate.month.toString().padLeft(2, '0')}-${focusDate.day.toString().padLeft(2, '0')}',
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
          TextButton(
            onPressed: () => onTap(_HistoryMode.week, focusDate),
            child: const Text('Week'),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 16),
          TextButton(
            onPressed: () => onTap(_HistoryMode.month, focusDate),
            child: const Text('Month'),
          ),
        ],
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    required this.history,
    required this.activityId,
    required this.day,
  });

  final HistoryRepository history;
  final int? activityId;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Session>>(
      stream: history.watch(
        activityId: activityId,
        range: DateTimeRange(start: day, end: day),
      ),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        final exactTotal = sessions.fold<int>(0, (a, s) => a + s.durationSeconds);
        final roundedTotal = roundToNearest(exactTotal);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Day total', style: Theme.of(context).textTheme.titleMedium),
                  Text(formatHoursMinutes(roundedTotal)),
                ],
              ),
            ),
            if (sessions.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No sessions this day',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) =>
                      SessionTile(session: sessions[i], repo: history),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WeekView extends StatelessWidget {
  const _WeekView({
    required this.history,
    required this.aggregator,
    required this.activityId,
    required this.weekStart,
    required this.onTapDay,
  });

  final HistoryRepository history;
  final HistoryAggregator aggregator;
  final int? activityId;
  final DateTime weekStart;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Session>>(
      stream: history.watch(
        activityId: activityId,
        range: DateTimeRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 6)),
        ),
      ),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        final buckets = aggregator.week(sessions, weekStart);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: WeekBarChart(buckets: buckets, onTapDay: onTapDay),
        );
      },
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.history,
    required this.aggregator,
    required this.activityId,
    required this.monthStart,
    required this.onTapDay,
  });

  final HistoryRepository history;
  final HistoryAggregator aggregator;
  final int? activityId;
  final DateTime monthStart;
  final ValueChanged<DateTime> onTapDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    final monthEnd = DateTime(monthStart.year, monthStart.month, daysInMonth);
    return StreamBuilder<List<Session>>(
      stream: history.watch(
        activityId: activityId,
        range: DateTimeRange(start: monthStart, end: monthEnd),
      ),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const [];
        final buckets = aggregator.month(sessions, monthStart);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: MonthHeatmap(
            buckets: buckets,
            monthStart: monthStart,
            onTapDay: onTapDay,
          ),
        );
      },
    );
  }
}
