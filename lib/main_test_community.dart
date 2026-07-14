// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// import 'screens/community/community_home_screen.dart.dart';
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
import 'screens/chat/chat_list_screen.dart'; // 채팅 목록
import 'screens/market/market_home_screen.dart';   // 마켓 홈

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: 'test@ddaenggeurang.com',
    password: 'test1234',
  );
  final db = FirebaseFirestore.instance;

  // 기존 chat1, 메시지 2개 만드는 코드 아래에 추가
  await db.collection('chats').doc('chat1').collection('messages').add({
    'senderId': 'user2',
    'type': 'text',
    'text': '이거 아직 판매중이에요?',
    'imageUrl': null,
    'productId': null,
    'sentAt': Timestamp.now(),
  });

// unreadCount 수동으로 증가 (실제로는 sendMessage()가 자동으로 하지만, 테스트용 직접 세팅)
  await db.collection('chats').doc('chat1').update({
    'lastMessage': '이거 아직 판매중이에요?',
    'lastMessageAt': Timestamp.now(),
    'unreadCount.test_user_id': 3,  // 임의로 3개 안읽음 상태 만들기
  });

  runApp(const MaterialApp(
    // home: ChatListScreen(), // 채팅목록
    home: MarketHomeScreen(),   // ← 화면 변경
  ));
}