import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:javelin_workout_tracker/models/season_plan.dart';

/// The season plan and the athlete's weekly actuals.
///
/// The plan itself is static and ships as an asset — it is the same for
/// everyone using this build, so there is nothing to store per user. Only
/// the IST numbers go to Firestore, in `users/{uid}/season/{seasonId}`, one
/// document holding a map per week so a whole season reads in one go.
class SeasonRepository {
  SeasonRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String _planAsset = 'assets/seed/season_plan.json';
  static const String seasonId = '2026-27';

  static SeasonPlan? _cachedPlan;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _seasonDoc => _firestore
      .collection('users')
      .doc(_uid)
      .collection('season')
      .doc(seasonId);

  /// Loads and caches the bundled plan. Parsing 43 weeks of session text on
  /// every rebuild would be wasteful, and the asset cannot change at runtime.
  ///
  /// Returns an empty plan when the asset is absent. The seed files hold a
  /// real athlete's programming and are kept out of version control, so a
  /// fresh clone has none — that must degrade to "no plan yet" rather than
  /// crash on launch.
  Future<SeasonPlan> loadPlan() async {
    final cached = _cachedPlan;
    if (cached != null) return cached;

    try {
      final raw = await rootBundle.loadString(_planAsset);
      return _cachedPlan = SeasonPlan.fromMap(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return _cachedPlan = SeasonPlan.empty;
    }
  }

  Stream<Map<String, WeekActuals>> watchActuals() =>
      _seasonDoc.snapshots().map(weekActualsFrom);

  /// Writes one week's actuals. `merge` keeps the other weeks in the
  /// document untouched.
  Future<void> saveWeek(String weekKey, WeekActuals actuals) {
    return _seasonDoc.set(
      {weekKey: actuals.toMap()},
      SetOptions(merge: true),
    );
  }

  Future<void> clearWeek(String weekKey) {
    return _seasonDoc.set(
      {weekKey: FieldValue.delete()},
      SetOptions(merge: true),
    );
  }
}
