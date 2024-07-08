import 'package:flutter/material.dart';

// ignore: must_be_immutable
class NewSetWidget extends StatelessWidget {
  final TextEditingController reps;
  final TextEditingController weight;
  int index;
  // final String weightBevor;
  // final String repsBevor;
  final Function onDelete;
  final Function updateFirestore;

  NewSetWidget({
    super.key,
    required this.index,
    // required this.weightBevor,
    // required this.repsBevor,
    required this.onDelete,
    required this.reps,
    required this.weight,
    required this.updateFirestore,
  });

  @override
  Widget build(BuildContext context) {
    // adding listeners to the TextEditingControllers
    reps.addListener(() => updateFirestore());
    weight.addListener(() => updateFirestore());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        // Todo Row alignment !!!
        Container(
          alignment: Alignment.center,
          width: 50,
          child: Text((index + 1).toString()),
        ),
        Container(
          width: 75,
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
          width: 80,
          padding: EdgeInsets.symmetric(horizontal: 2.5),
          child: TextFormField(
            textAlign: TextAlign.center,
            controller: weight,
            decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 5),
                border: OutlineInputBorder(gapPadding: 10),
                isDense: true),
            keyboardType: TextInputType.number,
          ),
        ),
        Container(
            alignment: Alignment.center,
            width: 60,
            child: IconButton(
                onPressed: () => onDelete(index),
                icon: Icon(
                  Icons.delete,
                  color: Colors.red,
                )))
      ],
    );
  }
}
