import 'package:flutter/material.dart' show DateTimeRange;

import '../../../core/services/database/app_database.dart';
import '../../history/service/totals_calculator.dart';

/// One activity's sessions and total within a [Report].
class ReportGroup {
  const ReportGroup({
    required this.activity,
    required this.sessions,
    required this.total,
  });

  final Activity activity;
  final List<Session> sessions;
  final ActivityTotal total;
}

/// The data an export (HTML/PDF) renders: grouped by activity, with a
/// grand total already summed from each group's rounded total — never
/// recomputed by rounding the grand sum itself (sum-then-round happens once,
/// per group; the grand total sums those already-rounded figures).
class Report {
  const Report({
    this.range,
    required this.groups,
    required this.grandRoundedSeconds,
    this.grandAmount,
  });

  final DateTimeRange? range;
  final List<ReportGroup> groups;
  final int grandRoundedSeconds;
  final double? grandAmount;
}
