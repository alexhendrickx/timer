import '../../../core/utils/duration_utils.dart';

/// One exported session row — carries the exact per-session duration
/// (never rounded; spec: rounding is a view-only total, never a per-session
/// figure in the CSV export).
class SessionRow {
  const SessionRow({
    required this.activityName,
    required this.date,
    required this.start,
    required this.end,
    required this.durationSeconds,
    this.note,
  });

  final String activityName;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final int durationSeconds;
  final String? note;
}

const _header = 'activity,date,start,end,duration,note';

String _two(int n) => n.toString().padLeft(2, '0');
String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// RFC 4180 quoting: wrap the field in quotes (doubling any embedded quote)
/// whenever it contains a comma, a quote, or a newline.
String _escape(String field) {
  if (field.contains(',') || field.contains('"') || field.contains('\n')) {
    return '"${field.replaceAll('"', '""')}"';
  }
  return field;
}

/// Builds a CSV of [rows], one line per session, exact durations. Empty
/// input yields just the header line — a valid, well-formed empty file.
String buildCsv(List<SessionRow> rows) {
  final lines = [_header];
  for (final row in rows) {
    lines.add([
      _escape(row.activityName),
      _date(row.date),
      _time(row.start),
      _time(row.end),
      formatHms(row.durationSeconds),
      _escape(row.note ?? ''),
    ].join(','));
  }
  return '${lines.join('\n')}\n';
}
