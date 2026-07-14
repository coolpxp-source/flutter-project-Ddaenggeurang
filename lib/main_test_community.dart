// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'screens/community/CommunityHomeScreen.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//
//   await FirebaseAuth.instance.signInWithEmailAndPassword(
//     email: 'test@ddaenggeurang.com',
//     password: 'test1234',
//   );
//
//   runApp(const MaterialApp(
//     home: CommunityHomeScreen(),
//   ));
// }

// 채팅 화면 test
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/chat/chat_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: 'test@ddaenggeurang.com',
    password: 'test1234',
  );

  runApp(const MaterialApp(
    home: ChatListScreen(),
  ));
}