import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:javelin_workout_tracker/models/test_result.dart';

/// Test and competition results for the signed-in athlete.
///
/// Stored in `users/{uid}/testResults`, which the existing owner-only rule
/// for subcollections already covers.
class TestRepository {
  TestRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  /// Bumped if the bundled history is ever corrected, so a re-import can be
  /// offered without duplicating what is already there.
  static const int seedVersion = 1;
  static const String _seedAsset = 'assets/seed/test_history.json';

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _results =>
      _userDoc.collection('testResults');

  Stream<List<TestResult>> watchResults() {
    return _results
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(TestResult.fromSnapshot).toList());
  }

  Future<void> addResult(TestResult result) =>
      _results.add(result.toMap());

  Future<void> deleteResult(String id) => _results.doc(id).delete();

  // --- one-time import of the Testblatt ------------------------------------

  /// Whether the bundled history has already been written for this user.
  bool hasImportedSeed(Map<String, dynamic>? userData) =>
      coerceSeedVersion(userData) >= seedVersion;

  /// How many results the bundled history holds, or 0 when there is none.
  ///
  /// The seed is a real athlete's data and is kept out of version control,
  /// so a fresh clone has no asset and must simply not offer the import.
  Future<int> seedSize() async {
    try {
      final raw = await rootBundle.loadString(_seedAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return (decoded['tests'] as List?)?.length ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static int coerceSeedVersion(Map<String, dynamic>? userData) {
    final value = userData?['testSeedVersion'];
    return value is int ? value : 0;
  }

  /// Writes the results parsed from `Testblatt_Tom.xlsx` into the athlete's
  /// own subcollection, then records the version so it cannot run twice.
  ///
  /// Returns how many results were written. Everything goes in batches with
  /// the marker set in the last one, so an interrupted import does not leave
  /// the user marked as done with only half the history.
  Future<int> importSeedHistory() async {
    final raw = await rootBundle.loadString(_seedAsset);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (decoded['tests'] as List?) ?? const [];

    final results = entries
        .whereType<Map>()
        .map((e) => TestResult.fromMap(Map<String, dynamic>.from(e)))
        .where((r) => r.disciplineId.isNotEmpty && r.value > 0)
        .toList();

    if (results.isEmpty) return 0;

    // Firestore caps a batch at 500 writes; the marker needs a slot too.
    const chunkSize = 400;
    for (var start = 0; start < results.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, results.length);
      final batch = _firestore.batch();

      for (final result in results.sublist(start, end)) {
        batch.set(_results.doc(), result.toMap());
      }

      final isLast = end >= results.length;
      if (isLast) {
        batch.set(
          _userDoc,
          {'testSeedVersion': seedVersion},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    }

    return results.length;
  }
}
