import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:javelin_workout_tracker/utils/coerce.dart';

/// How long the in-progress workout has been running.
///
/// [accumulated] covers stretches that have already finished, and
/// [runningSince] is the instant the clock was last started, or `null` while
/// it is paused.
///
/// Storing the start *instant* rather than a tick count is the whole point:
/// mobile platforms suspend timers for backgrounded apps, so a counter that
/// adds a second per tick loses every minute the phone spends in a pocket
/// between sets. Elapsed time derived from this state stays correct even if
/// the app was killed mid-workout.
class WorkoutTimerState {
  final Duration accumulated;
  final DateTime? runningSince;

  const WorkoutTimerState({
    this.accumulated = Duration.zero,
    this.runningSince,
  });

  static const empty = WorkoutTimerState();

  bool get isRunning => runningSince != null;

  Duration elapsedAt(DateTime now) {
    final since = runningSince;
    if (since == null) return accumulated;
    final run = now.difference(since);
    // A device clock moving backwards would otherwise report a shrinking
    // workout; never go below what already accumulated.
    return run.isNegative ? accumulated : accumulated + run;
  }

  factory WorkoutTimerState.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    return WorkoutTimerState(
      accumulated: Duration(seconds: coerceInt(map['accumulatedSeconds'])),
      runningSince: coerceDate(map['runningSince']),
    );
  }

  Map<String, dynamic> toMap() => {
        'accumulatedSeconds': accumulated.inSeconds,
        'runningSince':
            runningSince == null ? null : Timestamp.fromDate(runningSince!),
      };
}
