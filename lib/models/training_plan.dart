import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:javelin_workout_tracker/models/season_plan.dart';
import 'package:javelin_workout_tracker/utils/coerce.dart';

/// A plan a coach publishes and assigns to athletes.
///
/// Stored as one document in `plans/{planId}`. The whole season is about
/// 40 KB, so it fits a single document comfortably and a plan loads in one
/// read with no partial states.
///
/// The app only ever *reads* [content]; plans are written by the desktop
/// importer, which parses the coach's spreadsheet. The one field the app
/// writes is [athleteUids], when a coach assigns or unassigns someone.
class TrainingPlan {
  final String id;
  final String ownerUid;
  final String ownerName;
  final String name;

  /// Athletes allowed to read this plan. The security rules check this
  /// list, so removing a uid genuinely revokes access.
  final List<String> athleteUids;

  final DateTime? updatedAt;
  final SeasonPlan content;

  const TrainingPlan({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.content,
    this.ownerName = '',
    this.athleteUids = const [],
    this.updatedAt,
  });

  factory TrainingPlan.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) =>
      TrainingPlan.fromMap(snapshot.data() ?? {}, id: snapshot.id);

  /// Split out from [fromSnapshot] so the parsing can be tested without a
  /// Firestore instance.
  factory TrainingPlan.fromMap(Map<String, dynamic> data,
      {required String id}) {
    final rawAthletes = data['athleteUids'];
    final name = (data['name'] as String?)?.trim();

    return TrainingPlan(
      id: id,
      ownerUid: data['ownerUid'] as String? ?? '',
      ownerName: (data['ownerName'] as String?)?.trim() ?? '',
      name: (name == null || name.isEmpty) ? 'Trainingsplan' : name,
      athleteUids: rawAthletes is List
          ? rawAthletes.whereType<String>().where((u) => u.isNotEmpty).toList()
          : const [],
      updatedAt: coerceDate(data['updatedAt']),
      // The plan body uses exactly the same shape as the bundled asset, so
      // one parser serves both and the importer needs no second format.
      content: SeasonPlan.fromMap(data),
    );
  }

  bool isAssignedTo(String uid) => athleteUids.contains(uid);

  int get weekCount => content.weeks.length;
}

/// Where the plan currently on screen came from.
enum PlanSource {
  /// Assigned by a coach and read from Firestore.
  coach,

  /// The plan compiled into the app, used when no coach has assigned one.
  bundled,
}

/// The plan to show, plus where it came from.
class ResolvedPlan {
  final SeasonPlan plan;
  final PlanSource source;

  /// Null for [PlanSource.bundled].
  final TrainingPlan? assigned;

  const ResolvedPlan({
    required this.plan,
    required this.source,
    this.assigned,
  });

  String get label => switch (source) {
        PlanSource.coach => assigned?.name ?? 'Trainingsplan',
        PlanSource.bundled => 'Eigener Plan',
      };
}
