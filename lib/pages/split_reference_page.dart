import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/season_plan.dart';

/// The AT-Split and the Sprint & Sprung guidance, as reference.
///
/// Read-only on purpose: this is the coach's prescription, not something the
/// athlete edits from the phone.
class SplitReferencePage extends StatelessWidget {
  final SeasonPlan plan;

  /// Highlighted in the progression table and the sprint blocks.
  final int? currentWeek;

  const SplitReferencePage({
    required this.plan,
    this.currentWeek,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final split = plan.split;
    final sprint = plan.sprint;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.deepPurple,
        appBar: AppBar(
          title: const Text('Übungen & Sprint'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'AT-Split'),
              Tab(text: 'Sprint & Sprung'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildSplit(split),
              _buildSprint(sprint),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplit(SplitReference split) {
    if (split.blocks.isEmpty) {
      return const _Empty('Kein AT-Split hinterlegt.');
    }

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        for (final line in split.intro) _IntroLine(line),
        for (final block in split.blocks) _BlockCard(block: block),
        if (split.progression.isNotEmpty)
          _ProgressionCard(
            progression: split.progression,
            currentWeek: currentWeek,
          ),
      ],
    );
  }

  Widget _buildSprint(SprintReference sprint) {
    if (sprint.blocks.isEmpty) {
      return const _Empty('Keine Sprint-Vorgaben hinterlegt.');
    }

    return ListView(
      padding: const EdgeInsets.all(15),
      children: [
        for (final block in sprint.blocks)
          _SprintCard(
            block: block,
            isCurrent: currentWeek != null && block.covers(currentWeek!),
          ),
        if (sprint.rules.isNotEmpty)
          _Card(
            title: 'Regeln',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rule in sprint.rules) _Bullet(rule),
              ],
            ),
          ),
      ],
    );
  }
}

class _BlockCard extends StatelessWidget {
  final SplitBlock block;

  const _BlockCard({required this.block});

  static const _typeLabels = {
    'H': 'Hauptübung',
    'N': 'Nebenübung',
    'I': 'Isolation / Prävention',
  };

  static const _typeColors = {
    'H': Colors.deepPurple,
    'N': Colors.blueGrey,
    'I': Colors.teal,
  };

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: block.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in block.notes) _Bullet(note),
          if (block.notes.isNotEmpty && block.exercises.isNotEmpty)
            const SizedBox(height: 6),
          for (final exercise in block.exercises) _exerciseRow(exercise),
        ],
      ),
    );
  }

  Widget _exerciseRow(SplitExercise exercise) {
    final type = exercise.type;
    final badge = exercise.sets ?? type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '${exercise.nr}',
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (exercise.equipment.isNotEmpty)
                  Text(
                    exercise.equipment,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                if (exercise.hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      exercise.hint!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.black45,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (badge != null)
            Tooltip(
              message: type == null ? '' : (_typeLabels[type] ?? ''),
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (type == null
                          ? Colors.blueGrey
                          : _typeColors[type] ?? Colors.blueGrey)
                      .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: type == null
                        ? Colors.blueGrey
                        : _typeColors[type] ?? Colors.blueGrey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressionCard extends StatelessWidget {
  final List<SplitProgression> progression;
  final int? currentWeek;

  const _ProgressionCard({required this.progression, this.currentWeek});

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Progression Wo ${progression.first.week}–'
          '${progression.last.week}',
      child: Column(
        children: [
          for (final row in progression)
            _row(row, highlight: row.week == currentWeek),
        ],
      ),
    );
  }

  Widget _row(SplitProgression row, {required bool highlight}) {
    // The AT target is met partly by lifting reps and partly by medball, so
    // both are shown next to the week's total.
    final label = row.label.isEmpty ? 'Wo ${row.week}' : 'Wo ${row.week} · ${row.label}';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlight ? Colors.amber.withOpacity(0.18) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: highlight ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'RIR ${row.rir}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'H ${row.main} · N ${row.secondary} · I ${row.isolation}',
            style: const TextStyle(fontSize: 12),
          ),
          if (row.focus.isNotEmpty)
            Text(
              row.focus,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            'Kraft ${row.kraftReps.round()} + Medball ${row.medball.round()} '
            '= ${row.atTotal.round()}  (Soll ${row.soll.round()})',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SprintCard extends StatelessWidget {
  final SprintBlock block;
  final bool isCurrent;

  const _SprintCard({required this.block, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: isCurrent ? Border.all(color: Colors.amber, width: 3) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Wo ${block.label}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCurrent)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Text(
                    'aktuell',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(block.goal, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            block.contents,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.straighten, size: 13, color: Colors.black45),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  block.volume,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
          if (block.placement.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 13, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      block.placement,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  final String text;

  const _IntroLine(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 12)),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  final String text;

  const _Empty(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
}
