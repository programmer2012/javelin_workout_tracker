import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/season_plan.dart';
import 'package:javelin_workout_tracker/pages/split_reference_page.dart';
import 'package:javelin_workout_tracker/pages/week_detail_page.dart';
import 'package:javelin_workout_tracker/models/training_plan.dart';
import 'package:javelin_workout_tracker/services/plan_repository.dart';
import 'package:javelin_workout_tracker/services/season_repository.dart';

/// The season at a glance: SOLL against IST, week by week.
class SeasonPage extends StatefulWidget {
  const SeasonPage({super.key});

  @override
  State<SeasonPage> createState() => _SeasonPageState();
}

class _SeasonPageState extends State<SeasonPage> {
  final SeasonRepository _repository = SeasonRepository();
  final PlanRepository _plans = PlanRepository();

  /// The plan a coach assigned, or the bundled one when there is none.
  late final Future<ResolvedPlan> _plan = _plans.resolve();
  late final Stream<Map<String, WeekActuals>> _actuals =
      _repository.watchActuals();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: FutureBuilder<ResolvedPlan>(
          future: _plan,
          builder: (context, planSnapshot) {
            if (planSnapshot.hasError) {
              return const _Centered('Der Trainingsplan konnte nicht '
                  'geladen werden.');
            }
            if (!planSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final resolved = planSnapshot.data!;
            if (resolved.plan.weeks.isEmpty) {
              return const _Centered(
                'Noch kein Trainingsplan.\n\n'
                'Lass dich von deinem Coach hinzufügen, damit du seinen Plan '
                'erhältst – oder importiere deinen eigenen mit '
                'tools/import_plan.py.',
              );
            }

            return StreamBuilder<Map<String, WeekActuals>>(
              stream: _actuals,
              builder: (context, actualsSnapshot) {
                // No actuals yet is the normal starting state, not an error.
                final actuals = actualsSnapshot.data ?? const {};
                return _buildBody(resolved, actuals);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(ResolvedPlan resolved, Map<String, WeekActuals> actuals) {
    final plan = resolved.plan;
    final today = DateTime.now();
    final current = plan.closestTo(today);
    final inSeason = plan.weekFor(today) != null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'Trainingsplan ${plan.season}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            // Say where the plan came from: an athlete needs to know
            // whether they are looking at their coach's prescription.
            resolved.source == PlanSource.coach
                ? '${resolved.assigned!.name}'
                  '${resolved.assigned!.ownerName.isEmpty ? '' : ' · von '
                      '${resolved.assigned!.ownerName}'}'
                : 'Kein Coach-Plan zugewiesen – App-Plan',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        _buildSeasonTotals(plan, actuals),
        if (plan.split.blocks.isNotEmpty || plan.sprint.blocks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
              ),
              icon: const Icon(Icons.fitness_center, size: 18),
              label: const Text('Übungen & Sprint'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SplitReferencePage(
                    plan: plan,
                    currentWeek: current?.week,
                  ),
                ),
              ),
            ),
          ),
        if (current != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              inSeason
                  ? 'Aktuelle Woche'
                  : 'Saison läuft nicht – nächstgelegene Woche',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        for (final week in plan.weeks)
          _WeekTile(
            week: week,
            actuals: actuals[week.key] ?? WeekActuals.empty,
            isCurrent: identical(week, current),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WeekDetailPage(
                  week: week,
                  actuals: actuals[week.key] ?? WeekActuals.empty,
                  sprint: plan.sprint.forWeek(week.week),
                  split: plan.split.forWeek(week.week),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSeasonTotals(SeasonPlan plan, Map<String, WeekActuals> actuals) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saison gesamt',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final category in LoadCategory.values)
            _TotalRow(
              label: category.label,
              ist: actuals.values
                  .fold(0.0, (sum, a) => sum + a.forCategory(category)),
              soll: plan.sollTotal(category),
            ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double ist;
  final double soll;

  const _TotalRow({
    required this.label,
    required this.ist,
    required this.soll,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = completionFraction(ist, soll);
    final percent = (fraction * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                // The bar saturates at 100 % while the number keeps going,
                // so overshooting a target is visible but not distorting.
                value: fraction.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor:
                    const AlwaysStoppedAnimation(Colors.deepPurple),
              ),
            ),
          ),
          SizedBox(
            width: 108,
            child: Text(
              '${_short(ist)} / ${_short(soll)}  $percent%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(double value) {
    if (value >= 1000) {
      final thousands = value / 1000;
      return '${thousands.toStringAsFixed(thousands >= 10 ? 0 : 1)}k';
    }
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(1);
  }
}

class _WeekTile extends StatelessWidget {
  final SeasonWeek week;
  final WeekActuals actuals;
  final bool isCurrent;
  final VoidCallback onTap;

  const _WeekTile({
    required this.week,
    required this.actuals,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final monday = week.monday;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: isCurrent
            ? Border.all(color: Colors.amber, width: 3)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Row(
          children: [
            Text(
              'Wo ${week.week}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${monday.day}.${monday.month}.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (actuals.isEmpty)
              const Spacer()
            else ...[
              const Spacer(),
              const Icon(Icons.check_circle, size: 15, color: Colors.green),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              week.phase,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                for (final category in LoadCategory.values)
                  Expanded(
                    child: _MiniBar(
                      label: category.label,
                      ist: actuals.forCategory(category),
                      soll: week.sollFor(category),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  final String label;
  final double ist;
  final double soll;

  const _MiniBar({
    required this.label,
    required this.ist,
    required this.soll,
  });

  @override
  Widget build(BuildContext context) {
    // A week with no target for this category is a rest block, not a gap in
    // the data, so show it as a flat line rather than an empty bar.
    final planned = soll > 0;
    final fraction = completionFraction(ist, soll).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Colors.black54),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: planned ? fraction : 0,
              minHeight: 5,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(
                planned ? Colors.deepPurple : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final String text;

  const _Centered(this.text);

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
