import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/pages/add_workout_page.dart';
import 'package:javelin_workout_tracker/pages/season_page.dart';
import 'package:javelin_workout_tracker/pages/tests_page.dart';
import 'package:javelin_workout_tracker/pages/overview_page.dart';
import 'package:javelin_workout_tracker/pages/progress_page.dart';
import 'package:javelin_workout_tracker/services/workout_repository.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final WorkoutRepository _repository = WorkoutRepository();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;

  /// Owned here rather than by each page: the overview needs the history for
  /// its totals and the progress page needs it for the exercise charts, and
  /// two separate listeners meant downloading the whole collection twice.
  StreamSubscription<List<Workout>>? _workoutSubscription;

  Map<String, dynamic>? _userData;
  List<Workout> _workouts = [];
  String? _error;
  int _currentIndex = 0;
  bool _migrationStarted = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _workoutSubscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _workoutSubscription?.cancel();
    _workoutSubscription = _repository.watchWorkouts().listen(
      (workouts) {
        if (!mounted) return;
        setState(() => _workouts = workouts);
      },
      // The totals and charts simply stay empty; the profile stream below
      // owns the visible error state.
      onError: (Object error) => debugPrint('Could not load workouts: $error'),
    );

    _subscription?.cancel();
    _subscription = _repository.userStream().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _userData = snapshot.data() ?? {};
          _error = null;
        });
        _migrateOnce();
      },
      onError: (Object error) {
        if (!mounted) return;
        // Previously this only printed, leaving the user on an endless
        // spinner with no way to recover.
        setState(() => _error = 'Could not load your profile: $error');
      },
    );
  }

  /// Moves a legacy `workoutHistory` array into the workouts subcollection.
  /// A no-op once that field is gone, so it is safe on every launch.
  Future<void> _migrateOnce() async {
    if (_migrationStarted) return;
    _migrationStarted = true;
    try {
      await _repository.migrateLegacyWorkoutHistory();
    } catch (error) {
      debugPrint('Workout history migration failed: $error');
      _migrationStarted = false;
    }
  }

  void _retry() {
    setState(() => _error = null);
    _subscribe();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: _buildBody(),
      bottomNavigationBar: CurvedNavigationBar(
        height: 60,
        index: _currentIndex,
        backgroundColor: Colors.deepPurple,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          Icon(Icons.home),
          Icon(Icons.fitness_center),
          Icon(Icons.add),
          Icon(Icons.calendar_month),
          Icon(Icons.bar_chart),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final userData = _userData;
    if (userData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final screens = [
      OverviewPage(userData: userData, workouts: _workouts),
      TestsPage(userData: userData),
      AddWorkoutPage(userData: userData),
      const SeasonPage(),
      ProgressPage(userData: userData, workouts: _workouts),
    ];

    return IndexedStack(index: _currentIndex, children: screens);
  }
}
