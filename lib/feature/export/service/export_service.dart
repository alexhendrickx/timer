import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/database/app_database.dart';
import '../../activities/data/activity_repository.dart';
import '../../history/data/history_repository.dart';
import '../../settings/data/rounding_settings.dart';
import 'csv_builder.dart';
import 'html_report_builder.dart';
import 'pdf_report_builder.dart';
import 'report_model.dart';

enum ExportFormat { csv, html, pdf }

enum ExportScope { combined, perActivity }

/// Gathers the active History filter's sessions/totals from
/// [HistoryRepository] and [ActivityRepository], builds the requested
/// export files (combined or one-per-activity, D6) at the current
/// [RoundingSettings] step, and hands them to the system share sheet.
/// Fully local — files are written to a temp dir and never leave the
/// device except via the OS share sheet the user drives.
class ExportService {
  ExportService({
    required this.history,
    required this.activities,
    required this.rounding,
    Future<Directory> Function()? tempDirProvider,
  }) : _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final HistoryRepository history;
  final ActivityRepository activities;
  final RoundingSettings rounding;
  final Future<Directory> Function() _tempDirProvider;

  final Set<String> _usedFileNames = {};

  /// Lowercases [activityName], collapses any run of non `[a-z0-9]`
  /// characters to a single `_`, and de-duplicates a repeat result with a
  /// numeric suffix — safe for use as a filename on both platforms.
  String safeFileName(String activityName) {
    final base =
        activityName.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (_usedFileNames.add(base)) return base;
    var n = 2;
    while (!_usedFileNames.add('${base}_$n')) {
      n++;
    }
    return '${base}_$n';
  }

  /// Builds the requested export [formats] for the given filter ([range],
  /// [activityId]), either as one combined file set or one set per activity
  /// (D6), and returns them ready to [share]. Writes into a temp dir.
  Future<List<XFile>> buildFiles({
    required Set<ExportFormat> formats,
    required ExportScope scope,
    DateTimeRange? range,
    int? activityId,
  }) async {
    final sessions = await history.watch(activityId: activityId, range: range).first;
    final totals = await history.totals(
      range: range,
      activityId: activityId,
      stepSeconds: rounding.stepSeconds,
    );
    final activityList = await activities.activeActivities();
    final activityById = {for (final a in activityList) a.id: a};

    final byActivity = <int, List<Session>>{};
    for (final s in sessions) {
      byActivity.putIfAbsent(s.activityId, () => []).add(s);
    }

    final dir = await _tempDirProvider();

    if (scope == ExportScope.combined) {
      final groups = [
        for (final t in totals)
          if (activityById[t.activityId] != null)
            ReportGroup(
              activity: activityById[t.activityId]!,
              sessions: byActivity[t.activityId] ?? const [],
              total: t,
            ),
      ];
      final report = Report(
        range: range,
        groups: groups,
        grandRoundedSeconds: totals.fold<int>(0, (a, t) => a + t.roundedSeconds),
        grandAmount: totals.any((t) => t.amount != null)
            ? totals.where((t) => t.amount != null).fold<double>(0, (a, t) => a + t.amount!)
            : null,
      );
      return _writeFiles('time-report', report, formats, dir);
    }

    final result = <XFile>[];
    for (final t in totals) {
      final activity = activityById[t.activityId];
      if (activity == null) continue;
      final report = Report(
        range: range,
        groups: [
          ReportGroup(
            activity: activity,
            sessions: byActivity[t.activityId] ?? const [],
            total: t,
          ),
        ],
        grandRoundedSeconds: t.roundedSeconds,
        grandAmount: t.amount,
      );
      result.addAll(
        await _writeFiles(safeFileName(activity.name), report, formats, dir),
      );
    }
    return result;
  }

  Future<List<XFile>> _writeFiles(
    String baseName,
    Report report,
    Set<ExportFormat> formats,
    Directory dir,
  ) async {
    final sessionRows = [
      for (final group in report.groups)
        for (final session in group.sessions)
          SessionRow(
            activityName: group.activity.name,
            date: session.date,
            start: session.startTime,
            end: session.endTime ?? session.startTime,
            durationSeconds: session.durationSeconds,
            note: session.note,
          ),
    ];

    final files = <XFile>[];
    if (formats.contains(ExportFormat.csv)) {
      final file = File(p.join(dir.path, '$baseName.csv'));
      await file.writeAsString(buildCsv(sessionRows));
      files.add(XFile(file.path));
    }
    if (formats.contains(ExportFormat.html)) {
      final file = File(p.join(dir.path, '$baseName.html'));
      await file.writeAsString(buildHtml(report));
      files.add(XFile(file.path));
    }
    if (formats.contains(ExportFormat.pdf)) {
      final file = File(p.join(dir.path, '$baseName.pdf'));
      await file.writeAsBytes(await buildPdf(report));
      files.add(XFile(file.path));
    }
    return files;
  }

  /// Hands [files] to the system share sheet (iOS + macOS).
  Future<void> share(List<XFile> files) async {
    await SharePlus.instance.share(ShareParams(files: files));
  }
}
