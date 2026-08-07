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

  /// 카드 단건 실시간 구독 — 상세화면 히어로 카드 갱신용
  Stream<CardPointModel?> getCardPointById({
    required String userId,
    required String cardId,
  }) {
    return _cardPointsRef(userId)
        .doc(cardId)
        .snapshots()
        .map((doc) => doc.exists ? CardPointModel.fromFirestore(doc) : null);
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
  // 카드삭제
  Future<void> deleteCard({
    required String userId,
    required String cardId,
  }) async {
    await _cardPointsRef(userId).doc(cardId).delete();
  }

  /// 포인트 내역 수정 — 기존 반영분을 되돌리고 새 값을 다시 반영
  Future<void> updateHistory({
    required String userId,
    required String cardId,
    required CardPointHistoryModel oldHistory,
    required CardPointHistoryModel newHistory,
  }) async {
    final cardRef = _cardPointsRef(userId).doc(cardId);
    final historyRef = _historyRef(userId, cardId).doc(oldHistory.historyId);

    await _db.runTransaction((transaction) async {
      final cardSnap = await transaction.get(cardRef);
      if (!cardSnap.exists) {
        throw Exception('카드를 찾을 수 없어요.');
      }

      final data = cardSnap.data() ?? {};
      var total = (data['totalPoint'] as num?)?.toInt() ?? 0;
      var expiring = (data['expiringPoint'] as num?)?.toInt() ?? 0;

      // 1) 기존 내역이 반영했던 효과를 되돌림
      if (oldHistory.type == 'earn') {
        total -= oldHistory.point;
      } else {
        total += oldHistory.point;
        // 사용 시 깎였던 expiringPoint는 정확히 복원 불가하므로 되돌리지 않음
        // (아래 신규 적용에서도 사용 건은 expiring을 다시 깎지 않도록 처리)
      }

      // 2) 새 내역의 효과를 반영
      if (newHistory.type == 'earn') {
        total += newHistory.point;
      } else {
        total -= newHistory.point;
        if (total < 0) {
          throw Exception('사용 포인트가 보유 포인트보다 많아요.');
        }
        expiring = (expiring - newHistory.point).clamp(0, expiring);
      }

      if (total < 0) {
        throw Exception('수정 결과 보유 포인트가 음수가 돼요.');
      }

      transaction.set(historyRef, newHistory.toFirestore());
      transaction.update(cardRef, {
        'totalPoint': total,
        'expiringPoint': expiring,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// 포인트 내역 삭제 — 반영됐던 효과를 되돌림
  Future<void> deleteHistory({
    required String userId,
    required String cardId,
    required CardPointHistoryModel history,
  }) async {
    final cardRef = _cardPointsRef(userId).doc(cardId);
    final historyRef = _historyRef(userId, cardId).doc(history.historyId);

    await _db.runTransaction((transaction) async {
      final cardSnap = await transaction.get(cardRef);
      if (!cardSnap.exists) {
        throw Exception('카드를 찾을 수 없어요.');
      }

      final data = cardSnap.data() ?? {};
      var total = (data['totalPoint'] as num?)?.toInt() ?? 0;

      if (history.type == 'earn') {
        total -= history.point;
      } else {
        total += history.point;
      }

      if (total < 0) {
        throw Exception('삭제 결과 보유 포인트가 음수가 돼요.');
      }

      transaction.delete(historyRef);
      transaction.update(cardRef, {
        'totalPoint': total,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}