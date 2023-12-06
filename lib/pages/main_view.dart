import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/pages/add_workout_page.dart';
import 'package:javelin_workout_tracker/pages/home_page.dart';
import 'package:javelin_workout_tracker/pages/overview_page.dart';

import '../components/line_chart_widget.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  var userData = {};
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    getData();
  }

  getData() async {
    try {
      var snap = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      userData = snap.data()!;
      setState(() {});
    } catch (e) {
      print('fehler');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      OverviewPage(
        userData: userData,
      ),
      const HomePage(),
      const AddWorkoutPage(),
      const HomePage(),
      const LineChartPage(
        isShowingMainData: false,
      ),
    ];
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: screens[currentIndex],
      bottomNavigationBar: CurvedNavigationBar(
        height: 60,
        index: currentIndex,
        backgroundColor: Colors.deepPurple,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          Icon(Icons.home),
          Icon(Icons.fitness_center),
          Icon(Icons.add),
          Icon(Icons.sports),
          Icon(Icons.bar_chart),
        ],
      ),
    );
  }
}
