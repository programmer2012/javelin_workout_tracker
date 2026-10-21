import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:javelin_workout_tracker/models/coach.dart';
import 'package:javelin_workout_tracker/pages/athlete_detail_page.dart';
import 'package:javelin_workout_tracker/services/coach_repository.dart';

/// Coaching, in both directions: the athletes who have given you access, the
/// code you share to get it, and the coaches you have granted access to.
class CoachPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CoachPage({required this.userData, super.key});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final CoachRepository _repository = CoachRepository();
  final TextEditingController _codeController = TextEditingController();

  late final Stream<List<Athlete>> _athletes = _repository.watchAthletes();

  bool _creatingCode = false;
  bool _redeeming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String? get _myCode {
    final code = (widget.userData['coachCode'] as String?)?.trim();
    return (code == null || code.isEmpty) ? null : code;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _createCode() async {
    setState(() => _creatingCode = true);
    try {
      await _repository.ensureInviteCode();
      // The new code arrives through the user document stream that feeds
      // widget.userData, so there is nothing to set here.
    } catch (error) {
      _showMessage('Could not create a coach code: $error');
    } finally {
      if (mounted) setState(() => _creatingCode = false);
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    _showMessage('Coach code copied');
  }

  Future<void> _redeemCode() async {
    FocusScope.of(context).unfocus();

    setState(() => _redeeming = true);
    try {
      final name = await _repository.addCoachByCode(_codeController.text);
      _codeController.clear();
      _showMessage('$name can now see your workouts');
    } on CoachLinkException catch (error) {
      // Carries a message written for the user.
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Could not add that coach: $error');
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  Future<void> _confirmRemoveCoach(CoachRef coach) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text(
          'Remove ${coach.name}?',
          style: const TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'They will no longer be able to see your workouts.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          MaterialButton(
            color: Colors.red,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('remove'),
          ),
          MaterialButton(
            color: Colors.green,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _repository.removeCoach(coach.uid);
      _showMessage('${coach.name} no longer has access');
    } catch (error) {
      _showMessage('Could not remove that coach: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  "Coach's Zone",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildAthletes(),
              _buildMyCode(),
              _buildMyCoaches(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAthletes() {
    return _Card(
      title: 'Your athletes',
      child: StreamBuilder<List<Athlete>>(
        stream: _athletes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Hint('Could not load your athletes.');
          }
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final athletes = snapshot.data!;
          if (athletes.isEmpty) {
            return const _Hint(
              'Nobody has added you as their coach yet. Share your coach '
              'code below, and their workouts will show up here.',
            );
          }

          return Column(
            children: [
              for (final athlete in athletes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    backgroundImage: athlete.photoUrl != null
                        ? NetworkImage(athlete.photoUrl!)
                        : null,
                    child: athlete.photoUrl == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(athlete.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AthleteDetailPage(athlete: athlete),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMyCode() {
    final code = _myCode;

    return _Card(
      title: 'Your coach code',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Hint(
            'Give this code to an athlete. They enter it on their own Coach '
            "tab, and you will then see their workouts.",
          ),
          const SizedBox(height: 10),
          if (code == null)
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _creatingCode ? null : _createCode,
                child: _creatingCode
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create my code'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      code,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy',
                  onPressed: () => _copyCode(code),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMyCoaches() {
    final coaches = coachesFrom(widget.userData);

    return _Card(
      title: 'Your coaches',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (coaches.isEmpty)
            const _Hint(
              'Enter a coach code to let someone see your workouts. You can '
              'remove them again at any time.',
            )
          else
            for (final coach in coaches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sports, color: Colors.deepPurple),
                title: Text(coach.name),
                subtitle: coach.linkedAt == null
                    ? null
                    : Text(
                        'since ${coach.linkedAt!.day}.'
                        '${coach.linkedAt!.month}.${coach.linkedAt!.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                trailing: IconButton(
                  tooltip: 'Remove',
                  onPressed: () => _confirmRemoveCoach(coach),
                  icon: Icon(Icons.delete, color: Colors.red[600]),
                ),
              ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Coach code',
                    hintText: 'ABC234',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _redeemCode(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _redeeming ? null : _redeemCode,
                child: _redeeming
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
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
      margin: const EdgeInsets.only(bottom: 20),
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

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black54),
    );
  }
}
