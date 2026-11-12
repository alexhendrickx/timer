import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/services/database/app_database.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/duration_utils.dart';
import '../../activities/data/activity_repository.dart';
import '../../settings/data/rounding_settings.dart';
import '../data/history_repository.dart';
import '../service/totals_calculator.dart';
import 'widgets/activity_ring_chart.dart';

enum _Period { week, month, all }

DateTimeRange? _rangeFor(_Period period) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case _Period.week:
      final start = today.subtract(Duration(days: today.weekday - 1));
      return DateTimeRange(start: start, end: start.add(const Duration(days: 6)));
    case _Period.month:
      final start = DateTime(today.year, today.month, 1);
      final end = DateTime(today.year, today.month + 1, 0);
      return DateTimeRange(start: start, end: end);
    case _Period.all:
      return null;
  }
}

/// Per-activity totals for the selected period: a ring/pie by share of time,
/// with the exact figures, rounded totals, and amounts (rated activities
/// only) listed beside it, plus a grand total — the visual and the precise
/// numbers together (spec: Reports).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Period _period = _Period.month;
  int? _activityId;

  // Futures are held in state (not rebuilt inline) so an unrelated rebuild
  // never re-runs the grouped query or reloads the activity list; they are
  // refreshed only when the period or activity filter actually changes.
  late Future<List<Activity>> _activitiesFuture;
  late Future<List<ActivityTotal>> _totalsFuture;

  @override
  void initState() {
    super.initState();
    final history = context.read<HistoryRepository>();
    final activityRepo = context.read<ActivityRepository>();
    _activitiesFuture = activityRepo.activeActivities();
    _totalsFuture = history.totals(
      range: _rangeFor(_period),
      activityId: _activityId,
      stepSeconds: context.read<RoundingSettings>().stepSeconds,
    );
  }

  void _refreshTotals() {
    final history = context.read<HistoryRepository>();
    setState(() {
      _totalsFuture = history.totals(
        range: _rangeFor(_period),
        activityId: _activityId,
        stepSeconds: context.read<RoundingSettings>().stepSeconds,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Reports'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.week, label: Text('Week')),
                ButtonSegment(value: _Period.month, label: Text('Month')),
                ButtonSegment(value: _Period.all, label: Text('All time')),
              ],
              selected: {_period},
              onSelectionChanged: (s) {
                _period = s.first;
                _refreshTotals();
              },
            ),
          ),
          FutureBuilder<List<Activity>>(
            future: _activitiesFuture,
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
                  onChanged: (id) {
                    _activityId = id;
                    _refreshTotals();
                  },
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<List<Activity>>(
              future: _activitiesFuture,
              builder: (context, activitySnapshot) {
                final activities = activitySnapshot.data ?? const [];
                final activityById = {for (final a in activities) a.id: a};
                return FutureBuilder<List<ActivityTotal>>(
                  future: _totalsFuture,
                  builder: (context, snapshot) {
                    final totals = snapshot.data ?? const [];
                    if (totals.isEmpty) {
                      return Center(
                        child: Text(
                          'No sessions in this period',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      );
                    }
                    final colors = [
                      for (var i = 0; i < totals.length; i++)
                        colorForActivity(
                          totals[i].activityId,
                          activityById[totals[i].activityId]?.color,
                          i,
                        ),
                    ];
                    final grandSeconds =
                        totals.fold<int>(0, (a, t) => a + t.roundedSeconds);
                    final grandAmount = totals
                        .where((t) => t.amount != null)
                        .fold<double>(0, (a, t) => a + t.amount!);
                    final hasAnyAmount = totals.any((t) => t.amount != null);
                    // Show a currency unit on the grand total only when every
                    // rated activity shares one label (mixed currencies can't
                    // be summed into a single symbol).
                    final ratedCurrencies = {
                      for (final t in totals.where((t) => t.amount != null))
                        activityById[t.activityId]?.currencyLabel,
                    };
                    final grandCurrency = ratedCurrencies.length == 1
                        ? ratedCurrencies.first
                        : null;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Center(child: ActivityRingChart(totals: totals, colors: colors)),
                          const SizedBox(height: 24),
                          for (var i = 0; i < totals.length; i++)
                            _TotalRow(
                              total: totals[i],
                              color: colors[i],
                              currency:
                                  activityById[totals[i].activityId]?.currencyLabel,
                            ),
                          const Divider(height: 24),
                          _GrandTotalRow(
                            seconds: grandSeconds,
                            amount: hasAnyAmount ? grandAmount : null,
                            currency: grandCurrency,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats an amount with its currency label when one is set, e.g.
/// `75.00 EUR`; bare `75.00` when the activity has no label.
String _formatAmount(double amount, String? currency) {
  final value = amount.toStringAsFixed(2);
  return currency == null || currency.isEmpty ? value : '$value $currency';
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total, required this.color, this.currency});

  final ActivityTotal total;
  final Color color;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(total.name)),
          Text(
            '${formatHms(total.exactSeconds)} exact',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Text(formatHoursMinutes(total.roundedSeconds)),
          if (total.amount != null) ...[
            const SizedBox(width: 12),
            Text(_formatAmount(total.amount!, currency)),
          ],
        ],
      ),
    );
  }
}

class _GrandTotalRow extends StatelessWidget {
  const _GrandTotalRow({required this.seconds, this.amount, this.currency});

  final int seconds;
  final double? amount;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Grand total', style: Theme.of(context).textTheme.titleMedium),
        Row(
          children: [
            Text(formatHoursMinutes(seconds),
                style: Theme.of(context).textTheme.titleMedium),
            if (amount != null) ...[
              const SizedBox(width: 12),
              Text(_formatAmount(amount!, currency),
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ],
        ),
      ],
    );
  }
}
