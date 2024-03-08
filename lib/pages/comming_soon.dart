import 'package:flutter/material.dart';

class CommingSoon extends StatelessWidget {
  const CommingSoon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Text(
          'Comming Soon',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
