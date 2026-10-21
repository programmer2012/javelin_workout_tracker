import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:javelin_workout_tracker/models/workout_set.dart';

/// One editable row of a set. It owns its text controllers and disposes them,
/// and writes edits straight back into the [WorkoutSet] it was given before
/// notifying the page via [onChanged].
class NewSetWidget extends StatefulWidget {
  final WorkoutSet set;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const NewSetWidget({
    super.key,
    required this.set,
    required this.index,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<NewSetWidget> createState() => _NewSetWidgetState();
}

class _NewSetWidgetState extends State<NewSetWidget> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: _format(widget.set.reps));
    _weight = TextEditingController(text: _format(widget.set.weight));
  }

  @override
  void didUpdateWidget(covariant NewSetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only adopt values that changed underneath us (e.g. a remote update);
    // never overwrite what the user is currently typing.
    _syncIfChanged(_reps, _format(widget.set.reps));
    _syncIfChanged(_weight, _format(widget.set.weight));
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _syncIfChanged(TextEditingController controller, String value) {
    if (controller.text == value) return;
    final parsedSame = (double.tryParse(controller.text.replaceAll(',', '.')) ??
            (controller.text.isEmpty ? 0 : null)) ==
        double.tryParse(value);
    if (parsedSame) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  static String _format(num value) {
    if (value == 0) return '';
    if (value is int || value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toString();
  }

  void _onRepsChanged(String value) {
    widget.set.reps = int.tryParse(value.trim()) ?? 0;
    widget.onChanged();
  }

  void _onWeightChanged(String value) {
    widget.set.weight =
        double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        SizedBox(
          width: 50,
          child: Text(
            (widget.index + 1).toString(),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 75,
          child: TextFormField(
            textAlign: TextAlign.center,
            controller: _reps,
            onChanged: _onRepsChanged,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 5),
              border: OutlineInputBorder(gapPadding: 10),
              isDense: true,
            ),
          ),
        ),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: TextFormField(
            textAlign: TextAlign.center,
            controller: _weight,
            onChanged: _onWeightChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(vertical: 5),
              border: OutlineInputBorder(gapPadding: 10),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ),
      ],
    );
  }
}
