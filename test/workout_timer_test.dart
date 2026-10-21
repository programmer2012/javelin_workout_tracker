import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/workout_timer_state.dart';
import 'package:javelin_workout_tracker/utils/count_up_timer_controler.dart';

void main() {
  group('WorkoutTimerState', () {
    test('a paused clock reports only what accumulated', () {
      const state = WorkoutTimerState(accumulated: Duration(minutes: 12));

      expect(state.isRunning, isFalse);
      expect(state.elapsedAt(DateTime(2026, 3, 14)), const Duration(minutes: 12));
    });

    test('a running clock counts wall-clock time, not ticks', () {
      // The regression this guards: the timer used to add one second per
      // tick, so every minute the phone spent locked in a pocket between
      // sets was lost from the workout duration.
      final now = DateTime(2026, 3, 14, 10, 0);
      final state = WorkoutTimerState(
        accumulated: const Duration(minutes: 5),
        runningSince: now.subtract(const Duration(minutes: 30)),
      );

      expect(state.elapsedAt(now), const Duration(minutes: 35));
    });

    test('a clock moving backwards never shrinks the total', () {
      final state = WorkoutTimerState(
        accumulated: const Duration(minutes: 7),
        runningSince: DateTime(2026, 5, 1),
      );

      expect(
        state.elapsedAt(DateTime(2026, 4, 1)),
        const Duration(minutes: 7),
      );
    });

    test('a running clock survives a round trip through Firestore', () {
      final runningSince = DateTime(2026, 3, 14, 9, 30);

      final restored = WorkoutTimerState.fromMap(
        WorkoutTimerState(
          accumulated: const Duration(seconds: 90),
          runningSince: runningSince,
        ).toMap(),
      );

      expect(restored.accumulated, const Duration(seconds: 90));
      expect(restored.runningSince, runningSince);
      expect(restored.isRunning, isTrue);
    });

    test('a paused clock round trips with no start instant', () {
      final map =
          const WorkoutTimerState(accumulated: Duration(seconds: 42)).toMap();

      expect(map['runningSince'], isNull);

      final restored = WorkoutTimerState.fromMap(map);
      expect(restored.isRunning, isFalse);
      expect(restored.accumulated, const Duration(seconds: 42));
    });

    test('reads a Timestamp date and a string second count', () {
      final date = DateTime(2026, 1, 2, 3, 4);

      final state = WorkoutTimerState.fromMap({
        'accumulatedSeconds': '120',
        'runningSince': Timestamp.fromDate(date),
      });

      expect(state.accumulated, const Duration(minutes: 2));
      expect(state.runningSince, date);
    });

    test('a missing or empty field is a clock at zero', () {
      for (final state in [
        WorkoutTimerState.fromMap(null),
        WorkoutTimerState.fromMap({}),
      ]) {
        expect(state.accumulated, Duration.zero);
        expect(state.runningSince, isNull);
        expect(state.isRunning, isFalse);
      }
    });
  });

  group('CountUpTimerController', () {
    test('restores a clock that was still running when the app closed', () {
      final controller = CountUpTimerController();
      addTearDown(controller.dispose);

      controller.restore(
        WorkoutTimerState(
          accumulated: const Duration(minutes: 10),
          runningSince: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
      );

      expect(controller.isRunning, isTrue);
      // The 20 minutes the app spent closed still count.
      expect(controller.elapsed.inMinutes, 30);
    });

    test('restore is not a transition, so it writes nothing back', () {
      final controller = CountUpTimerController();
      addTearDown(controller.dispose);

      var transitions = 0;
      controller.onTransition = () => transitions++;

      controller.restore(
        const WorkoutTimerState(accumulated: Duration(minutes: 3)),
      );

      expect(transitions, 0);
      expect(controller.elapsed, const Duration(minutes: 3));
    });

    test('pausing banks the time that had run', () {
      final controller = CountUpTimerController();
      addTearDown(controller.dispose);

      controller.restore(
        WorkoutTimerState(
          accumulated: const Duration(minutes: 1),
          runningSince: DateTime.now().subtract(const Duration(minutes: 4)),
        ),
      );

      controller.stop();

      expect(controller.isRunning, isFalse);
      expect(controller.state.runningSince, isNull);
      expect(controller.state.accumulated.inMinutes, 5);
      // Paused, so the total stops moving.
      expect(controller.elapsed.inMinutes, 5);
    });

    test('start, stop and reset each report one transition', () {
      final controller = CountUpTimerController();
      addTearDown(controller.dispose);

      var transitions = 0;
      controller.onTransition = () => transitions++;

      controller.start();
      controller.start(); // already running, so not a transition
      controller.stop();
      controller.stop(); // already paused
      controller.reset();

      expect(transitions, 3);
      expect(controller.elapsed, Duration.zero);
      expect(controller.isRunning, isFalse);
    });

    test('a repaint tick is not a transition', () async {
      final controller = CountUpTimerController();
      addTearDown(controller.dispose);

      var transitions = 0;
      var repaints = 0;
      controller.onTransition = () => transitions++;
      controller.addListener(() => repaints++);

      controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      // Ticks repaint the display but must not reach Firestore, or the app
      // would write to the user document once a second.
      expect(transitions, 1);
      expect(repaints, greaterThan(1));
    });
  });
}
