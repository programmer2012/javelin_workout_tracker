import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:javelin_workout_tracker/models/weight_entry.dart';
import 'package:javelin_workout_tracker/models/workout.dart';
import 'package:javelin_workout_tracker/models/workout_exercise.dart';
import 'package:javelin_workout_tracker/models/workout_timer_state.dart';

/// Single point of access to the signed-in user's workout data.
///
/// Finished workouts live in the `users/{uid}/workouts` subcollection. They
/// used to be appended to a `workoutHistory` array on the user document, which
/// grows against the 1 MB document limit and makes every save a
/// read-modify-write of the whole history. [migrateLegacyWorkoutHistory] moves
/// existing users over.
class WorkoutRepository {
  WorkoutRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _workouts =>
      _userDoc.collection('workouts');

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream() =>
      _userDoc.snapshots();

  Future<Map<String, dynamic>> fetchUser() async {
    final snap = await _userDoc.get();
    return snap.data() ?? {};
  }

  // --- current (in progress) workout -------------------------------------

  List<WorkoutExercise> currentWorkoutFrom(Map<String, dynamic>? userData) =>
      exercisesFromDynamic(userData?['currentWorkout']);

  /// The clock for the in-progress workout. Persisting it means a workout
  /// interrupted by the app closing resumes with its real duration instead of
  /// restarting at zero.
  WorkoutTimerState timerStateFrom(Map<String, dynamic>? userData) {
    final raw = userData?['currentWorkoutTimer'];
    return WorkoutTimerState.fromMap(
      raw is Map ? Map<String, dynamic>.from(raw) : null,
    );
  }

  Future<void> saveCurrentWorkout(List<WorkoutExercise> exercises) {
    return _userDoc.set(
      {'currentWorkout': exercises.map((e) => e.toMap()).toList()},
      SetOptions(merge: true),
    );
  }

  Future<void> saveTimerState(WorkoutTimerState state) {
    return _userDoc.set(
      {'currentWorkoutTimer': state.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<void> clearCurrentWorkout() {
    return _userDoc.set({
      'currentWorkout': [],
      'currentWorkoutTimer': WorkoutTimerState.empty.toMap(),
    }, SetOptions(merge: true));
  }

  // --- exercise catalogue -------------------------------------------------

  Future<void> saveExerciseCatalogue(List<Map<String, dynamic>> exercises) {
    return _userDoc.set({'workoutList': exercises}, SetOptions(merge: true));
  }

  // --- finished workouts --------------------------------------------------

  /// Writes the workout to the history subcollection and clears the in
  /// progress workout and its clock in one atomic batch, so a failure cannot
  /// do both.
  Future<void> finishWorkout(Workout workout) {
    final batch = _firestore.batch();
    batch.set(_workouts.doc(), workout.toMap());
    batch.set(
      _userDoc,
      {
        'currentWorkout': [],
        'currentWorkoutTimer': WorkoutTimerState.empty.toMap(),
      },
      SetOptions(merge: true),
    );
    return batch.commit();
  }

  Stream<List<Workout>> watchWorkouts() {
    return _workouts
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Workout.fromSnapshot).toList());
  }

  Future<List<Workout>> fetchWorkouts() async {
    final snap = await _workouts.orderBy('date', descending: true).get();
    return snap.docs.map(Workout.fromSnapshot).toList();
  }

  // --- body weight --------------------------------------------------------

  /// Reads the logged body weights, oldest first.
  List<WeightEntry> weightHistoryFrom(Map<String, dynamic>? userData) =>
      weightHistoryFromDynamic(userData?['weightHistory']);

  /// `arrayUnion` appends server-side, so two devices logging a weight at the
  /// same time can no longer overwrite each other.
  Future<void> addWeightEntry(double weight) {
    final entry = WeightEntry(date: DateTime.now(), weight: weight);
    return _userDoc.set({
      'weightHistory': FieldValue.arrayUnion([entry.toMap()])
    }, SetOptions(merge: true));
  }

  // --- migration ----------------------------------------------------------

  /// Moves a legacy `workoutHistory` array into the `workouts` subcollection
  /// and removes the field. Safe to call on every launch: it is a no-op once
  /// the field is gone.
  Future<void> migrateLegacyWorkoutHistory() async {
    final snap = await _userDoc.get();
    final data = snap.data();
    if (data == null || !data.containsKey('workoutHistory')) return;

    final legacy = data['workoutHistory'];
    final entries = legacy is List ? legacy.whereType<Map>().toList() : const [];

    if (entries.isEmpty) {
      await _userDoc.update({'workoutHistory': FieldValue.delete()});
      return;
    }

    // A batch is capped at 500 writes, so chunk the history.
    const chunkSize = 450;
    for (var start = 0; start < entries.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, entries.length);
      final batch = _firestore.batch();
      for (final entry in entries.sublist(start, end)) {
        final workout = Workout.fromMap(Map<String, dynamic>.from(entry));
        batch.set(_workouts.doc(), workout.toMap());
      }
      await batch.commit();
    }

    await _userDoc.update({'workoutHistory': FieldValue.delete()});
  }
}
