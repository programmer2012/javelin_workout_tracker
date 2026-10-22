import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/progress_chart.dart';
import 'package:javelin_workout_tracker/models/progression.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/services/workout_repository.dart';

/// Progression over time for body weight or any exercise in the history.
class ProgressPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<Workout> workouts;

  const ProgressPage({
    required this.userData,
    required this.workouts,
    super.key,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final WorkoutRepository _repository = WorkoutRepository();

  /// `null` means body weight; otherwise the exercise name being plotted.
  String? _exercise;
  ExerciseMetric _metric = ExerciseMetric.heaviestWeight;
  ChartRange _range = ChartRange.all;

  @override
  Widget build(BuildContext context) {
    final names = exerciseNamesIn(widget.workouts);

    // The chosen exercise can vanish — the last workout containing it gets
    // deleted, say. Fall back to body weight rather than charting nothing.
    final selected = (_exercise != null && names.contains(_exercise))
        ? _exercise
        : null;

    final allPoints = selected == null
        ? weightPoints(_repository.weightHistoryFrom(widget.userData))
        : progressionFor(widget.workouts, selected, _metric);

    final points = pointsInRange(allPoints, _range);
    final unit = selected == null ? 'kg' : _metric.unit;

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Progress',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPickers(names, selected),
                    const SizedBox(height: 8),
                    _buildRangePicker(allPoints),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 260,
                      child: ProgressChart(
                        points: points,
                        unit: unit,
                        emptyMessage: _emptyMessage(
                          selected,
                          names,
                          hasOlderData: allPoints.isNotEmpty,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (points.isNotEmpty) _buildSummary(points, unit),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickers(List<String> names, String? selected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Show',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String?>(
                value: selected,
                isExpanded: true,
                isDense: true,
                onChanged: (value) => setState(() => _exercise = value),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Body Weight'),
                  ),
                  for (final name in names)
                    DropdownMenuItem<String?>(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
            ),
          ],
        ),
        // Body weight has only one sensible metric, so the second picker
        // only appears once an exercise is being plotted.
        if (selected != null)
          Row(
            children: [
              const Text('as', style: TextStyle(fontSize: 15)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<ExerciseMetric>(
                  value: _metric,
                  isExpanded: true,
                  isDense: true,
                  onChanged: (value) {
                    if (value != null) setState(() => _metric = value);
                  },
                  items: [
                    for (final metric in ExerciseMetric.values)
                      DropdownMenuItem(
                        value: metric,
                        child: Text(metric.label),
                      ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRangePicker(List<ChartPoint> allPoints) {
    return Wrap(
      spacing: 6,
      children: [
        for (final range in ChartRange.values)
          ChoiceChip(
            label: Text(range.label),
            labelStyle: const TextStyle(fontSize: 12),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected: _range == range,
            onSelected: (_) => setState(() => _range = range),
          ),
      ],
    );
  }

  String _emptyMessage(
    String? selected,
    List<String> names, {
    bool hasOlderData = false,
  }) {
    // Distinguish "nothing logged" from "nothing in this window", otherwise
    // narrowing the range looks like the data was lost.
    if (hasOlderData) {
      return 'Nothing in the last ${_range.label}. '
          'Pick a longer range to see earlier entries.';
    }

    if (selected != null) {
      return 'No ${_metric.label.toLowerCase()} recorded for $selected yet.';
    }
    if (names.isEmpty) {
      return 'No weight logged yet. Add an entry on the home tab, and '
          'finished workouts will show up here as exercises to pick from.';
    }
    return 'No weight logged yet. Add an entry on the home tab and it will '
        'appear here.';
  }

  Widget _buildSummary(List<ChartPoint> points, String unit) {
    final first = points.first;
    final latest = points.last;
    final change = latest.value - first.value;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Current',
            value: '${ProgressChart.formatValue(latest.value)} $unit',
          ),
          _SummaryRow(
            label: 'Since ${first.date.day}.${first.date.month}.'
                '${first.date.year}',
            // An explicit sign reads better than a bare number for a delta.
            value: '${change >= 0 ? '+' : ''}'
                '${ProgressChart.formatValue(change)} $unit',
          ),
          _SummaryRow(label: 'Entries', value: '${points.length}'),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
