import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PsychologyTestService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    return user.uid;
  }

  // 테스트 결과 저장 메서드
  Future<String> saveTestResult({
    required String resultType,
    required int totalScore,
  }) async {
    final resultRef = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('testResults')
        .doc();

    await resultRef.set({
      'testType': 'consumption_psychology',
      'resultType': resultType,
      'totalScore': totalScore,
      'recommendedProductIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return resultRef.id;
  }

  // 최신 소비심리 테스트 결과 조회 메서드
  Future<Map<String, dynamic>?> getLatestTestResult() async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('testResults')
        .where(
      'testType',
      isEqualTo: 'consumption_psychology',
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    final document = querySnapshot.docs.first;

    return {
      'id': document.id,
      ...document.data(),
    };
  }
}