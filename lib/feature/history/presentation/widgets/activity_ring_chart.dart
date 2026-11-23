import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../service/totals_calculator.dart';

/// Fixed categorical order for activities with no custom swatch — the same
/// palette offered in the activity editor (dataviz: assign hue by identity,
/// in fixed order, never cycled/re-ranked when the filtered set changes).
const List<int> _fallbackPalette = [
  0xFF4FB8A8, // accent teal
  0xFFE0A458, // amber
  0xFFC45B6E, // rose
  0xFF6E8FC4, // blue
  0xFF8FB36E, // green
  0xFFB08FC4, // violet
];

Color colorForActivity(int activityId, int? customColor, int indexInList) {
  if (customColor != null) return Color(customColor);
  return Color(_fallbackPalette[indexInList % _fallbackPalette.length]);
}

/// Each activity's share of the period total as a ring (dataviz: identity →
/// categorical color, a 2px surface gap between segments, a legend is
/// always shown beside the chart — see [ReportsScreen] — so color is never
/// the only way to read which slice is which). Zero-safe: an all-zero period
/// renders an empty ring rather than dividing by zero.
class ActivityRingChart extends StatelessWidget {
  const ActivityRingChart({
    super.key,
    required this.totals,
    required this.colors,
  });

  final List<ActivityTotal> totals;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _RingPainter(totals: totals, colors: colors),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.totals, required this.colors});

  final List<ActivityTotal> totals;
  final List<Color> colors;

  static const double _strokeWidth = 22;
  static const double _gapRadians = 0.02; // 2px-equivalent surface gap

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _strokeWidth / 2,
      _strokeWidth / 2,
      size.width - _strokeWidth,
      size.height - _strokeWidth,
    );
    final grandTotal = totals.fold<int>(0, (a, t) => a + t.roundedSeconds);

    if (grandTotal <= 0) {
      final paint = Paint()
        ..color = AppColors.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth;
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
      return;
    }

    double start = -math.pi / 2;
    for (var i = 0; i < totals.length; i++) {
      final sweep = (totals[i].roundedSeconds / grandTotal) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.butt;
      final drawSweep = (sweep - _gapRadians).clamp(0.0, sweep);
      canvas.drawArc(rect, start + _gapRadians / 2, drawSweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.totals != totals || oldDelegate.colors != colors;
}
