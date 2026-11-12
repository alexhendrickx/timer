import 'package:flutter_test/flutter_test.dart';
import 'package:timer/core/services/database/app_database.dart';
import 'package:timer/feature/export/service/html_report_builder.dart';
import 'package:timer/feature/export/service/pdf_report_builder.dart';
import 'package:timer/feature/export/service/report_model.dart';
import 'package:timer/feature/history/service/totals_calculator.dart';

Activity _activity({required int id, String name = 'Client X', double? hourlyRate}) {
  return Activity(
    id: id,
    name: name,
    hourlyRate: hourlyRate,
    archived: false,
    createdAt: DateTime(2026, 1, 1),
  );
}

Session _session(int id, int activityId, DateTime start, int durationSeconds) {
  return Session(
    id: id,
    activityId: activityId,
    date: DateTime(start.year, start.month, start.day),
    startTime: start,
    endTime: start.add(Duration(seconds: durationSeconds)),
    durationSeconds: durationSeconds,
    createdAt: start,
    updatedAt: start,
  );
}

// 9h22m exact, rounds to 9:30 at the 15-min step; rate 75 -> 9.5 * 75 = 712.50.
final _ratedActivity = _activity(id: 1, hourlyRate: 75);
final reportNineH22mRate75 = Report(
  range: null,
  groups: [
    ReportGroup(
      activity: _ratedActivity,
      sessions: [_session(1, 1, DateTime(2026, 11, 1, 9, 0), 9 * 3600 + 22 * 60)],
      total: TotalsCalculator.forGroup(
        [_session(1, 1, DateTime(2026, 11, 1, 9, 0), 9 * 3600 + 22 * 60)],
        _ratedActivity,
      ),
    ),
  ],
  grandRoundedSeconds: 34200,
  grandAmount: 712.50,
);

final _unratedActivity = _activity(id: 2, name: 'Personal');
final reportNoRate = Report(
  range: null,
  groups: [
    ReportGroup(
      activity: _unratedActivity,
      sessions: [_session(2, 2, DateTime(2026, 11, 1, 9, 0), 3600)],
      total: TotalsCalculator.forGroup(
        [_session(2, 2, DateTime(2026, 11, 1, 9, 0), 3600)],
        _unratedActivity,
      ),
    ),
  ],
  grandRoundedSeconds: 3600,
  grandAmount: null,
);

void main() {
  test('html subtotal uses rounded hours, not exact', () {
    final html = buildHtml(reportNineH22mRate75);
    expect(html, contains('9:30')); // rounded
    expect(html, contains('712.50')); // 9.5 * 75
  });

  test('activity without rate omits the amount cell', () {
    expect(buildHtml(reportNoRate), isNot(contains('€')));
  });

  test('buildPdf returns non-empty bytes', () async {
    expect((await buildPdf(reportNineH22mRate75)).isNotEmpty, isTrue);
  });
}
