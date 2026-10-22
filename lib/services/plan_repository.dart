import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:javelin_workout_tracker/models/training_plan.dart';
import 'package:javelin_workout_tracker/services/season_repository.dart';

/// Training plans published by coaches.
///
/// A plan is owned by the coach who imported it and read by the athletes
/// listed on it. Writes from the app are limited to that assignment list —
/// the plan body comes from the desktop importer, which parses the coach's
/// spreadsheet.
class PlanRepository {
  PlanRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    SeasonRepository? seasons,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _seasons = seasons ?? SeasonRepository();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final SeasonRepository _seasons;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _plans =>
      _firestore.collection('plans');

  /// Plans a coach has assigned to the signed-in athlete.
  ///
  /// The `array-contains` filter matches the security rule exactly, which is
  /// what makes the query permissible: every document it can return is one
  /// the rules already allow.
  Stream<List<TrainingPlan>> watchAssignedPlans() {
    return _plans
        .where('athleteUids', arrayContains: _uid)
        .snapshots()
        .map((snap) => snap.docs.map(TrainingPlan.fromSnapshot).toList()
          ..sort(_newestFirst));
  }

  /// Plans the signed-in user has published as a coach.
  Stream<List<TrainingPlan>> watchOwnedPlans() {
    return _plans
        .where('ownerUid', isEqualTo: _uid)
        .snapshots()
        .map((snap) => snap.docs.map(TrainingPlan.fromSnapshot).toList()
          ..sort(_newestFirst));
  }

  static int _newestFirst(TrainingPlan a, TrainingPlan b) {
    final left = a.updatedAt;
    final right = b.updatedAt;
    // Plans with no timestamp sort last rather than crashing the comparator.
    if (left == null && right == null) return a.name.compareTo(b.name);
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }

  /// Grants or revokes an athlete's access to a plan.
  Future<void> setAssigned({
    required String planId,
    required String athleteUid,
    required bool assigned,
  }) {
    return _plans.doc(planId).update({
      'athleteUids': assigned
          ? FieldValue.arrayUnion([athleteUid])
          : FieldValue.arrayRemove([athleteUid]),
    });
  }

  /// The plan to show this athlete: the one their coach assigned, or the
  /// plan bundled with the app when there is none.
  ///
  /// Falling back rather than showing nothing means the app keeps working
  /// for an athlete with no coach, and for Tom's own season.
  Future<ResolvedPlan> resolve() async {
    try {
      final snap = await _plans
          .where('athleteUids', arrayContains: _uid)
          .get();

      if (snap.docs.isNotEmpty) {
        final plans = snap.docs.map(TrainingPlan.fromSnapshot).toList()
          ..sort(_newestFirst);
        final chosen = plans.first;
        // A plan with no weeks would leave the page blank; prefer the
        // bundled one over an empty screen.
        if (chosen.content.weeks.isNotEmpty) {
          return ResolvedPlan(
            plan: chosen.content,
            source: PlanSource.coach,
            assigned: chosen,
          );
        }
      }
    } catch (_) {
      // Offline, or rules refused the query: fall through to the bundle.
    }

    return ResolvedPlan(
      plan: await _seasons.loadPlan(),
      source: PlanSource.bundled,
    );
  }
}
