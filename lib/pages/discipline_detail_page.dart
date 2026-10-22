import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:javelin_workout_tracker/components/progress_chart.dart';
import 'package:javelin_workout_tracker/models/progression.dart';
import 'package:javelin_workout_tracker/models/test_result.dart';
import 'package:javelin_workout_tracker/pages/tests_page.dart' show formatValue;
import 'package:javelin_workout_tracker/services/test_repository.dart';

/// One discipline: its progression, its personal best, and the full history.
class DisciplineDetailPage extends StatefulWidget {
  final Discipline discipline;
  final List<TestResult> results;

  const DisciplineDetailPage({
    required this.discipline,
    required this.results,
    super.key,
  });

  @override
  State<DisciplineDetailPage> createState() => _DisciplineDetailPageState();
}

class _DisciplineDetailPageState extends State<DisciplineDetailPage> {
  final TestRepository _repository = TestRepository();
  ChartRange _range = ChartRange.all;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addResult() async {
    final result = await showDialog<_NewResult>(
      context: context,
      builder: (_) => _AddResultDialog(discipline: widget.discipline),
    );
    if (result == null) return;

    final beatsBest = isPersonalBest(
      result.value,
      widget.results,
      widget.discipline,
    );

    try {
      await _repository.addResult(TestResult(
        id: '',
        disciplineId: widget.discipline.id,
        date: result.date,
        value: result.value,
        note: result.note,
      ));
      _showMessage(
        beatsBest
            ? 'Neue Bestleistung: ${formatValue(result.value)} '
                '${widget.discipline.unit}'
            : 'Resultat gespeichert',
      );
      // The list was passed in, so leave and let the stream rebuild it.
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showMessage('Konnte nicht speichern: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final discipline = widget.discipline;
    // Oldest first for the chart; the incoming list is newest first.
    final ordered = [...widget.results]
      ..sort((a, b) => a.date.compareTo(b.date));

    final points = pointsInRange(
      [
        for (final r in ordered) ChartPoint(date: r.date, value: r.value),
      ],
      _range,
    );
    final best = personalBest(widget.results, discipline);

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(title: Text(discipline.label)),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _addResult,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 80),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        best == null
                            ? 'Noch kein Resultat'
                            : 'PB ${formatValue(best.value)} ${discipline.unit}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (discipline.lowerIsBetter)
                        const Text(
                          'kleiner ist besser',
                          style:
                              TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final range in ChartRange.values)
                        ChoiceChip(
                          label: Text(range.label),
                          labelStyle: const TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          selected: _range == range,
                          onSelected: (_) => setState(() => _range = range),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: ProgressChart(
                      points: points,
                      unit: discipline.unit,
                      emptyMessage: ordered.isEmpty
                          ? 'Noch keine Resultate erfasst.'
                          : 'Nichts in den letzten ${_range.label}.',
                    ),
                  ),
                ],
              ),
            ),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Alle Resultate',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (widget.results.isEmpty)
                    const Text(
                      'Noch nichts erfasst.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
                    )
                  else
                    for (final result in widget.results)
                      _ResultRow(
                        result: result,
                        discipline: discipline,
                        isBest: identical(result, best),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final TestResult result;
  final Discipline discipline;
  final bool isBest;

  const _ResultRow({
    required this.result,
    required this.discipline,
    required this.isBest,
  });

  @override
  Widget build(BuildContext context) {
    final date = result.date;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              result.seasonBest
                  // These rows carry no real day, so showing one would be a
                  // small lie; the year is all the sheet knew.
                  ? '${date.year}'
                  : '${date.day}.${date.month}.${date.year}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Text(
                  '${formatValue(result.value)} ${discipline.unit}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                    color: isBest ? Colors.deepPurple : Colors.black87,
                  ),
                ),
                if (isBest)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.star, size: 14, color: Colors.amber),
                  ),
                if (result.seasonBest)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Text(
                      'Saisonbest',
                      style: TextStyle(fontSize: 10, color: Colors.black45),
                    ),
                  ),
              ],
            ),
          ),
          if (result.note != null)
            Flexible(
              child: Text(
                result.note!,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }
}

class _NewResult {
  final double value;
  final DateTime date;
  final String? note;

  const _NewResult({required this.value, required this.date, this.note});
}

class _AddResultDialog extends StatefulWidget {
  final Discipline discipline;

  const _AddResultDialog({required this.discipline});

  @override
  State<_AddResultDialog> createState() => _AddResultDialogState();
}

class _AddResultDialogState extends State<_AddResultDialog> {
  final TextEditingController _value = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    final parsed = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= 0) {
      setState(() => _error = 'Bitte einen gültigen Wert eingeben');
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      _NewResult(
        value: parsed,
        date: _date,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
        widget.discipline.label,
        style: const TextStyle(fontSize: 18),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _value,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Wert in ${widget.discipline.unit}',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Bemerkung (optional)',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_date.day}.${_date.month}.${_date.year}'),
              TextButton(onPressed: _pickDate, child: const Text('Datum')),
            ],
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        MaterialButton(
          color: Colors.green,
          onPressed: _submit,
          child: const Text('speichern'),
        ),
        MaterialButton(
          color: Colors.red,
          onPressed: () => Navigator.pop(context),
          child: const Text('abbrechen'),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(12),
        child: child,
      );
}
