import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/season_plan.dart';
import 'package:javelin_workout_tracker/models/training_plan.dart';


/// The seed files hold a real athlete's data and are gitignored, so a fresh
/// clone has none. Skip rather than fail: these tests verify the parse of
/// data that is simply not present there.
final _seedMissing = !File('assets/seed/season_plan.json').existsSync();
const _skipReason = 'seed data not in this checkout (gitignored)';

void main() {
  late Map<String, dynamic> planBody;

  setUpAll(() {
    if (_seedMissing) {
      planBody = const {};
      return;
    }
    // The importer writes exactly this shape into plans/{id} — verified by
    // diffing its output against the bundled asset — so parsing the asset
    // with the plan metadata around it exercises the real coach path.
    planBody = jsonDecode(
      File('assets/seed/season_plan.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  Map<String, dynamic> planDoc({
    String owner = 'coach-1',
    List<String> athletes = const ['athlete-1'],
    String name = 'TP Speer Tom/Alex 2026/27',
    Object? updatedAt,
  }) =>
      {
        ...planBody,
        'ownerUid': owner,
        'ownerName': 'Tom',
        'name': name,
        'athleteUids': athletes,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  group('TrainingPlan', () {
    test('parses a coach plan document, body and metadata', () {
      final plan = TrainingPlan.fromMap(planDoc(), id: 'plan-2026-27');

      expect(plan.id, 'plan-2026-27');
      expect(plan.ownerUid, 'coach-1');
      expect(plan.ownerName, 'Tom');
      expect(plan.name, 'TP Speer Tom/Alex 2026/27');
      expect(plan.athleteUids, ['athlete-1']);

      // The body must come through as a fully usable season.
      expect(plan.weekCount, 43);
      expect(plan.content.season, '2026/27');
      expect(plan.content.sollTotal(LoadCategory.at), 19650);
      expect(plan.content.split.blocks, isNotEmpty);
      expect(plan.content.sprint.forWeek(5)?.label, '4–9');
    });

    test('assignment is by uid', () {
      final plan = TrainingPlan.fromMap(
        planDoc(athletes: ['a', 'b']),
        id: 'p',
      );

      expect(plan.isAssignedTo('a'), isTrue);
      expect(plan.isAssignedTo('b'), isTrue);
      expect(plan.isAssignedTo('c'), isFalse);
    });

    test('a malformed athlete list grants nobody access', () {
      // Anything but a clean list of non-empty strings must not be read as
      // an assignment — the rules check this same field.
      for (final bad in [null, 'athlete-1', <dynamic>[], [42, '', null]]) {
        final plan = TrainingPlan.fromMap(
          {...planBody, 'ownerUid': 'c', 'athleteUids': bad},
          id: 'p',
        );
        expect(plan.athleteUids.where((u) => u.isNotEmpty), isEmpty,
            reason: '$bad');
        expect(plan.isAssignedTo('athlete-1'), isFalse, reason: '$bad');
      }
    });

    test('falls back to a usable name when none is stored', () {
      for (final bad in [null, '', '   ']) {
        final plan = TrainingPlan.fromMap(
          {...planBody, 'ownerUid': 'c', 'name': bad},
          id: 'p',
        );
        expect(plan.name, 'Trainingsplan');
      }
    });

    test('reads updatedAt as a Timestamp or an ISO string', () {
      final date = DateTime(2026, 10, 22);

      expect(
        TrainingPlan.fromMap(
          planDoc(updatedAt: Timestamp.fromDate(date)),
          id: 'p',
        ).updatedAt,
        date,
      );
      expect(
        TrainingPlan.fromMap(
          planDoc(updatedAt: '2026-10-22'),
          id: 'p',
        ).updatedAt,
        date,
      );
      expect(TrainingPlan.fromMap(planDoc(), id: 'p').updatedAt, isNull);
    });

    test('an empty document parses without throwing', () {
      // A half-written plan must not crash the athlete's app.
      final plan = TrainingPlan.fromMap(const {}, id: 'p');
      expect(plan.weekCount, 0);
      expect(plan.athleteUids, isEmpty);
      expect(plan.ownerUid, '');
    });
  }, skip: _seedMissing ? _skipReason : null);

  group('ResolvedPlan', () {
    test('names the coach plan it is showing', () {
      final assigned = TrainingPlan.fromMap(planDoc(), id: 'p');
      final resolved = ResolvedPlan(
        plan: assigned.content,
        source: PlanSource.coach,
        assigned: assigned,
      );

      expect(resolved.label, 'TP Speer Tom/Alex 2026/27');
      expect(resolved.plan.weeks, hasLength(43));
    });

    test('labels the bundled plan distinctly', () {
      final resolved = ResolvedPlan(
        plan: SeasonPlan.fromMap(planBody),
        source: PlanSource.bundled,
      );

      expect(resolved.label, 'Eigener Plan');
      expect(resolved.assigned, isNull);
    });
  }, skip: _seedMissing ? _skipReason : null);
}
