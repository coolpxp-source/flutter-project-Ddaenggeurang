import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/subscription_model.dart';

class SubscriptionService {
  // Firestore 접근 객체
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인 사용자 확인 객체
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 최상위 subscriptions 컬렉션
  ///
  /// 구조:
  /// subscriptions/{subscriptionId}
  CollectionReference<Map<String, dynamic>> get _subscriptionCollection {
    return _firestore.collection('subscriptions');
  }

  /// 로그인 상태와 사용자 UID 확인
  User _requireCurrentUser(String userId) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자 UID가 일치하지 않습니다.');
    }

    return currentUser;
  }

  /// 현재 사용자의 구독 목록 실시간 조회
  Stream<List<SubscriptionModel>> getSubscriptions(String userId) {
    _requireCurrentUser(userId);

    return _subscriptionCollection
        .where(
      'userId',
      isEqualTo: userId,
    )
        .snapshots()
        .map((snapshot) {
      final List<SubscriptionModel> subscriptions =
      snapshot.docs.map((document) {
        return SubscriptionModel.fromDocument(document);
      }).toList();

      // 결제일이 빠른 순서대로 정렬
      subscriptions.sort(
            (a, b) => a.paymentDay.compareTo(b.paymentDay),
      );

      return subscriptions;
    });
  }

  /// 새로운 구독 추가
  Future<void> addSubscription({
    required String userId,
    required String name,
    required int amount,
    required int paymentDay,
  }) async {
    final User currentUser = _requireCurrentUser(userId);

    final String trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      throw Exception('구독 서비스명을 입력하세요.');
    }

    if (amount <= 0) {
      throw Exception('구독 금액은 0원보다 커야 합니다.');
    }

    if (paymentDay < 1 || paymentDay > 31) {
      throw Exception(
        '결제일은 1일부터 31일 사이여야 합니다.',
      );
    }

    await _subscriptionCollection.add({
      // 사용자 구분용 UID
      'userId': currentUser.uid,

      // 구독 서비스명
      'name': trimmedName,

      // 월 결제 금액
      'amount': amount,

      // 매월 결제일
      'paymentDay': paymentDay,

      // 현재 이용 중 여부
      'isActive': true,

      // 생성 시간
      'createdAt': FieldValue.serverTimestamp(),

      // 수정 시간
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 기존 구독 정보 수정
  Future<void> updateSubscription({
    required String userId,
    required String subscriptionId,
    required String name,
    required int amount,
    required int paymentDay,
    required bool isActive,
  }) async {
    final User currentUser = _requireCurrentUser(userId);

    final String trimmedName = name.trim();

    if (subscriptionId.trim().isEmpty) {
      throw Exception('구독 문서 ID가 없습니다.');
    }

    if (trimmedName.isEmpty) {
      throw Exception('구독 서비스명을 입력하세요.');
    }

    if (amount <= 0) {
      throw Exception('구독 금액은 0원보다 커야 합니다.');
    }

    if (paymentDay < 1 || paymentDay > 31) {
      throw Exception(
        '결제일은 1일부터 31일 사이여야 합니다.',
      );
    }

    final DocumentReference<Map<String, dynamic>> reference =
    _subscriptionCollection.doc(subscriptionId);

    final DocumentSnapshot<Map<String, dynamic>> document =
    await reference.get();

    if (!document.exists) {
      throw Exception('수정할 구독 정보가 없습니다.');
    }

    final Map<String, dynamic> data = document.data() ?? {};
    final String ownerId = data['userId'] as String? ?? '';

    // 다른 사용자의 구독 수정 방지
    if (ownerId != currentUser.uid) {
      throw Exception('해당 구독을 수정할 권한이 없습니다.');
    }

    await reference.update({
      'userId': currentUser.uid,
      'name': trimmedName,
      'amount': amount,
      'paymentDay': paymentDay,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 구독 삭제
  Future<void> deleteSubscription({
    required String userId,
    required String subscriptionId,
  }) async {
    final User currentUser = _requireCurrentUser(userId);

    if (subscriptionId.trim().isEmpty) {
      throw Exception('구독 문서 ID가 없습니다.');
    }

    final DocumentReference<Map<String, dynamic>> reference =
    _subscriptionCollection.doc(subscriptionId);

    final DocumentSnapshot<Map<String, dynamic>> document =
    await reference.get();

    if (!document.exists) {
      throw Exception('삭제할 구독 정보가 없습니다.');
    }

    final Map<String, dynamic> data = document.data() ?? {};
    final String ownerId = data['userId'] as String? ?? '';

    // 다른 사용자의 구독 삭제 방지
    if (ownerId != currentUser.uid) {
      throw Exception('해당 구독을 삭제할 권한이 없습니다.');
    }

    await reference.delete();
  }
}