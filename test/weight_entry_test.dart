import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:javelin_workout_tracker/models/weight_entry.dart';

void main() {
  group('weightHistoryFromDynamic', () {
    test('reads epoch millis entries and sorts them oldest first', () {
      final entries = weightHistoryFromDynamic([
        {'weight': 84.0, 'date': DateTime(2026, 3, 10).millisecondsSinceEpoch},
        {'weight': 82.5, 'date': DateTime(2026, 1, 5).millisecondsSinceEpoch},
      ]);

      // Sorted on read, so the chart can plot the list as it comes.
      expect(entries.map((e) => e.weight), [82.5, 84.0]);
      expect(entries.first.date, DateTime(2026, 1, 5));
    });

    test('accepts a Timestamp date and a comma decimal weight', () {
      final entries = weightHistoryFromDynamic([
        {'weight': '81,4', 'date': Timestamp.fromDate(DateTime(2026, 2, 2))},
      ]);

      expect(entries.single.weight, 81.4);
      expect(entries.single.date, DateTime(2026, 2, 2));
    });

    test('drops entries that cannot be plotted instead of throwing', () {
      final entries = weightHistoryFromDynamic([
        {'weight': 80.0}, // no date
        {'date': 1700000000000}, // no weight
        {'weight': 0, 'date': 1700000000000}, // zero
        {'weight': -5, 'date': 1700000000000}, // negative
        'nonsense',
        {'weight': 79.5, 'date': 1700000000000},
      ]);

      expect(entries.length, 1);
      expect(entries.single.weight, 79.5);
    });

    test('a missing or non-list field is an empty history', () {
      expect(weightHistoryFromDynamic(null), isEmpty);
      expect(weightHistoryFromDynamic({'weight': 80}), isEmpty);
      expect(weightHistoryFromDynamic(const []), isEmpty);
    });

    test('round trips through the shape stored in Firestore', () {
      final entry = WeightEntry(
        date: DateTime(2026, 4, 1, 7, 30),
        weight: 83.2,
      );

      final restored = weightHistoryFromDynamic([entry.toMap()]).single;

      expect(restored.weight, 83.2);
      expect(restored.date, DateTime(2026, 4, 1, 7, 30));
    });
  });
}
