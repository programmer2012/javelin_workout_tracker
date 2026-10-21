import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';

void main() {
  group('legacy format', () {
    test('reads exercises stored as a name-keyed map with string numbers', () {
      final exercises = exercisesFromDynamic({
        'Bench Press': [
          {'reps': '10', 'weight': '60'},
          {'reps': '8', 'weight': '65'},
        ],
        'Squats': [
          {'reps': '5', 'weight': '100'},
        ],
      });

      expect(exercises.map((e) => e.name), ['Bench Press', 'Squats']);
      expect(exercises.first.sets.length, 2);
      expect(exercises.first.sets.first.reps, 10);
      expect(exercises.first.sets.first.weight, 60);
      expect(exercises.first.totalVolume, 10 * 60 + 8 * 65);
    });

    test('reads a workoutHistory entry with epoch millis and seconds', () {
      final workout = Workout.fromMap({
        'date': 1700000000000,
        'duration': 3600,
        'exercises': {
          'Cleans': [
            {'reps': '3', 'weight': '80'},
          ],
        },
      });

      expect(workout.date, DateTime.fromMillisecondsSinceEpoch(1700000000000));
      expect(workout.duration, const Duration(hours: 1));
      expect(workout.totalReps, 3);
      expect(workout.totalVolume, 240);
    });

    test('tolerates empty and malformed entries instead of throwing', () {
      expect(exercisesFromDynamic(null), isEmpty);
      expect(exercisesFromDynamic('nonsense'), isEmpty);

      final workout = Workout.fromMap({});
      expect(workout.exercises, isEmpty);
      expect(workout.duration, Duration.zero);
      expect(workout.totalReps, 0);
    });

    test('a comma decimal weight is read as a number', () {
      final exercises = exercisesFromDynamic({
        'Pull Over': [
          {'reps': 12, 'weight': '22,5'},
        ],
      });

      expect(exercises.single.sets.single.weight, 22.5);
    });
  });

  group('current format', () {
    test('survives a toMap/fromMap round trip with order and ids intact', () {
      final original = exercisesFromDynamic({
        'Bench Press': [
          {'reps': '10', 'weight': '60'},
        ],
        'Squats': [
          {'reps': '5', 'weight': '100'},
        ],
      });

      final restored =
          exercisesFromDynamic(original.map((e) => e.toMap()).toList());

      expect(restored.map((e) => e.name), ['Bench Press', 'Squats']);
      expect(restored.map((e) => e.id), original.map((e) => e.id));
      expect(restored.first.sets.single.reps, 10);
      expect(restored.last.sets.single.weight, 100);
    });

    test('the same exercise can appear twice, which the old map forbade', () {
      final exercises = exercisesFromDynamic([
        {
          'id': 'a',
          'name': 'Bench Press',
          'sets': [
            {'id': 's1', 'reps': 10, 'weight': 60}
          ]
        },
        {
          'id': 'b',
          'name': 'Bench Press',
          'sets': [
            {'id': 's2', 'reps': 6, 'weight': 80}
          ]
        },
      ]);

      expect(exercises.length, 2);
      expect(exercises[0].sets.single.weight, 60);
      expect(exercises[1].sets.single.weight, 80);
    });

    test('a workout serialises its date as a Timestamp', () {
      final date = DateTime(2026, 3, 14, 9, 30);
      final workout = Workout(
        id: '',
        date: date,
        duration: const Duration(minutes: 45),
        exercises: exercisesFromDynamic([
          {
            'id': 'a',
            'name': 'Cleans',
            'sets': [
              {'id': 's1', 'reps': 3, 'weight': 80}
            ]
          }
        ]),
      );

      final map = workout.toMap();
      expect(map['date'], Timestamp.fromDate(date));
      expect(map['durationSeconds'], 45 * 60);

      final restored = Workout.fromMap(map, id: 'doc1');
      expect(restored.id, 'doc1');
      expect(restored.date, date);
      expect(restored.duration, const Duration(minutes: 45));
      expect(restored.totalVolume, 240);
    });
  });
}
