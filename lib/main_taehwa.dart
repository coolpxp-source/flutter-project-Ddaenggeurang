import 'package:ddaenggeurang/screens/avatar/my_avatar_screen.dart';
import 'package:ddaenggeurang/screens/mission/mission_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MissionListScreen(),
    ),
  );
}