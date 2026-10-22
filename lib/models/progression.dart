import 'package:javelin_workout_tracker/models/weight_entry.dart';
import 'package:javelin_workout_tracker/models/workout.dart';

/// One plottable measurement: a value at a point in time.
class ChartPoint {
  final DateTime date;
  final double value;

  const ChartPoint({required this.date, required this.value});
}

/// What to plot for an exercise across workouts.
enum ExerciseMetric {
  /// The heaviest single set, which is the usual read on strength progress.
  heaviestWeight,

  /// Reps x weight summed over the exercise's sets.
  totalVolume,

  /// Reps summed over the exercise's sets.
  totalReps;

  String get label => switch (this) {
        ExerciseMetric.heaviestWeight => 'Heaviest set',
        ExerciseMetric.totalVolume => 'Total volume',
        ExerciseMetric.totalReps => 'Total reps',
      };

  String get unit => switch (this) {
        ExerciseMetric.heaviestWeight => 'kg',
        ExerciseMetric.totalVolume => 'kg',
        ExerciseMetric.totalReps => 'reps',
      };
}

/// How far back a chart reaches.
enum ChartRange {
  oneMonth('1M', Duration(days: 30)),
  threeMonths('3M', Duration(days: 90)),
  sixMonths('6M', Duration(days: 182)),
  oneYear('1Y', Duration(days: 365)),
  all('All', null);

  const ChartRange(this.label, this.window);

  final String label;

  /// `null` for [all], which applies no cutoff.
  final Duration? window;
}

/// The points inside [range], counted back from [now].
///
/// The window is measured from now rather than from the most recent entry: a
/// "last 3 months" that silently reached back from an entry made a year ago
/// would show a full chart and read as current data.
List<ChartPoint> pointsInRange(
  List<ChartPoint> points,
  ChartRange range, {
  DateTime? now,
}) {
  final window = range.window;
  if (window == null) return points;

  final cutoff = (now ?? DateTime.now()).subtract(window);
  return points.where((point) => !point.date.isBefore(cutoff)).toList();
}

/// Body weight as chart points, oldest first.
List<ChartPoint> weightPoints(List<WeightEntry> entries) => [
      for (final entry in entries)
        ChartPoint(date: entry.date, value: entry.weight),
    ];

/// Every exercise name appearing anywhere in [workouts], de-duplicated and
/// sorted so the picker does not reshuffle between rebuilds.
///
/// Names are matched case-insensitively but displayed as first seen, so
/// "Bench Press" and "bench press" do not become two entries.
List<String> exerciseNamesIn(List<Workout> workouts) {
  final byLowercase = <String, String>{};

  for (final workout in workouts) {
    for (final exercise in workout.exercises) {
      final name = exercise.name.trim();
      if (name.isEmpty) continue;
      byLowercase.putIfAbsent(name.toLowerCase(), () => name);
    }
  }

  final names = byLowercase.values.toList();
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}

/// One point per workout containing [exerciseName], oldest first.
///
/// A workout that lists the same exercise twice is combined into a single
/// point: the heaviest set wins for [ExerciseMetric.heaviestWeight], and the
/// others sum. Workouts where the metric comes out at zero are left out — an
/// unfilled set would otherwise drag the line down to zero.
List<ChartPoint> progressionFor(
  List<Workout> workouts,
  String exerciseName,
  ExerciseMetric metric,
) {
  final target = exerciseName.trim().toLowerCase();
  final points = <ChartPoint>[];

  for (final workout in workouts) {
    final matching = workout.exercises
        .where((e) => e.name.trim().toLowerCase() == target)
        .toList();
    if (matching.isEmpty) continue;

    var value = 0.0;
    for (final exercise in matching) {
      switch (metric) {
        case ExerciseMetric.heaviestWeight:
          for (final set in exercise.sets) {
            // Only sets that were actually performed count.
            if (set.reps > 0 && set.weight > value) value = set.weight;
          }
        case ExerciseMetric.totalVolume:
          value += exercise.totalVolume;
        case ExerciseMetric.totalReps:
          value += exercise.totalReps.toDouble();
      }
    }

    if (value > 0) {
      points.add(ChartPoint(date: workout.date, value: value));
    }
  }

  points.sort((a, b) => a.date.compareTo(b.date));
  return points;
}
