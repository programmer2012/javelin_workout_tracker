import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/test_result.dart';

TestResult _r(String discipline, String date, double value) => TestResult(
      id: date,
      disciplineId: discipline,
      date: DateTime.parse(date),
      value: value,
    );


/// The seed files hold a real athlete's data and are gitignored, so a fresh
/// clone has none. Skip rather than fail: these tests verify the parse of
/// data that is simply not present there.
final _seedMissing = !File('assets/seed/test_history.json').existsSync();
const _skipReason = 'seed data not in this checkout (gitignored)';

void main() {
  const throwing = Discipline(id: 'x', label: 'Wurf', unit: 'm');
  const sprint = Discipline(
    id: 's',
    label: 'Sprint',
    unit: 's',
    lowerIsBetter: true,
  );

  group('personalBest', () {
    test('takes the largest value when higher is better', () {
      final best = personalBest([
        _r('x', '2026-01-01', 60),
        _r('x', '2026-02-01', 77.39),
        _r('x', '2026-03-01', 70),
      ], throwing);

      expect(best!.value, 77.39);
    });

    test('takes the smallest value for a time', () {
      // The bug this guards: a sprint PB is the fastest run, not the slowest.
      final best = personalBest([
        _r('s', '2026-01-01', 4.01),
        _r('s', '2026-02-01', 3.17),
        _r('s', '2026-03-01', 3.43),
      ], sprint);

      expect(best!.value, 3.17);
    });

    test('an empty history has no best', () {
      expect(personalBest([], throwing), isNull);
    });

    test('a single result is the best', () {
      expect(personalBest([_r('x', '2026-01-01', 60)], throwing)!.value, 60);
    });
  });

  group('isPersonalBest', () {
    final history = [
      _r('x', '2026-01-01', 70),
      _r('x', '2026-02-01', 77.39),
    ];

    test('beating the best counts', () {
      expect(isPersonalBest(78.0, history, throwing), isTrue);
    });

    test('equalling the best does not', () {
      expect(isPersonalBest(77.39, history, throwing), isFalse);
    });

    test('a worse result does not', () {
      expect(isPersonalBest(60.0, history, throwing), isFalse);
    });

    test('the first result always counts', () {
      expect(isPersonalBest(1.0, const [], throwing), isTrue);
    });

    test('for a time, faster counts and slower does not', () {
      final times = [_r('s', '2026-01-01', 3.43)];
      expect(isPersonalBest(3.17, times, sprint), isTrue);
      expect(isPersonalBest(3.90, times, sprint), isFalse);
    });
  });

  group('TestResult serialisation', () {
    test('round trips through a map', () {
      final date = DateTime(2026, 5, 24);
      final result = TestResult(
        id: '',
        disciplineId: 'competition',
        date: date,
        value: 77.39,
        note: 'Halle',
      );

      final map = result.toMap();
      expect(map['date'], Timestamp.fromDate(date));

      final restored = TestResult.fromMap(map, id: 'doc1');
      expect(restored.id, 'doc1');
      expect(restored.disciplineId, 'competition');
      expect(restored.date, date);
      expect(restored.value, 77.39);
      expect(restored.note, 'Halle');
      expect(restored.seasonBest, isFalse);
    });

    test('reads the ISO dates and blank notes used by the seed file', () {
      final restored = TestResult.fromMap({
        'discipline': 'shot4_forward',
        'date': DateTime.parse('2026-03-21').millisecondsSinceEpoch,
        'value': '20.34',
        'seasonBest': true,
        'note': '   ',
      });

      expect(restored.date, DateTime.parse('2026-03-21'));
      expect(restored.value, 20.34);
      expect(restored.seasonBest, isTrue);
      expect(restored.note, isNull);
    });
  });

  group('bundled seed history', () {
    // Reads the asset straight off disk: if the parse is ever regenerated
    // wrongly, that should fail here rather than on Tom's phone.
    late Map<String, dynamic> seed;

    setUpAll(() {
      final file = File('assets/seed/test_history.json');
      seed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('every result parses and has a known discipline', () {
      final entries = (seed['tests'] as List).cast<Map<String, dynamic>>();
      expect(entries, hasLength(98));

      for (final entry in entries) {
        final result = TestResult.fromMap(entry);
        expect(result.value, greaterThan(0), reason: '$entry');
        expect(
          disciplineById(result.disciplineId),
          isNotNull,
          reason: 'unknown discipline ${result.disciplineId}',
        );
        expect(result.date.year, inInclusiveRange(2020, 2026));
      }
    });

    test('the known personal bests come out of the data', () {
      final entries = (seed['tests'] as List).cast<Map<String, dynamic>>();
      final results = entries.map(TestResult.fromMap).toList();

      List<TestResult> forId(String id) =>
          results.where((r) => r.disciplineId == id).toList();

      expect(
        personalBest(forId('competition'), disciplineById('competition')!)!
            .value,
        77.39,
      );
      // Lower is better here, so this is the fastest of the flying times.
      expect(
        personalBest(
          forId('sprint_30m_flying'),
          disciplineById('sprint_30m_flying')!,
        )!
            .value,
        3.17,
      );
      expect(
        personalBest(forId('bench_press'), disciplineById('bench_press')!)!
            .value,
        147,
      );
    });

    test('the two sprint protocols stay apart', () {
      final entries = (seed['tests'] as List).cast<Map<String, dynamic>>();
      final flying =
          entries.where((e) => e['discipline'] == 'sprint_30m_flying');
      final standing =
          entries.where((e) => e['discipline'] == 'sprint_30m_standing');

      expect(flying, hasLength(4));
      expect(standing, hasLength(2));
      // Every flying time must be faster than every standing one, which is
      // the physical check that the split landed the right way round.
      final slowestFlying =
          flying.map((e) => e['value'] as num).reduce((a, b) => a > b ? a : b);
      final fastestStanding = standing
          .map((e) => e['value'] as num)
          .reduce((a, b) => a < b ? a : b);
      expect(slowestFlying, lessThan(fastestStanding));
    });
  }, skip: _seedMissing ? _skipReason : null);
}
