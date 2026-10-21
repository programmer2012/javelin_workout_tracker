import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/coach.dart';

void main() {
  group('generateInviteCode', () {
    test('produces a code of the right length from the safe alphabet', () {
      final random = Random(42);

      for (var i = 0; i < 200; i++) {
        final code = generateInviteCode(random);
        expect(code.length, inviteCodeLength);
        for (final character in code.split('')) {
          expect(inviteCodeAlphabet.contains(character), isTrue,
              reason: '$code contains $character');
        }
      }
    });

    test('never emits characters that get misread', () {
      final random = Random(7);

      for (var i = 0; i < 200; i++) {
        // 0/O and 1/I/L are the pairs people get wrong reading a code out.
        expect(generateInviteCode(random), isNot(matches(RegExp(r'[01OIL]'))));
      }
    });

    test('a generated code round trips through normalisation', () {
      final random = Random(99);

      for (var i = 0; i < 50; i++) {
        final code = generateInviteCode(random);
        expect(normaliseInviteCode(code), code);
      }
    });
  });

  group('normaliseInviteCode', () {
    test('accepts what people actually type', () {
      expect(normaliseInviteCode('abc234'), 'ABC234');
      expect(normaliseInviteCode('  ABC234  '), 'ABC234');
      expect(normaliseInviteCode('ABC-234'), 'ABC234');
      expect(normaliseInviteCode('abc 234'), 'ABC234');
    });

    test('rejects the wrong length', () {
      expect(normaliseInviteCode(''), isNull);
      expect(normaliseInviteCode('ABC23'), isNull);
      expect(normaliseInviteCode('ABC2345'), isNull);
    });

    test('rejects look-alike characters rather than guessing', () {
      // A typed O could have been meant as 0, which is equally not in the
      // alphabet — there is no correct repair, so refuse.
      expect(normaliseInviteCode('ABC2O4'), isNull);
      expect(normaliseInviteCode('ABC2I4'), isNull);
      expect(normaliseInviteCode('ABC2L4'), isNull);
      expect(normaliseInviteCode('ABC204'), isNull);
      expect(normaliseInviteCode('ABC214'), isNull);
    });

    test('rejects punctuation and non-alphabet symbols', () {
      expect(normaliseInviteCode('ABC2!4'), isNull);
      expect(normaliseInviteCode('AB/234'), isNull);
    });
  });

  group('coachUidsFrom', () {
    test('reads the granted uids', () {
      expect(
        coachUidsFrom({
          'coachUids': ['coach-a', 'coach-b']
        }),
        ['coach-a', 'coach-b'],
      );
    });

    test('a missing, empty or malformed field grants nobody access', () {
      expect(coachUidsFrom(null), isEmpty);
      expect(coachUidsFrom({}), isEmpty);
      expect(coachUidsFrom({'coachUids': 'coach-a'}), isEmpty);
      expect(coachUidsFrom({'coachUids': []}), isEmpty);
      // Non-strings and blanks would never match a real uid anyway, but
      // letting them through would misreport who has access.
      expect(
        coachUidsFrom({
          'coachUids': ['coach-a', '', 42, null]
        }),
        ['coach-a'],
      );
    });
  });

  group('coachesFrom', () {
    test('reads the display map, sorted by name', () {
      final coaches = coachesFrom({
        'coaches': {
          'uid-2': {'name': 'Zoe', 'linkedAt': 1700000000000},
          'uid-1': {'name': 'Andreas'},
        }
      });

      expect(coaches.map((c) => c.name), ['Andreas', 'Zoe']);
      expect(coaches.first.uid, 'uid-1');
      expect(coaches.first.linkedAt, isNull);
      expect(
        coaches.last.linkedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('reads a Timestamp linkedAt', () {
      final date = DateTime(2026, 5, 4);
      final coaches = coachesFrom({
        'coaches': {
          'uid-1': {'name': 'Andreas', 'linkedAt': Timestamp.fromDate(date)},
        }
      });

      expect(coaches.single.linkedAt, date);
    });

    test('falls back to a label when the name is missing', () {
      final coaches = coachesFrom({
        'coaches': {
          'uid-1': {'linkedAt': 1700000000000},
          'uid-2': {'name': '   '},
        }
      });

      expect(coaches.map((c) => c.name), ['Coach', 'Coach']);
    });

    test('a missing or malformed field lists nobody', () {
      expect(coachesFrom(null), isEmpty);
      expect(coachesFrom({}), isEmpty);
      expect(coachesFrom({'coaches': 'nonsense'}), isEmpty);
    });
  });
}
