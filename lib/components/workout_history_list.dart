import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';

/// Finished workouts, newest first: a summary per session that opens to the
/// exercises and the sets as they were logged.
class WorkoutHistoryList extends StatelessWidget {
  final List<Workout> workouts;
  final String emptyMessage;

  /// Set when the list is already inside a scrolling parent.
  final bool shrinkWrap;

  const WorkoutHistoryList({
    required this.workouts,
    this.emptyMessage = 'No finished workouts yet.',
    this.shrinkWrap = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      itemCount: workouts.length,
      itemBuilder: (context, index) => _WorkoutCard(workout: workouts[index]),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final exercises = workout.exercises;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Theme(
        // The default divider lines fight the card's rounded edges.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  formatWorkoutDate(workout.date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formatDuration(workout.duration),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          subtitle: Text(
            _summaryLine(exercises),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          children: [
            if (exercises.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No exercises were recorded.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              )
            else
              for (final exercise in exercises)
                _ExerciseRow(exercise: exercise),
          ],
        ),
      ),
    );
  }

  String _summaryLine(List<WorkoutExercise> exercises) {
    final parts = <String>[
      '${exercises.length} ${exercises.length == 1 ? 'exercise' : 'exercises'}',
      '${workout.totalReps} reps',
    ];
    if (workout.totalVolume > 0) {
      parts.add('${formatNumber(workout.totalVolume)} kg');
    }
    return parts.join(' · ');
  }
}

class _ExerciseRow extends StatelessWidget {
  final WorkoutExercise exercise;

  const _ExerciseRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final sets = exercise.sets.where((s) => s.reps > 0 || s.weight > 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.name.trim().isEmpty ? 'Unnamed exercise' : exercise.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          if (sets.isEmpty)
            const Text(
              'no sets',
              style: TextStyle(fontSize: 13, color: Colors.black45),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                for (final set in sets)
                  Text(
                    set.weight > 0
                        ? '${set.reps} × ${formatNumber(set.weight)} kg'
                        : '${set.reps} reps',
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

const List<String> _weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// e.g. `Tue 20.10.2026`. The weekday matters to a coach reading a training
/// week at a glance.
String formatWorkoutDate(DateTime date) {
  final weekday = _weekdays[(date.weekday - 1).clamp(0, 6)];
  return '$weekday ${date.day}.${date.month}.${date.year}';
}

/// `1:05:09` once past an hour, `5:09` below it.
String formatDuration(Duration duration) {
  final seconds = duration.inSeconds;
  if (seconds <= 0) return '–';

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final secs = seconds.remainder(60);

  return hours > 0
      ? '$hours:${twoDigits(minutes)}:${twoDigits(secs)}'
      : '$minutes:${twoDigits(secs)}';
}

/// Whole numbers stay whole; anything else gets a single decimal.
String formatNumber(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
