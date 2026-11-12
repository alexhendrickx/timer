import '../../../core/utils/duration_utils.dart';
import 'report_model.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _two(int n) => n.toString().padLeft(2, '0');
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _amount(double amount, String? currency) {
  final value = amount.toStringAsFixed(2);
  return currency == null || currency.isEmpty ? value : '$value $currency';
}

/// A self-contained, print-friendly HTML report: grouped sections with
/// exact per-session rows, a rounded subtotal (and amount) per activity,
/// and a grand-total footer. Rounding appears only on subtotal/grand rows —
/// session rows always show the exact duration.
String buildHtml(Report report) {
  final sections = StringBuffer();
  for (final group in report.groups) {
    sections.writeln('<section>');
    sections.writeln('<h2>${_esc(group.activity.name)}</h2>');
    sections.writeln('<table>');
    sections.writeln(
        '<tr><th>Date</th><th>Start</th><th>End</th><th>Duration</th><th>Note</th></tr>');
    for (final session in group.sessions) {
      sections.writeln('<tr>'
          '<td>${_esc(session.date.toString().split(' ').first)}</td>'
          '<td>${_time(session.startTime)}</td>'
          '<td>${session.endTime == null ? '' : _time(session.endTime!)}</td>'
          '<td>${formatHms(session.durationSeconds)}</td>'
          '<td>${_esc(session.note ?? '')}</td>'
          '</tr>');
    }
    sections.writeln('</table>');
    final total = group.total;
    final amountHtml = total.amount == null
        ? ''
        : '<span class="amount">${_amount(total.amount!, group.activity.currencyLabel)}</span>';
    sections.writeln(
        '<p class="subtotal">Subtotal: ${formatHoursMinutes(total.roundedSeconds)}$amountHtml</p>');
    sections.writeln('</section>');
  }

  final grandAmountHtml = report.grandAmount == null
      ? ''
      : '<span class="amount">${report.grandAmount!.toStringAsFixed(2)}</span>';

  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Time report</title>
<style>
  body { font-family: -apple-system, sans-serif; color: #111; margin: 24px; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
  th, td { text-align: left; padding: 4px 8px; border-bottom: 1px solid #ddd; }
  .subtotal { font-weight: 600; }
  .amount { margin-left: 12px; }
  .grand-total { font-size: 1.2em; font-weight: 700; margin-top: 24px; }
  @media print { body { margin: 0; } }
</style>
</head>
<body>
$sections
<p class="grand-total">Grand total: ${formatHoursMinutes(report.grandRoundedSeconds)}$grandAmountHtml</p>
</body>
</html>
''';
}
