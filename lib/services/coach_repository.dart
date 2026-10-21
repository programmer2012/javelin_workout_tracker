import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:javelin_workout_tracker/models/coach.dart';
import 'package:javelin_workout_tracker/models/workout.dart';

/// Coaching links between users.
///
/// Access always flows one way and is always granted by the athlete: a coach
/// publishes an invite code, the athlete redeems it, and that writes the
/// coach's uid onto the *athlete's* own document. A coach can never add
/// themselves to anyone, because the security rules only let a user write
/// their own document.
///
/// Two fields carry the link, both on the athlete's document:
///  * `coachUids` — a plain array, so a coach can query for their athletes.
///  * `coaches` — a uid-keyed map of display details, so the athlete can see
///    who has access without being able to read a coach's profile document.
class CoachRepository {
  CoachRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    Random? random,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _random = random ?? Random.secure();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final Random _random;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('coachInvites');

  // --- being a coach ------------------------------------------------------

  /// The signed-in user's invite code, creating one on first use.
  ///
  /// The code is stored on the user document as well as being the id of the
  /// invite, so showing it again costs one read instead of a query.
  Future<String> ensureInviteCode() async {
    final userDoc = _users.doc(_uid);
    final snapshot = await userDoc.get();
    final existing = (snapshot.data()?['coachCode'] as String?)?.trim();
    if (existing != null && existing.isNotEmpty) return existing;

    final name = (snapshot.data()?['username'] as String?)?.trim();
    final code = await _reserveUnusedCode(
      coachName: (name == null || name.isEmpty) ? 'Your coach' : name,
    );

    await userDoc.set({'coachCode': code}, SetOptions(merge: true));
    return code;
  }

  /// Picks a code that is not already taken.
  ///
  /// Six characters from a 31 character alphabet is ~887 million codes, so a
  /// collision is vanishingly unlikely — but it is cheap to check, and a
  /// silent collision would hand one coach another's athletes.
  Future<String> _reserveUnusedCode({required String coachName}) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateInviteCode(_random);
      final doc = _invites.doc(code);

      final taken = (await doc.get()).exists;
      if (taken) continue;

      await doc.set(
        CoachInvite(code: code, coachUid: _uid, coachName: coachName).toMap(),
      );
      return code;
    }
    throw StateError('Could not allocate an invite code, please try again');
  }

  /// The athletes who have granted the signed-in user coaching access.
  Stream<List<Athlete>> watchAthletes() {
    return _users
        .where('coachUids', arrayContains: _uid)
        .snapshots()
        .map((snap) => snap.docs.map(Athlete.fromSnapshot).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())));
  }

  /// One athlete's finished workouts, newest first.
  Stream<List<Workout>> watchWorkoutsOf(String athleteUid) {
    return _users
        .doc(athleteUid)
        .collection('workouts')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Workout.fromSnapshot).toList());
  }

  // --- having a coach -----------------------------------------------------

  /// Grants the coach behind [rawCode] read access to the signed-in user.
  ///
  /// Returns the coach's display name. Throws a [CoachLinkException] with a
  /// message meant for the user when the code cannot be used.
  Future<String> addCoachByCode(String rawCode) async {
    final code = normaliseInviteCode(rawCode);
    if (code == null) {
      throw const CoachLinkException('That is not a valid coach code.');
    }

    final snapshot = await _invites.doc(code).get();
    if (!snapshot.exists) {
      throw const CoachLinkException('No coach found for that code.');
    }

    final invite = CoachInvite.fromSnapshot(snapshot);
    if (invite.coachUid.isEmpty) {
      throw const CoachLinkException('That code is no longer usable.');
    }
    if (invite.coachUid == _uid) {
      throw const CoachLinkException('That is your own coach code.');
    }

    await _users.doc(_uid).set({
      'coachUids': FieldValue.arrayUnion([invite.coachUid]),
      'coaches': {
        invite.coachUid: {
          'name': invite.coachName,
          'linkedAt': Timestamp.now(),
        },
      },
    }, SetOptions(merge: true));

    return invite.coachName;
  }

  /// Revokes a coach's access. Both fields are cleared together: leaving a
  /// uid in `coachUids` would keep the access the rules grant.
  Future<void> removeCoach(String coachUid) {
    return _users.doc(_uid).set({
      'coachUids': FieldValue.arrayRemove([coachUid]),
      'coaches': {coachUid: FieldValue.delete()},
    }, SetOptions(merge: true));
  }
}

/// A failure with a message that can be shown to the user as-is.
class CoachLinkException implements Exception {
  final String message;

  const CoachLinkException(this.message);

  @override
  String toString() => message;
}
