import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/season_plan.dart';


/// The seed files hold a real athlete's data and are gitignored, so a fresh
/// clone has none. Skip rather than fail: these tests verify the parse of
/// data that is simply not present there.
final _seedMissing = !File('assets/seed/season_plan.json').existsSync();
const _skipReason = 'seed data not in this checkout (gitignored)';

void main() {
  late SeasonPlan plan;

  setUpAll(() {
    // Groups that need the seed are skipped below; the rest must still run,
    // so this cannot throw when the file is absent.
    if (_seedMissing) {
      plan = SeasonPlan.empty;
      return;
    }
    final file = File('assets/seed/season_plan.json');
    plan = SeasonPlan.fromMap(
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>,
    );
  });

  group('bundled season plan', () {
    test('holds the whole season in training order', () {
      expect(plan.season, '2026/27');
      // 44-53 then 1-33: the season crosses the new year.
      expect(plan.weeks, hasLength(43));
      expect(plan.weeks.first.week, 44);
      expect(plan.weeks.last.week, 33);
      expect(
        plan.weeks.map((w) => w.week).toList(),
        [...List.generate(10, (i) => 44 + i), ...List.generate(33, (i) => i + 1)],
      );
    });

    test('mondays run forwards with no gaps', () {
      for (var i = 1; i < plan.weeks.length; i++) {
        // Calendar days, not a Duration: the season crosses two clock
        // changes and a local-time difference reports 6 across the spring
        // one.
        final gap = calendarDaysBetween(
          plan.weeks[i - 1].monday,
          plan.weeks[i].monday,
        );
        expect(gap, 7, reason: 'between week ${plan.weeks[i - 1].week} '
            'and ${plan.weeks[i].week}');
      }
    });

    test('reproduces the totals the spreadsheet computes itself', () {
      // These are the Summe row from the Kennzahlen sheet. A footnote row
      // once overwrote week 53 with zeros, which showed up here as totals
      // matching the sheet's "ohne Wo 53" figures instead.
      expect(plan.sollTotal(LoadCategory.at), 19650);
      expect(plan.sollTotal(LoadCategory.kraft), 7560);
      expect(plan.sollTotal(LoadCategory.spezKt), 9260);
      expect(plan.sollTotal(LoadCategory.wuerfe), 6370);
    });

    test('week 53 survived, with its own targets', () {
      final week53 = plan.weeks.firstWhere((w) => w.week == 53);
      expect(week53.sollFor(LoadCategory.kraft), 300);
      expect(week53.sollFor(LoadCategory.wuerfe), 250);
      expect(week53.days, isNotEmpty);
    });

    test('every week carries a phase and a full set of session text', () {
      for (final week in plan.weeks) {
        expect(week.phase, isNotEmpty, reason: 'week ${week.week}');
        expect(week.days, isNotEmpty, reason: 'week ${week.week}');
        expect(week.monday.year, inInclusiveRange(2026, 2027));
      }
    });

    test('competition notes survive the parse', () {
      final notes = plan.weeks.map((w) => w.note).where((n) => n.isNotEmpty);
      expect(notes, isNotEmpty);
      expect(notes.any((n) => n.contains('DM')), isTrue);
    });
  }, skip: _seedMissing ? _skipReason : null);

  group('week lookup', () {
    test('finds the week containing a date, inclusive at both ends', () {
      final first = plan.weeks.first;
      expect(plan.weekFor(first.monday)?.week, first.week);
      expect(plan.weekFor(first.sunday)?.week, first.week);
      // Time of day must not matter.
      expect(
        plan.weekFor(first.monday.add(const Duration(hours: 23)))?.week,
        first.week,
      );
    });

    test('the week around the spring clock change keeps all seven days', () {
      // 29.03.2027 is the European daylight-saving change; the Sunday before
      // it used to fall out of its own week.
      final march = plan.weeks.firstWhere(
        (w) => w.monday.year == 2027 && w.monday.month == 3 && w.monday.day == 22,
      );
      for (var i = 0; i <= 6; i++) {
        final day = DateTime(2027, 3, 22 + i);
        expect(march.containsDate(day), isTrue, reason: '\$day');
        expect(plan.weekFor(day)?.week, march.week, reason: '\$day');
      }
      expect(march.containsDate(DateTime(2027, 3, 29)), isFalse);
      expect(march.sunday, DateTime(2027, 3, 28));
    });

    test('a date outside the season has no week', () {
      expect(plan.weekFor(DateTime(2020, 1, 1)), isNull);
      expect(plan.weekFor(DateTime(2030, 1, 1)), isNull);
    });

    test('closestTo still returns something outside the season', () {
      // The page should never be blank just because the season has not
      // started or is over.
      expect(plan.closestTo(DateTime(2020, 1, 1))?.week, 44);
      expect(plan.closestTo(DateTime(2030, 1, 1))?.week, 33);
      expect(plan.closestTo(plan.weeks[5].monday)?.week, plan.weeks[5].week);
    });

    test('keys are unique and derived from the Monday', () {
      final keys = plan.weeks.map((w) => w.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
      expect(plan.weeks.first.key, '2026-10-26');
    });
  }, skip: _seedMissing ? _skipReason : null);

  group('WeekActuals', () {
    test('round trips through a map', () {
      const actuals = WeekActuals(
        values: {'at': 750, 'kraft': 0, 'wuerfe': 120.5},
        note: 'krank',
      );

      final restored = WeekActuals.fromMap(actuals.toMap());
      expect(restored.forCategory(LoadCategory.at), 750);
      expect(restored.forCategory(LoadCategory.wuerfe), 120.5);
      expect(restored.note, 'krank');
    });

    test('a missing category reads as zero, not an error', () {
      const actuals = WeekActuals(values: {'at': 100});
      expect(actuals.forCategory(LoadCategory.kraft), 0);
      expect(actuals.forExtra(ExtraMeasure.sprint), 0);
    });

    test('isEmpty separates "nothing entered" from "entered zero"', () {
      expect(WeekActuals.empty.isEmpty, isTrue);
      expect(const WeekActuals(values: {'at': 0}).isEmpty, isTrue);
      expect(const WeekActuals(values: {'at': 1}).isEmpty, isFalse);
      expect(const WeekActuals(note: 'x').isEmpty, isFalse);
    });

    test('reads string numbers, as a hand-edited document might hold', () {
      final restored = WeekActuals.fromMap({'at': '750', 'kraft': '12,5'});
      expect(restored.forCategory(LoadCategory.at), 750);
      expect(restored.forCategory(LoadCategory.kraft), 12.5);
    });
  });

  group('completion', () {
    test('is the plain ratio', () {
      expect(completionFraction(300, 600), 0.5);
      expect(completionFraction(600, 600), 1.0);
    });

    test('a week with no target cannot divide by zero', () {
      expect(completionFraction(0, 0), 0);
      expect(completionFraction(100, 0), 0);
    });

    test('overshooting is reported, not hidden', () {
      expect(completionFraction(900, 600), 1.5);
    });
  });

  group('AT-Split reference', () {
    test('every exercise block parsed with its exercises', () {
      final titles = plan.split.blocks
          .where((b) => b.exercises.isNotEmpty)
          .map((b) => b.title.split(' ').first)
          .toList();

      expect(titles, containsAll(['OK-A', 'UK-A', 'OK-B', 'UK-B']));
      expect(
        plan.split.blocks.fold<int>(0, (n, b) => n + b.exercises.length),
        40,
      );
    });

    test('exercises keep their machine, type and hint', () {
      final okA = plan.split.blocks.firstWhere((b) => b.title.startsWith('OK-A'));
      final first = okA.exercises.first;

      expect(first.nr, 1);
      expect(first.name, 'Brustpresse');
      expect(first.equipment, contains('Brustpresse'));
      expect(first.type, 'H');
      expect(first.hint, contains('Schulterblätter'));
      // Only H, N and I are used; anything else means a column shifted.
      for (final block in plan.split.blocks) {
        for (final exercise in block.exercises) {
          expect(
            exercise.type == null || ['H', 'N', 'I'].contains(exercise.type),
            isTrue,
            reason: '\${block.title}: \${exercise.name} -> \${exercise.type}',
          );
        }
      }
    });

    test('the reduced splits carry sets instead of a type', () {
      final reduced =
          plan.split.blocks.firstWhere((b) => b.title == 'Split-OK reduziert');
      expect(reduced.exercises, hasLength(4));
      expect(reduced.exercises.first.sets, '2 × 10');
      expect(reduced.exercises.first.type, isNull);
    });

    test('rule-only blocks are kept as notes, not dropped', () {
      final rules = plan.split.blocks.where((b) => b.isRulesOnly);
      expect(rules, isNotEmpty);
      expect(rules.any((b) => b.notes.any((n) => n.contains('Langhantel'))),
          isTrue);
    });

    test('the progression table covers the build-up weeks', () {
      expect(plan.split.progression.map((p) => p.week),
          [44, 45, 46, 47, 48, 49, 50]);

      final week49 = plan.split.forWeek(49)!;
      expect(week49.label, 'AT-Spitze');
      expect(week49.rir, '1');
      // Kraft reps plus medball must reconcile with the week's AT total.
      expect(week49.kraftReps + week49.medball, week49.atTotal);
      expect(week49.atTotal, 1502);
      expect(week49.soll, 1500);
    });

    test('weeks outside the build-up have no progression row', () {
      expect(plan.split.forWeek(20), isNull);
      expect(plan.split.forWeek(1), isNull);
    });
  }, skip: _seedMissing ? _skipReason : null);

  group('Sprint & Sprung reference', () {
    test('every season week is covered by exactly one block', () {
      for (final week in plan.weeks) {
        final matching =
            plan.sprint.blocks.where((b) => b.covers(week.week)).toList();
        expect(matching, hasLength(1), reason: 'week \${week.week}');
      }
    });

    test('blocks keep their goal, contents and volume', () {
      final main = plan.sprint.forWeek(5)!;
      expect(main.label, '4–9');
      expect(main.goal, contains('Kraft in Tempo'));
      expect(main.contents, contains('Reaktionsstarts'));
      expect(main.volume, contains('BK'));
    });

    test('week ranges that wrap the new year resolve in season order', () {
      // "50-53" must not swallow weeks 1-33 by counting numerically.
      final winter = plan.sprint.blocks.firstWhere((b) => b.label == '50–53');
      expect(winter.weeks, [50, 51, 52, 53]);

      final january = plan.sprint.blocks.firstWhere((b) => b.label == '1–3');
      expect(january.weeks, [1, 2, 3]);
    });

    test('the rules survived', () {
      expect(plan.sprint.rules, hasLength(5));
      expect(plan.sprint.rules.any((r) => r.contains('Tiefsprünge')), isTrue);
    });
  }, skip: _seedMissing ? _skipReason : null);
}
