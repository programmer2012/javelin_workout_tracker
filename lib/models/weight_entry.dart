import 'package:javelin_workout_tracker/utils/coerce.dart';

/// One body-weight measurement from the user's `weightHistory`.
class WeightEntry {
  final DateTime date;
  final double weight;

  const WeightEntry({required this.date, required this.weight});

  /// Returns `null` for an entry that cannot be plotted, so one bad record
  /// does not take the whole chart down.
  static WeightEntry? fromMap(Map<String, dynamic> map) {
    final date = coerceDate(map['date']);
    final weight = coerceDouble(map['weight']);
    if (date == null || weight <= 0) return null;
    return WeightEntry(date: date, weight: weight);
  }

  /// Dates stay epoch millis to match the entries already in Firestore.
  Map<String, dynamic> toMap() => {
        'weight': weight,
        'date': date.millisecondsSinceEpoch,
      };
}

/// Reads `weightHistory`, dropping unusable entries and sorting oldest first
/// so a chart can plot the result directly.
List<WeightEntry> weightHistoryFromDynamic(dynamic raw) {
  if (raw is! List) return [];

  final entries = raw
      .whereType<Map>()
      .map((e) => WeightEntry.fromMap(Map<String, dynamic>.from(e)))
      .whereType<WeightEntry>()
      .toList();
  entries.sort((a, b) => a.date.compareTo(b.date));
  return entries;
}
