import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:javelin_workout_tracker/firebase_options.dart';
import 'package:javelin_workout_tracker/pages/auth_pages/auth_page.dart';
import 'package:javelin_workout_tracker/pages/home_page.dart';
import 'package:javelin_workout_tracker/pages/main_view.dart';
import 'package:javelin_workout_tracker/pages/overview_page.dart';
// import 'package:javelin_workout_tracker/pages/home_page.dart';
// import 'package:javelin_workout_tracker/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: GoogleFonts.kdamThmorPro().fontFamily,
      ),
      debugShowCheckedModeBanner: false,
      home: MainView(),
    );
  }
}
