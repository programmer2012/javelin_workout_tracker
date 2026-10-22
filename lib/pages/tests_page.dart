import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/models/test_result.dart';
import 'package:javelin_workout_tracker/pages/discipline_detail_page.dart';
import 'package:javelin_workout_tracker/services/test_repository.dart';

/// Personal bests across every discipline, newest result first.
class TestsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TestsPage({required this.userData, super.key});

  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  final TestRepository _repository = TestRepository();
  late final Stream<List<TestResult>> _results = _repository.watchResults();

  bool _importing = false;
  late final Future<int> _seedSize = _repository.seedSize();

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      final count = await _repository.importSeedHistory();
      _showMessage('Imported $count results from the Testblatt');
    } catch (error) {
      _showMessage('Could not import: $error');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imported = _repository.hasImportedSeed(widget.userData);

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: StreamBuilder<List<TestResult>>(
          stream: _results,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _Centered('Could not load your results.');
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final byDiscipline = <String, List<TestResult>>{};
            for (final result in snapshot.data!) {
              byDiscipline.putIfAbsent(result.disciplineId, () => []).add(result);
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Tests & Bestleistungen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!imported)
                  FutureBuilder<int>(
                    future: _seedSize,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      // No bundled history (a clone without the private
                      // seed files) means nothing to offer.
                      if (count == 0) return const SizedBox.shrink();
                      return _buildImportCard(count);
                    },
                  ),
                for (final discipline in defaultDisciplines)
                  _DisciplineTile(
                    discipline: discipline,
                    results: byDiscipline[discipline.id] ?? const [],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImportCard(int count) {
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
            'Testblatt importieren',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '$count Resultate aus dem Testblatt. Läuft nur einmal.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: _importing ? null : _import,
              child: _importing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Importieren'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineTile extends StatelessWidget {
  final Discipline discipline;
  final List<TestResult> results;

  const _DisciplineTile({required this.discipline, required this.results});

  @override
  Widget build(BuildContext context) {
    final best = personalBest(results, discipline);
    // The stream is newest first.
    final latest = results.isEmpty ? null : results.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: ListTile(
        title: Text(
          discipline.label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          results.isEmpty
              ? 'noch kein Resultat'
              : '${results.length} Resultate · zuletzt '
                  '${formatValue(latest!.value)} ${discipline.unit} '
                  '(${latest.date.day}.${latest.date.month}.${latest.date.year})',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: best == null
            ? const Icon(Icons.chevron_right)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${formatValue(best.value)} ${discipline.unit}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const Text(
                        'PB',
                        style: TextStyle(fontSize: 10, color: Colors.black54),
                      ),
                    ],
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DisciplineDetailPage(
              discipline: discipline,
              results: results,
            ),
          ),
        ),
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

/// Whole numbers stay whole; anything else keeps two decimals, which is what
/// a throw or a sprint time needs.
String formatValue(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();
