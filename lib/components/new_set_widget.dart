import 'package:flutter/material.dart';

class NewSetWidget extends StatelessWidget {
  final TextEditingController reps = TextEditingController();
  final TextEditingController weight = TextEditingController();
  final length;
  final weightBevor;
  final repsBevor;
  NewSetWidget({super.key, this.length, this.weightBevor, this.repsBevor});

  @override
  Widget build(BuildContext context) {
    reps.text = repsBevor;
    weight.text = weightBevor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            width: 50,
            child: Text((length + 1).toString()),
          ),
          Container(
            width: 100,
            child: TextFormField(
              textAlign: TextAlign.center,
              controller: reps,
              decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 5),
                  border: OutlineInputBorder(gapPadding: 10),
                  isDense: true),
              keyboardType: TextInputType.number,
            ),
          ),
          Container(
            width: 100,
            child: TextFormField(
              textAlign: TextAlign.center,
              controller: weight,
              decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 5),
                  border: OutlineInputBorder(gapPadding: 10),
                  isDense: true),
              keyboardType: TextInputType.number,
            ),
          )
        ],
      ),
    );
  }
}
