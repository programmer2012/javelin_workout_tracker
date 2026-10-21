import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:javelin_workout_tracker/utils/coerce.dart';

/// Characters an invite code is built from.
///
/// Excludes the pairs that get misread when a code is spoken across a gym or
/// typed from a photo: `0`/`O` and `1`/`I`/`L`.
const String inviteCodeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

const int inviteCodeLength = 6;

String generateInviteCode(Random random) {
  return List.generate(
    inviteCodeLength,
    (_) => inviteCodeAlphabet[random.nextInt(inviteCodeAlphabet.length)],
  ).join();
}

/// Accepts what a user actually types — lower case, spaces, dashes — and
/// returns the canonical form, or `null` if it cannot be a code.
///
/// Characters outside [inviteCodeAlphabet] are rejected rather than repaired:
/// a typed `O` could have been meant as `0`, which is equally not in the
/// alphabet, so there is nothing to correct it to.
String? normaliseInviteCode(String input) {
  final cleaned = input.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');

  if (cleaned.length != inviteCodeLength) return null;
  for (final character in cleaned.split('')) {
    if (!inviteCodeAlphabet.contains(character)) return null;
  }
  return cleaned;
}

/// A coach's shareable code. Stored at `coachInvites/{code}`; the code itself
/// is the secret, and the document holds only what an athlete needs to see
/// before accepting.
class CoachInvite {
  final String code;
  final String coachUid;
  final String coachName;

  const CoachInvite({
    required this.code,
    required this.coachUid,
    required this.coachName,
  });

  factory CoachInvite.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> s) {
    final data = s.data() ?? {};
    return CoachInvite(
      code: s.id,
      coachUid: data['coachUid'] as String? ?? '',
      coachName: (data['coachName'] as String?)?.trim().isNotEmpty == true
          ? data['coachName'] as String
          : 'Your coach',
    );
  }

  Map<String, dynamic> toMap() => {
        'coachUid': coachUid,
        'coachName': coachName,
        'createdAt': Timestamp.now(),
      };
}

/// An athlete as seen by their coach.
class Athlete {
  final String uid;
  final String name;
  final String? photoUrl;

  const Athlete({required this.uid, required this.name, this.photoUrl});

  factory Athlete.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> s) {
    final data = s.data() ?? {};
    final name = (data['username'] as String?)?.trim();
    final photoUrl = (data['photoUrl'] as String?)?.trim();
    return Athlete(
      uid: s.id,
      name: (name == null || name.isEmpty) ? 'Athlete' : name,
      photoUrl: (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl,
    );
  }
}

/// A coach the athlete has granted access to, as shown on the athlete's side.
class CoachRef {
  final String uid;
  final String name;
  final DateTime? linkedAt;

  const CoachRef({required this.uid, required this.name, this.linkedAt});
}

/// Reads the `coaches` display map off a user document.
///
/// The queryable `coachUids` array is the source of truth for access; this
/// map only carries names, so the athlete can see who they granted access to
/// without being able to read the coach's own profile document.
List<CoachRef> coachesFrom(Map<String, dynamic>? userData) {
  final raw = userData?['coaches'];
  if (raw is! Map) return [];

  final coaches = <CoachRef>[];
  raw.forEach((key, value) {
    final uid = key.toString();
    if (uid.isEmpty) return;
    final details = value is Map ? Map<String, dynamic>.from(value) : const {};
    final name = (details['name'] as String?)?.trim();
    coaches.add(CoachRef(
      uid: uid,
      name: (name == null || name.isEmpty) ? 'Coach' : name,
      linkedAt: coerceDate(details['linkedAt']),
    ));
  });

  coaches.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return coaches;
}

/// The uids an athlete has granted coaching access to.
List<String> coachUidsFrom(Map<String, dynamic>? userData) {
  final raw = userData?['coachUids'];
  if (raw is! List) return [];
  return raw.whereType<String>().where((uid) => uid.isNotEmpty).toList();
}
