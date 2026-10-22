import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:javelin_workout_tracker/utils/coerce.dart';

/// Whole calendar days from [from] to [to], ignoring the time of day.
///
/// Compared in UTC on purpose. This season crosses two daylight-saving
/// changes, and a local-time `difference(...).inDays` reports 6 across the
/// spring one — enough to drop a day out of a week.
int calendarDaysBetween(DateTime from, DateTime to) {
  return DateTime.utc(to.year, to.month, to.day)
      .difference(DateTime.utc(from.year, from.month, from.day))
      .inDays;
}

/// The four load categories the plan is steered by.
///
/// Ids match the keys in `assets/seed/season_plan.json` and the field names
/// written to Firestore.
enum LoadCategory {
  at('at', 'AT', 'Athletiktraining'),
  kraft('kraft', 'Kraft', 'Krafttraining'),
  spezKt('spezKt', 'spez. KT', 'spezifisches Krafttraining'),
  wuerfe('wuerfe', 'Würfe', 'Wurfanzahl');

  const LoadCategory(this.id, this.label, this.hint);

  final String id;
  final String label;
  final String hint;
}

/// Volumes recorded alongside the four categories. The plan notes that
/// sprint metres and ground contacts deliberately do not count towards AT.
enum ExtraMeasure {
  weite('weite', 'Weite', 'm'),
  sprint('sprint', 'Sprint', 'm'),
  spruenge('spruenge', 'Sprünge', 'BK');

  const ExtraMeasure(this.id, this.label, this.unit);

  final String id;
  final String label;
  final String unit;
}

/// One week of the season: what is planned, and what to do each day.
class SeasonWeek {
  /// Calendar week. The season runs 44-53 and then 1-33, so this is not a
  /// position — use the index in [SeasonPlan.weeks] for ordering.
  final int week;
  final DateTime monday;
  final String phase;
  final Map<String, double> soll;
  final String note;
  final Map<String, String> days;

  const SeasonWeek({
    required this.week,
    required this.monday,
    required this.phase,
    required this.soll,
    required this.note,
    required this.days,
  });

  factory SeasonWeek.fromMap(Map<String, dynamic> map) {
    final rawSoll = map['soll'];
    final rawDays = map['days'];

    return SeasonWeek(
      week: coerceInt(map['week']),
      monday: coerceDate(map['monday']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      phase: (map['phase'] as String?)?.trim() ?? '',
      soll: {
        for (final category in LoadCategory.values)
          category.id: rawSoll is Map
              ? coerceDouble(rawSoll[category.id])
              : 0.0,
      },
      note: (map['note'] as String?)?.trim() ?? '',
      days: rawDays is Map
          ? {
              for (final entry in rawDays.entries)
                entry.key.toString(): entry.value.toString(),
            }
          : const {},
    );
  }

  double sollFor(LoadCategory category) => soll[category.id] ?? 0;

  /// Built from the calendar fields rather than `monday.add(Duration)`:
  /// adding a duration across a daylight-saving change lands an hour out,
  /// which is enough to push the Sunday onto the wrong date.
  DateTime get sunday => DateTime(monday.year, monday.month, monday.day + 6);

  /// The key this week's actuals are stored under. The Monday date rather
  /// than the week number, because the season spans two calendar years and
  /// "week 1" is ambiguous on its own.
  String get key =>
      '${monday.year}-${monday.month.toString().padLeft(2, '0')}'
      '-${monday.day.toString().padLeft(2, '0')}';

  bool containsDate(DateTime date) {
    final offset = calendarDaysBetween(monday, date);
    return offset >= 0 && offset <= 6;
  }
}

/// The whole season, as loaded from the bundled plan.
class SeasonPlan {
  final String season;
  final List<SeasonWeek> weeks;
  final SplitReference split;
  final SprintReference sprint;

  const SeasonPlan({
    required this.season,
    required this.weeks,
    this.split = SplitReference.empty,
    this.sprint = SprintReference.empty,
  });

  static const empty = SeasonPlan(season: '', weeks: []);

