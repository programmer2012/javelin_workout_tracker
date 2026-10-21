import 'package:cloud_firestore/cloud_firestore.dart';

/// Documents in this app have been written by several versions of the client,
/// so numbers and dates can arrive as strings, ints, doubles or Timestamps.
/// These helpers read any of those shapes instead of throwing on the ones a
/// given model did not expect.

int coerceInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

/// Also accepts a comma decimal separator, which the weight field produces on
/// German and Swiss keyboards.
double coerceDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse((value?.toString() ?? '').replaceAll(',', '.')) ?? 0;
}

/// Returns `null` rather than a sentinel date, so callers decide what a
/// missing or unreadable date means for them.
DateTime? coerceDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  return null;
}
