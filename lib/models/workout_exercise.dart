import 'package:javelin_workout_tracker/models/workout_set.dart';
import 'package:javelin_workout_tracker/utils/id.dart';

/// One exercise inside a workout, with its sets in user-defined order.
class WorkoutExercise {
  final String id;
  final String name;
  final List<WorkoutSet> sets;

  WorkoutExercise({
    required this.id,
    required this.name,
    List<WorkoutSet>? sets,
  }) : sets = sets ?? [];

  WorkoutExercise.create({required this.name, List<WorkoutSet>? sets})
      : id = newId(),
        sets = sets ?? [];

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    final rawSets = map['sets'];
    return WorkoutExercise(
      id: map['id'] as String? ?? newId(),
      name: map['name'] as String? ?? '',
      sets: rawSets is List
          ? rawSets
              .whereType<Map>()
              .map((s) => WorkoutSet.fromMap(Map<String, dynamic>.from(s)))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sets': sets.map((s) => s.toMap()).toList(),
      };

  int get totalReps => sets.fold(0, (total, s) => total + s.reps);

  double get totalVolume => sets.fold(0.0, (total, s) => total + s.volume);
}

/// Reads a list of exercises from Firestore, tolerating both the current
/// format (a `List` of exercise maps, which preserves order and allows the same
/// exercise twice) and the legacy format (a `Map` keyed by exercise name).
List<WorkoutExercise> exercisesFromDynamic(dynamic raw) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((e) => WorkoutExercise.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  if (raw is Map) {
    return raw.entries.map((entry) {
      final rawSets = entry.value;
      return WorkoutExercise.create(
        name: entry.key.toString(),
        sets: rawSets is List
            ? rawSets
                .whereType<Map>()
                .map((s) => WorkoutSet.fromMap(Map<String, dynamic>.from(s)))
                .toList()
            : [],
      );
    }).toList();
  }

  return [];
}
