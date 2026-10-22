import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/progression.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';
import 'package:javelin_workout_tracker/models/workout_set.dart';

Workout _workout(
  DateTime date,
  Map<String, List<(int reps, double weight)>> exercises,
) {
  return Workout(
    id: '',
    date: date,
    duration: const Duration(minutes: 60),
    exercises: [
      for (final entry in exercises.entries)
        WorkoutExercise.create(
          name: entry.key,
          sets: [
            for (final (reps, weight) in entry.value)
              WorkoutSet.create(reps: reps, weight: weight),
          ],
        ),
    ],
  );
}

void main() {
  final day1 = DateTime(2026, 3, 1);
  final day2 = DateTime(2026, 3, 8);
  final day3 = DateTime(2026, 3, 15);

  group('exerciseNamesIn', () {
    test('collects every name across workouts, sorted and de-duplicated', () {
      final names = exerciseNamesIn([
        _workout(day1, {
          'Squats': [(5, 100)],
          'Bench Press': [(8, 60)],
        }),
        _workout(day2, {
          'Cleans': [(3, 80)],
          'Bench Press': [(8, 62.5)],
        }),
      ]);

      expect(names, ['Bench Press', 'Cleans', 'Squats']);
    });

    test('treats differently cased spellings as one exercise', () {
      final names = exerciseNamesIn([
        _workout(day1, {
          'Bench Press': [(8, 60)],
        }),
        _workout(day2, {
          'bench press': [(8, 62.5)],
        }),
      ]);

      // First spelling seen wins, so the picker shows one stable entry.
      expect(names, ['Bench Press']);
    });

    test('ignores blank names and an empty history', () {
      expect(exerciseNamesIn([]), isEmpty);
      expect(
        exerciseNamesIn([
          _workout(day1, {
            '  ': [(5, 50)],
          })
        ]),
        isEmpty,
      );
    });
  });

  group('progressionFor', () {
    final history = [
      _workout(day2, {
        'Bench Press': [(8, 62.5), (6, 70)],
        'Squats': [(5, 100)],
      }),
      _workout(day1, {
        'Bench Press': [(8, 60), (8, 60)],
      }),
      _workout(day3, {
        'Squats': [(5, 105)],
      }),
    ];

    test('plots the heaviest set per workout, oldest first', () {
      final points =
          progressionFor(history, 'Bench Press', ExerciseMetric.heaviestWeight);

      // Sorted by date even though the history arrives newest-first.
      expect(points.map((p) => p.date), [day1, day2]);
      expect(points.map((p) => p.value), [60, 70]);
    });

    test('sums volume and reps across the sets', () {
      final volume =
          progressionFor(history, 'Bench Press', ExerciseMetric.totalVolume);
      expect(volume.map((p) => p.value), [8 * 60 + 8 * 60, 8 * 62.5 + 6 * 70]);

      final reps =
          progressionFor(history, 'Bench Press', ExerciseMetric.totalReps);
      expect(reps.map((p) => p.value), [16, 14]);
    });

    test('matches the exercise case-insensitively', () {
      final points =
          progressionFor(history, 'bench PRESS', ExerciseMetric.totalReps);
      expect(points.length, 2);
    });

    test('combines an exercise listed twice in one workout', () {
      final points = progressionFor(
        [
          Workout(
            id: '',
            date: day1,
            duration: Duration.zero,
            exercises: [
              WorkoutExercise.create(
                name: 'Cleans',
                sets: [WorkoutSet.create(reps: 3, weight: 80)],
              ),
              WorkoutExercise.create(
                name: 'Cleans',
                sets: [WorkoutSet.create(reps: 2, weight: 90)],
              ),
            ],
          )
        ],
        'Cleans',
        ExerciseMetric.heaviestWeight,
      );

      // One point for the workout, not two.
      expect(points.single.value, 90);
    });

    test('skips sets that were never filled in', () {
      final points = progressionFor(
        [
          _workout(day1, {
            // A weight typed with no reps is not a set that happened.
            'Squats': [(0, 200), (5, 100)],
          })
        ],
        'Squats',
        ExerciseMetric.heaviestWeight,
      );

      expect(points.single.value, 100);
    });

    test('leaves out workouts where the metric is zero', () {
      final points = progressionFor(
        [
          _workout(day1, {
            'Push Ups': [(20, 0)],
          })
        ],
        'Push Ups',
        ExerciseMetric.heaviestWeight,
      );

      // A bodyweight exercise has no weight to plot; reps still do.
      expect(points, isEmpty);
      expect(
        progressionFor(
          [
            _workout(day1, {
              'Push Ups': [(20, 0)],
            })
          ],
          'Push Ups',
          ExerciseMetric.totalReps,
        ).single.value,
        20,
      );
    });

    test('an unknown exercise yields no points', () {
      expect(
        progressionFor(history, 'Javelin Throw', ExerciseMetric.totalReps),
        isEmpty,
      );
    });
  });

  group('pointsInRange', () {
    final now = DateTime(2026, 10, 21);
    final points = [
      ChartPoint(date: DateTime(2024, 10, 21), value: 1),
      ChartPoint(date: DateTime(2025, 12, 21), value: 2),
      ChartPoint(date: DateTime(2026, 8, 21), value: 3),
      ChartPoint(date: DateTime(2026, 10, 10), value: 4),
    ];

    test('all applies no cutoff', () {
      expect(pointsInRange(points, ChartRange.all, now: now).length, 4);
    });

    test('narrower ranges keep only recent points', () {
      expect(
        pointsInRange(points, ChartRange.oneMonth, now: now)
            .map((p) => p.value),
        [4],
      );
      expect(
        pointsInRange(points, ChartRange.threeMonths, now: now)
            .map((p) => p.value),
        [3, 4],
      );
      expect(
        pointsInRange(points, ChartRange.oneYear, now: now)
            .map((p) => p.value),
        [2, 3, 4],
      );
    });

    test('the window is measured from now, not from the newest point', () {
      // Everything is years old: a 3 month range must come back empty rather
      // than reaching back from the last entry and looking current.
      final stale = [
        ChartPoint(date: DateTime(2020, 1, 1), value: 1),
        ChartPoint(date: DateTime(2020, 3, 1), value: 2),
      ];
      expect(pointsInRange(stale, ChartRange.threeMonths, now: now), isEmpty);
      expect(pointsInRange(stale, ChartRange.all, now: now).length, 2);
    });

    test('a point exactly on the cutoff is kept', () {
      final edge = [
        ChartPoint(date: now.subtract(const Duration(days: 30)), value: 1),
      ];
      expect(pointsInRange(edge, ChartRange.oneMonth, now: now).length, 1);
    });

    test('an empty list stays empty', () {
      expect(pointsInRange([], ChartRange.oneMonth, now: now), isEmpty);
    });
  });
}
