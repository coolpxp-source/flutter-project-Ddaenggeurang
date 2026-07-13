import 'package:flutter/material.dart';
import 'screens/mission/mission_list_screen.dart';

void main() {
  runApp(const TaehwaTestApp());
}

class TaehwaTestApp extends StatelessWidget {
  const TaehwaTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MissionListScreen(),
    );
  }
}