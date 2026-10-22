import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/coach.dart';
import 'package:javelin_workout_tracker/models/training_plan.dart';
import 'package:javelin_workout_tracker/services/coach_repository.dart';
import 'package:javelin_workout_tracker/services/plan_repository.dart';

/// Which of a coach's athletes can see a given plan.
///
/// Plans themselves are imported from the coach's spreadsheet by the desktop
/// importer; the app only decides who they reach.
class PlanAssignPage extends StatefulWidget {
  const PlanAssignPage({super.key});

  @override
  State<PlanAssignPage> createState() => _PlanAssignPageState();
}

class _PlanAssignPageState extends State<PlanAssignPage> {
  final PlanRepository _plans = PlanRepository();
  final CoachRepository _coaches = CoachRepository();

  late final Stream<List<TrainingPlan>> _owned = _plans.watchOwnedPlans();
  late final Stream<List<Athlete>> _athletes = _coaches.watchAthletes();

  /// Plan ids with a write in flight, so a tap cannot be double-fired.
  final Set<String> _busy = {};

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(TrainingPlan plan, Athlete athlete, bool assign) async {
    final key = '${plan.id}/${athlete.uid}';
    if (_busy.contains(key)) return;

    setState(() => _busy.add(key));
    try {
      await _plans.setAssigned(
        planId: plan.id,
        athleteUid: athlete.uid,
        assigned: assign,
      );
      _showMessage(assign
          ? '${athlete.name} sieht jetzt "${plan.name}"'
          : '${athlete.name} sieht "${plan.name}" nicht mehr');
    } catch (error) {
      _showMessage('Konnte nicht speichern: $error');
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(title: const Text('Pläne zuweisen')),
      body: SafeArea(
        child: StreamBuilder<List<TrainingPlan>>(
          stream: _owned,
          builder: (context, planSnapshot) {
            if (planSnapshot.hasError) {
              return const _Centered('Deine Pläne konnten nicht geladen '
                  'werden.');
            }
            if (!planSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final plans = planSnapshot.data!;
            if (plans.isEmpty) {
              return const _Centered(
                'Du hast noch keinen Plan veröffentlicht.\n\n'
                'Importiere deinen Excel-Plan mit dem Import-Skript '
                '(tools/import_plan.py) – danach erscheint er hier und du '
                'kannst ihn deinen Athleten zuweisen.',
              );
            }

            return StreamBuilder<List<Athlete>>(
              stream: _athletes,
              builder: (context, athleteSnapshot) {
                final athletes = athleteSnapshot.data ?? const <Athlete>[];
                return ListView(
                  padding: const EdgeInsets.all(15),
                  children: [
                    for (final plan in plans)
                      _PlanCard(
                        plan: plan,
                        athletes: athletes,
                        busy: _busy,
                        onToggle: _toggle,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final TrainingPlan plan;
  final List<Athlete> athletes;
  final Set<String> busy;
  final Future<void> Function(TrainingPlan, Athlete, bool) onToggle;

  const _PlanCard({
    required this.plan,
    required this.athletes,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final updated = plan.updatedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          Text(
            '${plan.weekCount} Wochen'
            '${updated == null ? '' : ' · aktualisiert '
                '${updated.day}.${updated.month}.${updated.year}'}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Divider(height: 18),
          if (athletes.isEmpty)
            const Text(
              'Noch keine Athleten. Teile deinen Coach-Code, damit sie dich '
              'hinzufügen.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            for (final athlete in athletes)
              _athleteRow(context, athlete),
        ],
      ),
    );
  }

  Widget _athleteRow(BuildContext context, Athlete athlete) {
    final assigned = plan.isAssignedTo(athlete.uid);
    final isBusy = busy.contains('${plan.id}/${athlete.uid}');

    return Row(
      children: [
        Expanded(child: Text(athlete.name, style: const TextStyle(fontSize: 14))),
        if (isBusy)
          const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Switch(
            value: assigned,
            onChanged: (value) => onToggle(plan, athlete, value),
          ),
      ],
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
