import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';
import 'package:javelin_workout_tracker/utils/coerce.dart';

/// A finished workout. Stored as one document in `users/{uid}/workouts`.
class Workout {
  final String id;
  final DateTime date;
  final Duration duration;
  final List<WorkoutExercise> exercises;

  Workout({
    required this.id,
    required this.date,
    required this.duration,
    required this.exercises,
  });

  /// Accepts both the current document shape and legacy entries that lived in
  /// the `workoutHistory` array (`date` as epoch millis, `duration` in
  /// seconds, `exercises` as a map keyed by name).
  factory Workout.fromMap(Map<String, dynamic> map, {String id = ''}) {
    return Workout(
      id: id,
      date: coerceDate(map['date']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      duration: Duration(
        seconds: coerceInt(map['durationSeconds'] ?? map['duration']),
      ),
      exercises: exercisesFromDynamic(map['exercises']),
    );
  }

  factory Workout.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    return Workout.fromMap(snap.data() ?? {}, id: snap.id);
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'durationSeconds': duration.inSeconds,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };

  int get totalReps => exercises.fold(0, (total, e) => total + e.totalReps);

  double get totalVolume =>
      exercises.fold(0.0, (total, e) => total + e.totalVolume);
}
