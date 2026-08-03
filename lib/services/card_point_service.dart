import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/card_point_model.dart';
import '../models/card_point_history_model.dart';

class CardPointService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _cardPointsRef(String userId) =>
      _db.collection('users').doc(userId).collection('cardPoints');

  /// 100_카드포인트목록
  Stream<List<CardPointModel>> getCardPoints({required String userId}) {
    return _cardPointsRef(userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CardPointModel.fromFirestore(d)).toList());
  }

  /// 카드 추가
  Future<void> addCard({required String userId, required CardPointModel card}) async {
    await _cardPointsRef(userId).add(card.toFirestore());
  }

  /// 101_카드포인트상세 - history 서브컬렉션
  Stream<List<CardPointHistoryModel>> getCardPointHistory({
    required String userId,
    required String cardId,
  }) {
    return _cardPointsRef(userId)
        .doc(cardId)
        .collection('history')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CardPointHistoryModel.fromFirestore(d)).toList());
  }

  CollectionReference<Map<String, dynamic>> _historyRef(String userId, String cardId) =>
      _cardPointsRef(userId).doc(cardId).collection('history');

  /// 포인트 적립/사용 내역 추가 + 카드 보유/소멸예정 포인트 자동 반영
  Future<void> addHistory({
    required String userId,
    required String cardId,
    required CardPointHistoryModel history,
  }) async {
    final cardRef = _cardPointsRef(userId).doc(cardId);
    final historyRef = _historyRef(userId, cardId).doc();

    await _db.runTransaction((transaction) async {
      final cardSnap = await transaction.get(cardRef);
      if (!cardSnap.exists) {
        throw Exception('카드를 찾을 수 없어요.');
      }

      final data = cardSnap.data() ?? {};
      final currentTotal = (data['totalPoint'] as num?)?.toInt() ?? 0;
      final currentExpiring = (data['expiringPoint'] as num?)?.toInt() ?? 0;

      late final int newTotal;
      late final int newExpiring;

      if (history.type == 'earn') {
        newTotal = currentTotal + history.point;
        newExpiring = currentExpiring; // 신규 적립분은 소멸예정에 영향 없음
      } else {
        newTotal = currentTotal - history.point;
        if (newTotal < 0) {
          throw Exception('사용 포인트가 보유 포인트보다 많아요.');
        }
        // 소멸 임박 포인트부터 우선 차감 (0 밑으로는 안 내려감)
        newExpiring = (currentExpiring - history.point).clamp(0, currentExpiring);
      }

      transaction.set(historyRef, history.toFirestore());
      transaction.update(cardRef, {
        'totalPoint': newTotal,
        'expiringPoint': newExpiring,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}