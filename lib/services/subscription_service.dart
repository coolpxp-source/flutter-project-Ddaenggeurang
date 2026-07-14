import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/subscription_model.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 최상위 subscriptions 컬렉션
  CollectionReference<Map<String, dynamic>> get _subscriptionCollection {
    return _firestore.collection('subscriptions');
  }

  /// 현재 사용자의 구독 목록 실시간 조회
  Stream<List<SubscriptionModel>> getSubscriptions(String userId) {
    debugPrint('============================');
    debugPrint('구독 목록 조회 시작');
    debugPrint('조회 userId: $userId');
    debugPrint('현재 로그인 UID: ${_auth.currentUser?.uid}');
    debugPrint('============================');

    return _subscriptionCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      debugPrint('조회된 구독 개수: ${snapshot.docs.length}');

      final List<SubscriptionModel> subscriptions =
      snapshot.docs.map((doc) {
        debugPrint('조회 문서 ID: ${doc.id}');
        debugPrint('조회 데이터: ${doc.data()}');

        return SubscriptionModel.fromDocument(doc);
      }).toList();

      subscriptions.sort(
            (a, b) => a.paymentDay.compareTo(b.paymentDay),
      );

      return subscriptions;
    })
        .handleError((error, stackTrace) {
      debugPrint('============================');
      debugPrint('구독 목록 조회 실패');
      debugPrint('오류 내용: $error');
      debugPrint('스택트레이스:');
      debugPrint('$stackTrace');
      debugPrint('============================');
    });
  }

  /// 새로운 구독 추가
  Future<void> addSubscription({
    required String userId,
    required String name,
    required int amount,
    required int paymentDay,
  }) async {
    final User? currentUser = _auth.currentUser;

    debugPrint('============================');
    debugPrint('구독 저장 시작');
    debugPrint('전달받은 userId: $userId');
    debugPrint('로그인 사용자 UID: ${currentUser?.uid}');
    debugPrint('로그인 사용자 이메일: ${currentUser?.email}');
    debugPrint('============================');

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception(
        '사용자 UID가 일치하지 않습니다.\n'
            '전달 UID: $userId\n'
            '로그인 UID: ${currentUser.uid}',
      );
    }

    final DocumentReference<Map<String, dynamic>> document =
    await _subscriptionCollection.add({
      'userId': currentUser.uid,
      'name': name,
      'amount': amount,
      'paymentDay': paymentDay,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('구독 저장 완료');
    debugPrint('구독 문서 ID: ${document.id}');
    debugPrint('저장 사용자 UID: ${currentUser.uid}');
  }

  /// 구독 수정
  Future<void> updateSubscription({
    required String userId,
    required String subscriptionId,
    required String name,
    required int amount,
    required int paymentDay,
    required bool isActive,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자 UID가 일치하지 않습니다.');
    }

    await _subscriptionCollection.doc(subscriptionId).update({
      'userId': currentUser.uid,
      'name': name,
      'amount': amount,
      'paymentDay': paymentDay,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('구독 수정 완료: $subscriptionId');
  }

  /// 구독 삭제
  Future<void> deleteSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자 UID가 일치하지 않습니다.');
    }

    await _subscriptionCollection.doc(subscriptionId).delete();

    debugPrint('구독 삭제 완료: $subscriptionId');
  }
}