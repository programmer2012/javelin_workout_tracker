import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/components/count_up_timer_widget.dart';
import 'package:javelin_workout_tracker/components/exercise_widget.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';
import 'package:javelin_workout_tracker/models/workout_set.dart';
import 'package:javelin_workout_tracker/models/workout_timer_state.dart';
import 'package:javelin_workout_tracker/pages/choose_workout.dart';
import 'package:javelin_workout_tracker/services/workout_repository.dart';
import 'package:javelin_workout_tracker/utils/count_up_timer_controler.dart';

/// Edits the workout that is currently in progress.
///
/// The page owns the data ([_exercises]); widgets are rebuilt from it. Remote
/// snapshots are applied through [_applySnapshot], never from `build`, so
/// typing is not interrupted and no text controllers leak.
class AddWorkoutPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AddWorkoutPage({required this.userData, super.key});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  static const _debounceDelay = Duration(milliseconds: 700);

  final WorkoutRepository _repository = WorkoutRepository();
  final CountUpTimerController _timerController = CountUpTimerController();

  List<WorkoutExercise> _exercises = [];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _debounce;

  /// Writes we started that have not completed yet. While any are pending we
  /// ignore remote snapshots, otherwise an in-flight save would bounce stale
  /// data back over the user's edits.
  int _pendingWrites = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    // Only start/stop/reset reach this, never the once-a-second repaint.
    _timerController.onTransition = _persistTimerState;
    _subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _timerController.dispose();
    super.dispose();
  }

  void _subscribe() {
    _subscription = _repository.userStream().listen(
      _applySnapshot,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not load the current workout: $error';
        });
      },
    );
  }

  void _applySnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    if (!mounted) return;

    final remote = _repository.currentWorkoutFrom(snapshot.data());

    // Adopt the stored clock once, on the first snapshot. After that the
    // timer is driven locally; re-reading it on every snapshot would fight
    // the user's own pause and resume.
    if (_loading) {
      _timerController.restore(_repository.timerStateFrom(snapshot.data()));
    }

    if (!_loading) {
      final hasLocalEdits = (_debounce?.isActive ?? false) ||
          _pendingWrites > 0 ||
          snapshot.metadata.hasPendingWrites;
      if (hasLocalEdits || _isSameAsLocal(remote)) return;
    }

    setState(() {
      _exercises = remote;
      _loading = false;
      _error = null;
      if (_expandedIndex != null && _expandedIndex! >= _exercises.length) {
        _expandedIndex = null;
      }
    });
  }

  bool _isSameAsLocal(List<WorkoutExercise> remote) {
    if (remote.length != _exercises.length) return false;
    for (var i = 0; i < remote.length; i++) {
      final a = remote[i];
      final b = _exercises[i];
      if (a.name != b.name || a.sets.length != b.sets.length) return false;
      for (var j = 0; j < a.sets.length; j++) {
        if (a.sets[j].reps != b.sets[j].reps ||
            a.sets[j].weight != b.sets[j].weight) {
          return false;
        }
      }
    }
    return true;
  }

  // --- persistence --------------------------------------------------------

  /// Collects edits for a moment before writing, so typing a weight costs one
  /// write instead of one per keystroke.
  void _scheduleSave({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _save();
    } else {
      _debounce = Timer(_debounceDelay, _save);
    }
  }

  Future<void> _save() async {
    _pendingWrites++;
    try {
      await _repository.saveCurrentWorkout(_exercises);
    } catch (error) {
      _showMessage('Could not save: $error');
    } finally {
      _pendingWrites--;
    }
  }

  /// Persists the clock whenever it is started, paused or reset, so closing
  /// the app mid-workout no longer loses the duration.
  Future<void> _persistTimerState() async {
    _pendingWrites++;
    try {
      await _repository.saveTimerState(_timerController.state);
    } catch (error) {
      _showMessage('Could not save the workout timer: $error');
    } finally {
      _pendingWrites--;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // --- mutations ----------------------------------------------------------

  void _handleExpansionChange(int index) {
    setState(() => _expandedIndex = index < 0 ? null : index);
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      final sets = _exercises[exerciseIndex].sets;
      // Carry the previous set over so the user only edits what changed.
      sets.add(sets.isEmpty ? WorkoutSet.create() : sets.last.copy());
    });
    _scheduleSave(immediate: true);
  }

  void _deleteSet(int exerciseIndex, int setIndex) {
    setState(() => _exercises[exerciseIndex].sets.removeAt(setIndex));
    _scheduleSave(immediate: true);
  }

  Future<void> _confirmDeleteExercise(int index) async {
    final name = _exercises[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          'Delete "$name"?',
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          MaterialButton(
            color: Colors.green,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('delete'),
          ),
          MaterialButton(
            color: Colors.red,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (index >= _exercises.length) return;

    setState(() {
      _exercises.removeAt(index);
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    _scheduleSave(immediate: true);
  }

  Future<void> _chooseExercises() async {
    final workoutList = widget.userData['workoutList'];
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => ChooseWorkout(
          exercises: workoutList is List ? workoutList : const [],
        ),
      ),
    );

    // Null when the user backed out with the system gesture or the app bar.
    if (!mounted || selected == null || selected.isEmpty) return;

    setState(() {
      for (final name in selected) {
        _exercises.add(WorkoutExercise.create(name: name));
      }
    });
    _scheduleSave(immediate: true);
    if (!_timerController.isRunning) _timerController.start();
  }

  Future<void> _confirmSaveWorkout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          'Sure you want to save and quit this workout?',
          style: TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          MaterialButton(
            color: Colors.green,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('save'),
          ),
          MaterialButton(
            color: Colors.red,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _finishWorkout();
  }

  Future<void> _finishWorkout() async {
    _debounce?.cancel();
    setState(() => _saving = true);

    final workout = Workout(
      id: '',
      date: DateTime.now(),
      duration: _timerController.elapsed,
      exercises: _exercises,
    );

    try {
      await _repository.finishWorkout(workout);
      if (!mounted) return;
      setState(() {
        _exercises = [];
        _expandedIndex = null;
      });
      // `restore` rather than `reset`: the batch above already cleared the
      // stored clock, so there is nothing left to write back.
      _timerController.restore(WorkoutTimerState.empty);
      _showMessage('Workout saved');
    } catch (error) {
      _showMessage('Could not save the workout: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: const Center(child: Text('Add a new Workout')),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _subscription?.cancel();
                  _subscribe();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // A Column with the list in an Expanded rather than a scroll view with
    // fixed heights: the card now takes whatever the screen gives it, so it
    // cannot overflow on a small phone or at a large font scale.
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_exercises.isNotEmpty) Expanded(child: _buildExerciseList()),
          _buildChooseExerciseButton(),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade200,
      ),
      child: Column(
        children: [
          CountUpTimer(controller: _timerController),
          Expanded(
            child: ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) => ExerciseWidget(
                key: ValueKey(_exercises[index].id),
                exercise: _exercises[index],
                index: index,
                isExpanded: _expandedIndex == index,
                onExpansionChanged: _handleExpansionChange,
                onChanged: _scheduleSave,
                onAddSet: () => _addSet(index),
                onDeleteSet: (setIndex) => _deleteSet(index, setIndex),
                onDelete: () => _confirmDeleteExercise(index),
              ),
            ),
          ),
          TextButton(
            onPressed: _saving ? null : _confirmSaveWorkout,
            child: _saving
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Workout'),
          ),
        ],
      ),
    );
  }

  Widget _buildChooseExerciseButton() {
    return GestureDetector(
      onTap: _chooseExercises,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade200,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Choose exercise', style: TextStyle(fontSize: 17)),
            Icon(Icons.add),
          ],
        ),
      ),
    );
  }
}