  factory SeasonPlan.fromMap(Map<String, dynamic> map) {
    final rawWeeks = map['weeks'];
    final rawSplit = map['split'];
    final rawSprint = map['sprint'];
    return SeasonPlan(
      season: (map['season'] as String?) ?? '',
      weeks: rawWeeks is List
          ? rawWeeks
              .whereType<Map>()
              .map((w) => SeasonWeek.fromMap(Map<String, dynamic>.from(w)))
              .toList()
          : const [],
      split: SplitReference.fromMap(
        rawSplit is Map ? Map<String, dynamic>.from(rawSplit) : null,
      ),
      sprint: SprintReference.fromMap(
        rawSprint is Map ? Map<String, dynamic>.from(rawSprint) : null,
      ),
    );
  }

  double sollTotal(LoadCategory category) =>
      weeks.fold(0.0, (sum, w) => sum + w.sollFor(category));

  /// The week containing [date], or `null` outside the season.
  SeasonWeek? weekFor(DateTime date) {
    for (final week in weeks) {
      if (week.containsDate(date)) return week;
    }
    return null;
  }

  /// The week to open on: the current one, or the nearest once the season is
  /// over or has not started, so the page is never blank.
  SeasonWeek? closestTo(DateTime date) {
    if (weeks.isEmpty) return null;
    final current = weekFor(date);
    if (current != null) return current;

    SeasonWeek best = weeks.first;
    var bestGap = (weeks.first.monday.difference(date)).abs();
    for (final week in weeks) {
      final gap = (week.monday.difference(date)).abs();
      if (gap < bestGap) {
        best = week;
        bestGap = gap;
      }
    }
    return best;
  }
}

/// What was actually done in one week. Stored per user, keyed by
/// [SeasonWeek.key].
class WeekActuals {
  final Map<String, double> values;
  final String note;

  const WeekActuals({this.values = const {}, this.note = ''});

  static const empty = WeekActuals();

  factory WeekActuals.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    return WeekActuals(
      values: {
        for (final entry in map.entries)
          if (entry.key != 'note' && entry.value != null)
            entry.key: coerceDouble(entry.value),
      },
      note: (map['note'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        ...values,
        'note': note,
      };

  double forCategory(LoadCategory category) => values[category.id] ?? 0;

  double forExtra(ExtraMeasure extra) => values[extra.id] ?? 0;

  bool get isEmpty =>
      note.isEmpty && values.values.every((value) => value == 0);

  WeekActuals copyWith({Map<String, double>? values, String? note}) =>
      WeekActuals(values: values ?? this.values, note: note ?? this.note);
}

/// Reads the per-week actuals keyed by week, as stored on the user document.
Map<String, WeekActuals> weekActualsFrom(DocumentSnapshot<Map<String, dynamic>>?
    snapshot) {
  final data = snapshot?.data();
  if (data == null) return {};
  return {
    for (final entry in data.entries)
      if (entry.value is Map)
        entry.key: WeekActuals.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
        ),
  };
}

/// Completion as a fraction, clamped at 0 so a missing SOLL cannot produce
/// an infinite or negative percentage.
double completionFraction(double ist, double soll) {
  if (soll <= 0) return 0;
  return (ist / soll).clamp(0.0, 10.0);
}

// --- AT-Split reference ----------------------------------------------------

/// One exercise of a gym split.
class SplitExercise {
  final int nr;
  final String name;
  final String equipment;

  /// `H` Hauptübung, `N` Nebenübung, `I` Isolation/Prävention. Absent in the
  /// reduced splits, which give [sets] instead.
  final String? type;
  final String? sets;
  final String? hint;

  const SplitExercise({
    required this.nr,
    required this.name,
    required this.equipment,
    this.type,
    this.sets,
    this.hint,
  });

  factory SplitExercise.fromMap(Map<String, dynamic> map) {
    String? trimmed(String key) {
      final value = (map[key] as String?)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    return SplitExercise(
      nr: coerceInt(map['nr']),
      name: (map['name'] as String?)?.trim() ?? '',
      equipment: (map['equipment'] as String?)?.trim() ?? '',
      type: trimmed('type'),
      sets: trimmed('sets'),
      hint: trimmed('hint'),
    );
  }
}

/// A named group of exercises, or a block of rules when [exercises] is empty.
class SplitBlock {
  final String title;
  final List<SplitExercise> exercises;
  final List<String> notes;

  const SplitBlock({
    required this.title,
    this.exercises = const [],
    this.notes = const [],
  });

  bool get isRulesOnly => exercises.isEmpty && notes.isNotEmpty;

