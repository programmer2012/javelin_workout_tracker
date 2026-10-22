import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:javelin_workout_tracker/utils/coerce.dart';

/// A discipline a result can be recorded against.
///
/// [lowerIsBetter] is the field that stops a sprint time being treated like a
/// throwing distance: for those, the personal best is the *minimum* and an
/// improvement is a decrease.
class Discipline {
  final String id;
  final String label;
  final String unit;
  final bool lowerIsBetter;

  const Discipline({
    required this.id,
    required this.label,
    required this.unit,
    this.lowerIsBetter = false,
  });

  factory Discipline.fromMap(Map<String, dynamic> map) => Discipline(
        id: map['id'] as String? ?? '',
        label: map['label'] as String? ?? '',
        unit: map['unit'] as String? ?? '',
        lowerIsBetter: map['lowerIsBetter'] == true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'unit': unit,
        'lowerIsBetter': lowerIsBetter,
      };
}

/// The disciplines from Tom's Testblatt.
///
/// `competition` is in here too: a javelin result is the metric that matters
/// most, and treating it as a discipline means personal bests and the
/// progression chart need no special case for it.
const List<Discipline> defaultDisciplines = [
  Discipline(id: 'competition', label: 'Wettkampf', unit: 'm'),
  Discipline(id: 'standing_throw', label: 'Standwurf', unit: 'm'),
  Discipline(id: 'shot4_forward', label: 'Schocken 4 kg vorwärts', unit: 'm'),
  Discipline(id: 'shot4_backward', label: 'Schocken 4 kg rückwärts', unit: 'm'),
  Discipline(id: 'shot7_forward', label: 'Schocken 7 kg vorwärts', unit: 'm'),
  Discipline(id: 'shot7_backward', label: 'Schocken 7 kg rückwärts', unit: 'm'),
  Discipline(id: 'standing_long_jump', label: 'Standweitsprung', unit: 'm'),
  Discipline(id: 'five_bound', label: '5er Sprung', unit: 'm'),
  Discipline(
    id: 'sprint_30m_flying',
    label: '30 m fliegend',
    unit: 's',
    lowerIsBetter: true,
  ),
  Discipline(
    id: 'sprint_30m_standing',
    label: '30 m aus dem Stand',
    unit: 's',
    lowerIsBetter: true,
  ),
  Discipline(id: 'bench_press', label: 'Bankdrücken', unit: 'kg'),
  Discipline(id: 'high_pull', label: 'Anreißen', unit: 'kg'),
  Discipline(id: 'snatch', label: 'Reißen', unit: 'kg'),
  Discipline(id: 'pullover', label: 'Überzug', unit: 'kg'),
];

Discipline? disciplineById(String id) {
  for (final discipline in defaultDisciplines) {
    if (discipline.id == id) return discipline;
  }
  return null;
}

/// One recorded result. Stored in `users/{uid}/testResults`.
class TestResult {
  final String id;
  final String disciplineId;
  final DateTime date;
  final double value;

  /// True for the 2020-2024 rows of the Testblatt, which are a season's best
  /// rather than a test done on a particular day.
  final bool seasonBest;

  /// Free text: the venue for a competition, "fliegend", "7 kg Gerät".
  final String? note;

  const TestResult({
    required this.id,
    required this.disciplineId,
    required this.date,
    required this.value,
    this.seasonBest = false,
    this.note,
  });

  factory TestResult.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> s) =>
      TestResult.fromMap(s.data() ?? {}, id: s.id);

  factory TestResult.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final note = (map['note'] as String?)?.trim();
    return TestResult(
      id: id,
      disciplineId: map['discipline'] as String? ?? '',
      date: coerceDate(map['date']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      value: coerceDouble(map['value']),
      seasonBest: map['seasonBest'] == true,
      note: (note == null || note.isEmpty) ? null : note,
    );
  }

  Map<String, dynamic> toMap() => {
        'discipline': disciplineId,
        'date': Timestamp.fromDate(date),
        'value': value,
        'seasonBest': seasonBest,
        if (note != null) 'note': note,
      };
}

/// The best result in [results], or `null` if there are none.
///
/// Respects [Discipline.lowerIsBetter], so a sprint personal best is the
/// fastest time rather than the slowest.
TestResult? personalBest(List<TestResult> results, Discipline discipline) {
  TestResult? best;
  for (final result in results) {
    if (best == null) {
      best = result;
      continue;
    }
    final better = discipline.lowerIsBetter
        ? result.value < best.value
        : result.value > best.value;
    if (better) best = result;
  }
  return best;
}

/// True if [value] would beat every result in [existing].
///
/// A first result counts as a personal best. Equalling the best does not.
bool isPersonalBest(
  double value,
  List<TestResult> existing,
  Discipline discipline,
) {
  final best = personalBest(existing, discipline);
  if (best == null) return true;
  return discipline.lowerIsBetter ? value < best.value : value > best.value;
}
