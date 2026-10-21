import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/workout_history_list.dart';
import 'package:javelin_workout_tracker/models/coach.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/services/coach_repository.dart';

/// What one athlete has actually done, for their coach.
class AthleteDetailPage extends StatefulWidget {
  final Athlete athlete;

  const AthleteDetailPage({required this.athlete, super.key});

  @override
  State<AthleteDetailPage> createState() => _AthleteDetailPageState();
}

class _AthleteDetailPageState extends State<AthleteDetailPage> {
  final CoachRepository _repository = CoachRepository();
  late final Stream<List<Workout>> _workouts =
      _repository.watchWorkoutsOf(widget.athlete.uid);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(title: Text(widget.athlete.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: StreamBuilder<List<Workout>>(
            stream: _workouts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    // Most likely cause is the athlete having revoked access
                    // while the page was open.
                    'Could not load these workouts.\n'
                    'The athlete may have removed you as their coach.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final workouts = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(workouts: workouts),
                  const SizedBox(height: 12),
                  Expanded(
                    child: WorkoutHistoryList(
                      workouts: workouts,
                      emptyMessage:
                          '${widget.athlete.name} has not finished a '
                          'workout yet.',
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final List<Workout> workouts;

  const _Header({required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();

    final totalReps = workouts.fold(0, (sum, w) => sum + w.totalReps);
    final totalVolume = workouts.fold(0.0, (sum, w) => sum + w.totalVolume);
    // The stream is ordered newest first.
    final last = workouts.first.date;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Stat(label: 'Workouts', value: '${workouts.length}'),
          _Stat(label: 'Reps', value: '$totalReps'),
          _Stat(label: 'Volume', value: '${formatNumber(totalVolume)} kg'),
          _Stat(label: 'Last', value: '${last.day}.${last.month}.'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }
}
