import 'package:flutter/material.dart';

class AddWorkoutPage extends StatefulWidget {
  const AddWorkoutPage({super.key});

  @override
  State<AddWorkoutPage> createState() => _AddWorkoutPageState();
}

class _AddWorkoutPageState extends State<AddWorkoutPage> {
  bool toggleWorkout = true;

  @override
  Widget build(BuildContext context) {
    toggleAddWorkout() {
      toggleWorkout = !toggleWorkout;
      setState(() {});
    }

    return Scaffold(
      backgroundColor: Colors.deepPurple,
      appBar: AppBar(
        title: const Center(child: Text('Add a new Workout')),
      ),
      body: toggleWorkout
          ? Center(
              child: FloatingActionButton(
                  onPressed: toggleAddWorkout, child: const Icon(Icons.add)),
            )
          : Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 50, vertical: 50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey.shade200),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Choose next exercise'),
                            IconButton(onPressed: () {}, icon: Icon(Icons.add))
                          ]),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
