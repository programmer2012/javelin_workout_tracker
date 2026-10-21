import 'package:javelin_workout_tracker/utils/coerce.dart';
import 'package:javelin_workout_tracker/utils/id.dart';

/// A single set of an exercise. Reps and weight are kept as numbers; older
/// documents stored them as strings, which [WorkoutSet.fromMap] still accepts.
class WorkoutSet {
  final String id;
  int reps;
  double weight;

  WorkoutSet({
    required this.id,
    this.reps = 0,
    this.weight = 0,
  });

  WorkoutSet.create({this.reps = 0, this.weight = 0}) : id = newId();

  factory WorkoutSet.fromMap(Map<String, dynamic> map) {
    return WorkoutSet(
      id: map['id'] as String? ?? newId(),
      reps: coerceInt(map['reps']),
      weight: coerceDouble(map['weight']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reps': reps,
        'weight': weight,
      };

  WorkoutSet copy() => WorkoutSet(id: newId(), reps: reps, weight: weight);

  /// Volume contributed by this set, in kg.
  double get volume => reps * weight;
}
