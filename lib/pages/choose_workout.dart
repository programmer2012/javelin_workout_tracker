import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChooseWorkout extends StatefulWidget {
  final Map<dynamic, dynamic> userData;
  const ChooseWorkout({
    super.key,
    required this.userData,
  });

  @override
  State<ChooseWorkout> createState() => _ChooseWorkoutState();
}

class _ChooseWorkoutState extends State<ChooseWorkout> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // [
  //   {"id": 1, "name": "Bench Press", "isSelected": false},
  //   {"id": 2, "name": "Pull Over", "isSelected": false},
  //   {"id": 3, "name": "Squats", "isSelected": false},
  //   {"id": 4, "name": "Cleans", "isSelected": false},
  //   {"id": 5, "name": "Push Ups", "isSelected": false},
  // ];

  var userData = {};

  List<int> idList = [];
  Map isSelected = {};

  List<dynamic> _foundExercises = [];
  List<dynamic> _exercises = [];

  @override
  void initState() {
    super.initState();
    userData = widget.userData;
    idList = [];
    _exercises = userData['workoutList'];
    _foundExercises = _exercises;
    for (var elem in _foundExercises) {
      isSelected[elem['name']] = false;
    }
  }

  // filter the exercises
  void _runFilter(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      // if the search bar is empty
      results = _exercises;
    } else {
      results = _exercises
          .where((exercise) => exercise["name"]
              .toLowerCase()
              .contains(enteredKeyword.toLowerCase()))
          .toList();
    }

    setState(() {
      _foundExercises = results;
    });
    print('foundExercises $_foundExercises');
  }

  // text controller
  final exerciseNameControler = TextEditingController();

  // delete exercise
  void delete(index) {
    _foundExercises.remove(_foundExercises[index]);
    setState(() {});
    updateFirestore();
  }

  // switch active state and save id to list
  void chosenExercise(index) {
    var exerciseName = _foundExercises[index]["name"];
    if (isSelected.containsKey(exerciseName)) {
      isSelected[exerciseName] = !isSelected[exerciseName];
    } else {
      isSelected[exerciseName] = true;
    }

    setState(() {});

    print(idList);
  }

  void addExercise() {
    Navigator.pop(context, isSelected);
  }

  void createNewExercise() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              title: const Text(
                'Create a new exercise',
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              content: TextField(controller: exerciseNameControler),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: [
                MaterialButton(
                  onPressed: save,
                  child: const Text('save'),
                  color: Colors.green,
                ),
                MaterialButton(
                  onPressed: cancel,
                  child: const Text('cancel'),
                  color: Colors.red,
                )
              ],
            ));
  }

  void updateFirestore() {
    _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .update({'workoutList': _exercises});
  }

  void save() {
    // get exercise name from text controller
    String newExerciseName = exerciseNameControler.text;

    if (newExerciseName.isNotEmpty) {
      _exercises.add({
        "id": _exercises.length + 1,
        'name': newExerciseName,
      });
    }

    isSelected[newExerciseName] = false;

    // pop dialog box
    Navigator.pop(context);
    exerciseNameControler.clear();

    setState(() {});
    updateFirestore();
  }

  void cancel() {
    Navigator.pop(context);
    exerciseNameControler.clear();
  }

  void popAddExercise() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    print(userData);

    print('while build foundExercises $_foundExercises');

    return Scaffold(
      floatingActionButton: Container(
        margin: EdgeInsets.fromLTRB(36.0, 0, 4, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            isSelected.containsValue(true)
                ? FloatingActionButton(
                    heroTag: null,
                    onPressed: addExercise,
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.lightGreen,
                  )
                : Container(
                    width: 0,
                    height: 0,
                  ),
            FloatingActionButton(
              heroTag: null,
              onPressed: createNewExercise,
              child: Icon(
                Icons.add,
                color: Colors.white,
              ),
              backgroundColor: Colors.deepPurple,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
            onPressed: popAddExercise, icon: const Icon(Icons.arrow_back)),
        title: Text('Add Excercise'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ),
            TextField(
              onChanged: (value) => _runFilter(value),
              decoration: const InputDecoration(
                  labelText: 'Search', suffixIcon: Icon(Icons.search)),
            ),
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80.0),
                  itemCount: _foundExercises.length,
                  itemBuilder: (context, index) {
                    String title = _foundExercises[index]['name'];
                    if (title.length > 20) {
                      title = '${title.substring(0, 20)}...';
                    }
                    return Card(
                      key: ValueKey(index),
                      color: Colors.deepPurpleAccent,
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      child: Tooltip(
                        message: _foundExercises[index]['name'],
                        child: ListTile(
                          contentPadding: EdgeInsets.fromLTRB(
                            12,
                            0,
                            0,
                            0,
                          ),
                          selected: false,
                          onTap: () => chosenExercise(index),
                          leading: Text(
                            (index + 1).toString(),
                            style: TextStyle(
                                color: Colors.grey.shade300, fontSize: 15),
                          ),
                          title: Text(title, style: TextStyle(fontSize: 15)),
                          // horizontalTitleGap: 40,
                          trailing: Row(
                            // mainAxisAlignment: MainAxisAlignment.end,
                            // crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fitness_center_sharp,
                                color:
                                    isSelected[_foundExercises[index]['name']]
                                        ? Colors.green
                                        : Colors.grey.shade300,
                              ),
                              IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () => delete(index),
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red[600],
                                  ))
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
            ),
          ],
        ),
      ),
    );
  }
}
