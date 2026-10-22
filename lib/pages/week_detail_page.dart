import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:javelin_workout_tracker/models/season_plan.dart';
import 'package:javelin_workout_tracker/services/season_repository.dart';

/// One training week: the planned sessions, and the SOLL/IST numbers.
class WeekDetailPage extends StatefulWidget {
  final SeasonWeek week;
  final WeekActuals actuals;

  /// The sprint block covering this week, if any.
  final SprintBlock? sprint;

  /// The AT-Split progression row for this week. Only the build-up weeks
  /// 44-50 have one.
  final SplitProgression? split;

  const WeekDetailPage({
    required this.week,
    required this.actuals,
    this.sprint,
    this.split,
    super.key,
  });

  @override
  State<WeekDetailPage> createState() => _WeekDetailPageState();
}

class _WeekDetailPageState extends State<WeekDetailPage> {
  static const _dayNames = {
    'Mo': 'Montag',
    'Di': 'Dienstag',
    'Mi': 'Mittwoch',
    'Do': 'Donnerstag',
    'Fr': 'Freitag',
    'Sa': 'Samstag',
    'So': 'Sonntag',
  };

  final SeasonRepository _repository = SeasonRepository();
  final Map<String, TextEditingController> _controllers = {};
  late final TextEditingController _note;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final category in LoadCategory.values) {
      _controllers[category.id] =
          TextEditingController(text: _format(widget.actuals.forCategory(category)));
    }
    for (final extra in ExtraMeasure.values) {
      _controllers[extra.id] =
          TextEditingController(text: _format(widget.actuals.forExtra(extra)));
    }
    _note = TextEditingController(text: widget.actuals.note);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  /// An unfilled field shows blank rather than 0, so "not entered yet" and
  /// "did none" stay visually distinct while typing.
  static String _format(double value) {
    if (value == 0) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  double _read(String id) =>
      double.tryParse(_controllers[id]!.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final values = <String, double>{
      for (final category in LoadCategory.values)
        category.id: _read(category.id),
      for (final extra in ExtraMeasure.values) extra.id: _read(extra.id),
    };

    try {
      await _repository.saveWeek(
        widget.week.key,
        WeekActuals(values: values, note: _note.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Woche gespeichert')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte nicht speichern: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = widget.week;
    final monday = week.monday;
    final sunday = week.sunday;

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: Text('Woche ${week.week}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 30),
          children: [
            _Card(
              title: '${monday.day}.${monday.month}. – '
                  '${sunday.day}.${sunday.month}.${sunday.year}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(week.phase, style: const TextStyle(fontSize: 13)),
                  if (week.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      week.note,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _Card(
              title: 'Soll / Ist',
              child: Column(
                children: [
                  for (final category in LoadCategory.values)
                    _LoadRow(
                      label: category.label,
                      hint: category.hint,
                      soll: week.sollFor(category),
                      controller: _controllers[category.id]!,
                      onChanged: () => setState(() {}),
                    ),
                  const Divider(height: 24),
                  // Sprint metres and ground contacts are tracked but do not
                  // count towards AT, per the plan's own note.
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Zusätzlich erfasst (zählt nicht zum AT)',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final extra in ExtraMeasure.values)
                    _ExtraRow(
                      label: extra.label,
                      unit: extra.unit,
                      controller: _controllers[extra.id]!,
                    ),
                ],
              ),
            ),
            _Card(
              title: 'Bemerkung',
              child: TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Wettkampf, Krankheit, Abweichungen …',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            if (widget.split != null) _buildSplitCard(widget.split!),
            if (widget.sprint != null) _buildSprintCard(widget.sprint!),
            if (week.days.isNotEmpty)
              _Card(
                title: 'Wochenplan',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _dayNames.entries)
                      if (week.days[entry.key] != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                week.days[entry.key]!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _WeekDetailPageState {
  Widget _buildSplitCard(SplitProgression split) {
    return _Card(
      title: 'AT-Split diese Woche',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (split.label.isNotEmpty)
            Text(
              split.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          Text(
            'Haupt ${split.main} · Neben ${split.secondary} · '
            'Isolation ${split.isolation}',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text('RIR ${split.rir}', style: const TextStyle(fontSize: 12)),
          if (split.focus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                split.focus,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54,
                ),
              ),
            ),
          const SizedBox(height: 6),
          // The AT target is hit partly by lifting reps and partly by
          // medball; showing the split makes the gap deliberate.
          Text(
            'Kraft ${split.kraftReps.round()} + Medball '
            '${split.medball.round()} = ${split.atTotal.round()} '
            '(Soll ${split.soll.round()})',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildSprintCard(SprintBlock sprint) {
    return _Card(
      title: 'Sprint & Sprung (Wo ${sprint.label})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sprint.goal, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Text(sprint.contents, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            '${sprint.volume}'
            '${sprint.placement.isEmpty ? '' : ' · ${sprint.placement}'}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _LoadRow extends StatelessWidget {
  final String label;
  final String hint;
  final double soll;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _LoadRow({
    required this.label,
    required this.hint,
    required this.soll,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ist =
        double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;
    final percent = (completionFraction(ist, soll) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Soll ${soll.round()}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              soll > 0 ? '$percent%' : '–',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: percent >= 100 ? Colors.green : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraRow extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;

  const _ExtraRow({
    required this.label,
    required this.unit,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('$label [$unit]',
                style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 80,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              ),
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
