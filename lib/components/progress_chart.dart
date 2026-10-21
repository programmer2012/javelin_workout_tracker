import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/progression.dart';

/// Plots a measurement over time — body weight, or one exercise's
/// progression across workouts.
///
/// The x axis is days since the first point rather than the point's position
/// in the list, so a month without training shows up as a gap in the line
/// instead of being drawn as one even step.
class ProgressChart extends StatelessWidget {
  final List<ChartPoint> points;

  /// Appended to axis labels' tooltips, e.g. `kg` or `reps`.
  final String unit;

  /// Shown when there is nothing to plot yet.
  final String emptyMessage;

  const ProgressChart({
    required this.points,
    this.unit = 'kg',
    this.emptyMessage = 'Nothing logged yet.',
    super.key,
  });

  static const _lineColor = Colors.deepPurple;
  static const _labelStyle = TextStyle(fontSize: 11, color: Colors.black54);

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final origin = points.first.date;
    final spots = [
      for (final point in points)
        FlSpot(_daysBetween(origin, point.date), point.value),
    ];

    final span = spots.last.x - spots.first.x;
    // A single point, or several from the same day, would collapse the axis
    // to zero width; give it room so the point stays visible.
    final minX = span <= 0 ? -0.5 : spots.first.x;
    final maxX = span <= 0 ? 0.5 : spots.last.x;

    // Without the year, a history running from October 2025 to October 2026
    // labels both ends "x.10." and reads as a few weeks rather than a year.
    final spansMultipleYears = points.first.date.year != points.last.date.year;

    final values = points.map((p) => p.value);
    final lowest = values.reduce(math.min);
    final highest = values.reduce(math.max);
    // Pad the range so a steady value is not drawn as a line glued to the
    // top of the chart.
    final padding = math.max(1.0, (highest - lowest) * 0.15);
    final minY = math.max(0.0, lowest - padding);
    final maxY = highest + padding;
    final interval = _niceInterval(maxY - minY);

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.grey.shade300,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(formatValue(value), style: _labelStyle),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              // Two or three labels is all that fits legibly on a phone.
              interval: span <= 0 ? 1 : math.max(span / 2, 0.001),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                axisSide: meta.axisSide,
                child: Text(
                  _formatDate(
                    _dateAt(origin, value),
                    withYear: spansMultipleYears,
                  ),
                  style: _labelStyle,
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.deepPurple.withOpacity(0.9),
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${formatValue(spot.y)} $unit\n'
                  '${_formatFullDate(_dateAt(origin, spot.x))}',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: _lineColor,
            barWidth: 3,
            isCurved: false,
            // Individual measurements matter here, but past a few dozen the
            // dots turn the line into a smear.
            dotData: FlDotData(show: spots.length <= 30),
            belowBarData: BarAreaData(
              show: true,
              color: _lineColor.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  static double _daysBetween(DateTime origin, DateTime date) =>
      date.difference(origin).inMinutes / Duration.minutesPerDay;

  static DateTime _dateAt(DateTime origin, double days) => origin.add(
        Duration(minutes: (days * Duration.minutesPerDay).round()),
      );

  /// Axis labels stay short (`5.10.`) unless the history crosses a year
  /// boundary, where the year is what distinguishes the two ends.
  static String _formatDate(DateTime date, {bool withYear = false}) {
    final base = '${date.day}.${date.month}.';
    if (!withYear) return base;
    return '$base${(date.year % 100).toString().padLeft(2, '0')}';
  }

  /// Tooltips always carry the full year — there is room, and it removes any
  /// doubt about which measurement is being read.
  static String _formatFullDate(DateTime date) =>
      '${date.day}.${date.month}.${date.year}';

  /// Whole numbers stay whole; anything else gets a single decimal.
  static String formatValue(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  /// Keeps the gridlines and labels on round numbers instead of values like
  /// 3.7333 kg.
  static double _niceInterval(double range) {
    if (range <= 0) return 1;
    for (final candidate in const [
      1.0,
      2.0,
      2.5,
      5.0,
      10.0,
      20.0,
      25.0,
      50.0,
      100.0,
      250.0,
      500.0,
      1000.0,
    ]) {
      if (range / candidate <= 5) return candidate;
    }
    return (range / 5).ceilToDouble();
  }
}
