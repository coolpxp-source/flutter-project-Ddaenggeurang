import 'package:ddaenggeurang/screens/avatar/my_avatar_screen.dart';
import 'package:flutter/material.dart';
import 'screens/mission/mission_list_screen.dart';
import 'screens/mission/mission_admin_approval_screen.dart';

void main() {
  runApp(const TaehwaTestApp());
}

class TaehwaTestApp extends StatelessWidget {
  const TaehwaTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MissionAdminApprovalScreen(),
    );
  }
}