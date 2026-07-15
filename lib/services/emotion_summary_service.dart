import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/emotion_summary_model.dart';

class EmotionSummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 감정 태그 이름
  static const Map<String, String> emotionNames = {
    'planned': '계획소비',
    'impulsive': '충동소비',
    'stress': '스트레스',
    'social': '사교',
    'reward': '보상',
    'none': '태그없음',
  };

  /// 현재 로그인 사용자 확인
  void _requireCurrentUser(String userId) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자 UID가 일치하지 않습니다.');
    }
  }

  /// users/{uid}/expenses 컬렉션
  CollectionReference<Map<String, dynamic>> _expenseCollection(
      String userId,
      ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses');
  }

  /// 선택한 달의 시작일
  DateTime _monthStart(int year, int month) {
    return DateTime(year, month, 1);
  }

  /// 다음 달의 시작일
  DateTime _nextMonthStart(int year, int month) {
    return DateTime(year, month + 1, 1);
  }

  /// 감정 태그별 지출 통계 조회
  Future<List<EmotionSummaryModel>> getEmotionSummary({
    required String userId,
    required int year,
    required int month,
  }) async {
    _requireCurrentUser(userId);

    final DateTime startDate = _monthStart(year, month);
    final DateTime endDate = _nextMonthStart(year, month);

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _expenseCollection(userId)
        .where(
      'date',
      isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
    )
        .where(
      'date',
      isLessThan: Timestamp.fromDate(endDate),
    )
        .get();

    final Map<String, int> emotionTotals = {
      for (final String key in emotionNames.keys) key: 0,
    };

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final dynamic amountValue = data['amount'];

      int amount = 0;

      if (amountValue is int) {
        amount = amountValue;
      } else if (amountValue is double) {
        amount = amountValue.toInt();
      } else if (amountValue is num) {
        amount = amountValue.toInt();
      } else if (amountValue is String) {
        amount = int.tryParse(
          amountValue.replaceAll(',', ''),
        ) ??
            0;
      }

      if (amount <= 0) {
        continue;
      }

      final dynamic emotionValue = data['emotionTag'];

      final String emotion =
      emotionValue is String && emotionValue.isNotEmpty
          ? emotionValue
          : 'none';

      final String emotionKey =
      emotionNames.containsKey(emotion) ? emotion : 'none';

      emotionTotals[emotionKey] =
          (emotionTotals[emotionKey] ?? 0) + amount;
    }

    final int totalAmount = emotionTotals.values.fold<int>(
      0,
          (int sum, int amount) => sum + amount,
    );

    final List<EmotionSummaryModel> result = emotionTotals.entries
        .where(
          (MapEntry<String, int> entry) => entry.value > 0,
    )
        .map(
          (MapEntry<String, int> entry) {
        return EmotionSummaryModel(
          emotionKey: entry.key,
          emotionName: emotionNames[entry.key] ?? '태그없음',
          totalAmount: entry.value,
          percentage: totalAmount == 0
              ? 0.0
              : (entry.value / totalAmount) * 100,
        );
      },
    )
        .toList();

    result.sort(
          (EmotionSummaryModel a, EmotionSummaryModel b) {
        return b.totalAmount.compareTo(a.totalAmount);
      },
    );

    return result;
  }

  /// 해당 월의 총 지출 금액 조회
  Future<int> getMonthlyTotalExpense({
    required String userId,
    required int year,
    required int month,
  }) async {
    final List<EmotionSummaryModel> summaryList =
    await getEmotionSummary(
      userId: userId,
      year: year,
      month: month,
    );

    return summaryList.fold<int>(
      0,
          (
          int sum,
          EmotionSummaryModel item,
          ) {
        return sum + item.totalAmount;
      },
    );
  }
}