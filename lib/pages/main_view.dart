import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:javelin_workout_tracker/pages/home_page.dart';
import 'package:javelin_workout_tracker/pages/overview_page.dart';

import '../components/line_chart_widget.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int currentIndex = 0;
  final screens = [
    OverviewPage(),
    HomePage(),
    HomePage(),
    HomePage(),
    LineChartPage(
      isShowingMainData: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
