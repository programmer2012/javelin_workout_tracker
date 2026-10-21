import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:javelin_workout_tracker/models/workout_timer_state.dart';

/// Owns the elapsed time of a workout so the page can read it when saving.
/// The widget is a pure view on this controller.
///
/// Elapsed time is always derived from the wall clock via [WorkoutTimerState],
/// never accumulated one second per tick: mobile platforms suspend timers for
/// backgrounded apps, so tick counting loses every minute the phone spends in
/// a pocket between sets. The periodic timer here exists only to repaint the
/// display once a second.
class CountUpTimerController extends ChangeNotifier {
  /// Called on [start], [stop] and [reset] — but never on a repaint tick and
  /// never on [restore] — so the page can persist transitions without writing
  /// to Firestore once a second.
  VoidCallback? onTransition;

  Timer? _ticker;
  WorkoutTimerState _state = WorkoutTimerState.empty;

  WorkoutTimerState get state => _state;

  Duration get elapsed => _state.elapsedAt(DateTime.now());

  bool get isRunning => _state.isRunning;

  void start() {
    if (isRunning) return;
    _state = WorkoutTimerState(
      accumulated: _state.accumulated,
      runningSince: DateTime.now(),
    );
    _startTicker();
    notifyListeners();
    onTransition?.call();
  }

  void stop() {
    if (!isRunning) return;
    // Fold the stretch that just ended into the accumulated total.
    _state = WorkoutTimerState(accumulated: elapsed);
    _stopTicker();
    notifyListeners();
    onTransition?.call();
  }

  void toggle() => isRunning ? stop() : start();

  void reset() {
    _state = WorkoutTimerState.empty;
    _stopTicker();
    notifyListeners();
    onTransition?.call();
  }

  /// Adopts state loaded from Firestore, resuming the display if the clock was
  /// still running when the app was last closed. Deliberately does not fire
  /// [onTransition]: these values came from Firestore in the first place.
  void restore(WorkoutTimerState state) {
    _state = state;
    if (state.isRunning) {
      _startTicker();
    } else {
      _stopTicker();
    }
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
