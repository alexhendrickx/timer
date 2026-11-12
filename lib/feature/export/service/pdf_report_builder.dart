import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/duration_utils.dart';
import 'report_model.dart';

String _two(int n) => n.toString().padLeft(2, '0');
String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
String _amount(double amount, String? currency) {
  final value = amount.toStringAsFixed(2);
  return currency == null || currency.isEmpty ? value : '$value $currency';
}

/// Same content as [buildHtml], laid out as a PDF via the `pdf` package:
/// grouped sections with exact session rows, a rounded subtotal (and
/// amount) per activity, and a grand-total footer.
Future<Uint8List> buildPdf(Report report) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        for (final group in report.groups) ...[
          pw.Header(text: group.activity.name),
          pw.TableHelper.fromTextArray(
            headers: const ['Date', 'Start', 'End', 'Duration', 'Note'],
            data: [
              for (final session in group.sessions)
                [
                  session.date.toString().split(' ').first,
                  _time(session.startTime),
                  session.endTime == null ? '' : _time(session.endTime!),
                  formatHms(session.durationSeconds),
                  session.note ?? '',
                ],
            ],
          ),
          pw.Text(
            'Subtotal: ${formatHoursMinutes(group.total.roundedSeconds)}'
            '${group.total.amount == null ? '' : '  ${_amount(group.total.amount!, group.activity.currencyLabel)}'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
        ],
        pw.Divider(),
        pw.Text(
          'Grand total: ${formatHoursMinutes(report.grandRoundedSeconds)}'
          '${report.grandAmount == null ? '' : '  ${report.grandAmount!.toStringAsFixed(2)}'}',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  return doc.save();
}
