import 'package:flutter_test/flutter_test.dart';
import 'package:timer/feature/export/service/csv_builder.dart';

SessionRow rowWithNote(String note) {
  return SessionRow(
    activityName: 'Client X',
    date: DateTime(2026, 11, 1),
    start: DateTime(2026, 11, 1, 9, 0),
    end: DateTime(2026, 11, 1, 10, 0),
    durationSeconds: 3600,
    note: note,
  );
}

void main() {
  test('quotes a note containing a comma and a quote', () {
    expect(buildCsv([rowWithNote('a, "b"')]), contains('"a, ""b"""'));
  });

  test('empty rows yields just the header line', () {
    expect(buildCsv([]).trim(), 'activity,date,start,end,duration,note');
  });

  test('carries the exact per-session duration, not rounded', () {
    final csv = buildCsv([
      SessionRow(
        activityName: 'Client X',
        date: DateTime(2026, 11, 1),
        start: DateTime(2026, 11, 1, 9, 0),
        end: DateTime(2026, 11, 1, 9, 22),
        durationSeconds: 22 * 60,
        note: null,
      ),
    ]);
    expect(csv, contains('0:22:00'));
  });

  test('a null note yields an empty field, not the string "null"', () {
    final row = SessionRow(
      activityName: 'Client X',
      date: DateTime(2026, 11, 1),
      start: DateTime(2026, 11, 1, 9, 0),
      end: DateTime(2026, 11, 1, 10, 0),
      durationSeconds: 3600,
      note: null,
    );
    expect(buildCsv([row]), isNot(contains('null')));
  });
}
