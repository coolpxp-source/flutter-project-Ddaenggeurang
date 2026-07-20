import 'package:ddaenggeurang/screens/avatar/my_avatar_screen.dart';
import 'package:ddaenggeurang/screens/mission/mission_admin_approval_screen.dart';
import 'package:ddaenggeurang/screens/mission/mission_list_screen.dart';
import 'package:ddaenggeurang/screens/psychology/personalized_budget_recommendation_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/budget/budget_setting_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PersonalizedBudgetRecommendationScreen(
        resultType: 'planned_spender',
      ),
    ),
  );
}