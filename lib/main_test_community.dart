import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/market/market_home_screen.dart'; // 마켓
import 'screens/community/community_home_screen.dart'; // 커뮤니티

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

  // 더미 상품 1
  await db.collection('marketProducts').doc('product1').set({
    'sellerId': 'user2',
    'sellerName': '판매자',
    'sellerAvatarUrl': '',
    'title': '무선 이어폰',
    'price': 39900,
    'description': '거의 새 제품입니다. 직거래 가능해요',
    'images': <String>[],
    'status': 'selling',
    'category': '전자기기',
    'priceComparisons': <Map<String, dynamic>>[],
    'locationGeo': null,
    'verifiedDong': null,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  // 더미 상품 2
  await db.collection('marketProducts').doc('product2').set({
    'sellerId': FirebaseAuth.instance.currentUser!.uid,
    'sellerName': '나',
    'sellerAvatarUrl': '',
    'title': '무선 키보드 팝니다',
    'price': 25000,
    'description': '사용감 적어요',
    'images': <String>[],
    'status': 'selling',
    'category': '전자기기',
    'priceComparisons': <Map<String, dynamic>>[],
    'locationGeo': null,
    'verifiedDong': null,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  });

  runApp(const MaterialApp(
    // home: MarketHomeScreen(), // 마켓
    home: CommunityHomeScreen(), // 커뮤니티
  ));
}