  factory SplitBlock.fromMap(Map<String, dynamic> map) {
    final rawExercises = map['exercises'];
    final rawNotes = map['notes'];
    return SplitBlock(
      title: (map['title'] as String?)?.trim() ?? '',
      exercises: rawExercises is List
          ? rawExercises
              .whereType<Map>()
              .map((e) => SplitExercise.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      notes: rawNotes is List
          ? rawNotes.map((n) => n.toString()).toList()
          : const [],
    );
  }
}

/// How the split is loaded in one week of the build-up (Wo 44-50).
class SplitProgression {
  final int week;
  final String label;
  final String main;
  final String secondary;
  final String isolation;
  final String rir;
  final String focus;
  final double kraftReps;
  final double medball;
  final double atTotal;
  final double soll;

  const SplitProgression({
    required this.week,
    required this.label,
    required this.main,
    required this.secondary,
    required this.isolation,
    required this.rir,
    required this.focus,
    required this.kraftReps,
    required this.medball,
    required this.atTotal,
    required this.soll,
  });

  factory SplitProgression.fromMap(Map<String, dynamic> map) {
    String str(String key) => (map[key] as String?)?.trim() ?? '';
    return SplitProgression(
      week: coerceInt(map['week']),
      label: str('label'),
      main: str('main'),
      secondary: str('secondary'),
      isolation: str('isolation'),
      rir: str('rir'),
      focus: str('focus'),
      kraftReps: coerceDouble(map['kraftReps']),
      medball: coerceDouble(map['medball']),
      atTotal: coerceDouble(map['atTotal']),
      soll: coerceDouble(map['soll']),
    );
  }
}

class SplitReference {
  final List<String> intro;
  final List<SplitBlock> blocks;
  final List<SplitProgression> progression;

  const SplitReference({
    this.intro = const [],
    this.blocks = const [],
    this.progression = const [],
  });

  static const empty = SplitReference();

  factory SplitReference.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    final rawIntro = map['intro'];
    final rawBlocks = map['blocks'];
    final rawProgression = map['progression'];
    return SplitReference(
      intro: rawIntro is List
          ? rawIntro.map((n) => n.toString()).toList()
          : const [],
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map((b) => SplitBlock.fromMap(Map<String, dynamic>.from(b)))
              .toList()
          : const [],
      progression: rawProgression is List
          ? rawProgression
              .whereType<Map>()
              .map((p) =>
                  SplitProgression.fromMap(Map<String, dynamic>.from(p)))
              .toList()
          : const [],
    );
  }

  /// The progression row for [week], or `null` — the table only covers the
  /// build-up weeks 44-50, after which the barbell work takes over.
  SplitProgression? forWeek(int week) {
    for (final row in progression) {
      if (row.week == week) return row;
    }
    return null;
  }
}

// --- Sprint & Sprung reference ---------------------------------------------

/// A span of weeks sharing one sprint and jump focus.
class SprintBlock {
  final String label;
  final List<int> weeks;
  final String goal;
  final String contents;
  final String volume;
  final String placement;

  const SprintBlock({
    required this.label,
    required this.weeks,
    required this.goal,
    required this.contents,
    required this.volume,
    required this.placement,
  });

  bool covers(int week) => weeks.contains(week);

  factory SprintBlock.fromMap(Map<String, dynamic> map) {
    String str(String key) => (map[key] as String?)?.trim() ?? '';
    final rawWeeks = map['weeks'];
    return SprintBlock(
      label: str('label'),
      weeks: rawWeeks is List
          ? rawWeeks.map(coerceInt).toList()
          : const [],
      goal: str('goal'),
      contents: str('contents'),
      volume: str('volume'),
      placement: str('placement'),
    );
  }
}

class SprintReference {
  final List<SprintBlock> blocks;
  final List<String> rules;

  const SprintReference({this.blocks = const [], this.rules = const []});

  static const empty = SprintReference();

  factory SprintReference.fromMap(Map<String, dynamic>? map) {
    if (map == null) return empty;
    final rawBlocks = map['blocks'];
    final rawRules = map['rules'];
    return SprintReference(
      blocks: rawBlocks is List
          ? rawBlocks
              .whereType<Map>()
              .map((b) => SprintBlock.fromMap(Map<String, dynamic>.from(b)))
              .toList()
          : const [],
      rules: rawRules is List
          ? rawRules.map((r) => r.toString()).toList()
          : const [],
    );
  }

  SprintBlock? forWeek(int week) {
    for (final block in blocks) {
      if (block.covers(week)) return block;
    }
    return null;
  }
}
