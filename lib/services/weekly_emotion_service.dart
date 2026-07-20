import 'package:cloud_firestore/cloud_firestore.dart';

/// 이번 주 감정 태그별 지출을 집계한다.
/// EmotionSummaryService(임예림)는 월 단위만 지원해서, 홈 화면의 "이번 주 감정
/// 온도계" 카드를 위해 같은 데이터 경로(users/{uid}/expenses)를 주 단위로
/// 직접 읽는다 — 읽기 전용이라 임예림 파트 파일은 건드리지 않는다.
class WeeklyEmotionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// emotionKey → 합계 금액. 태그가 없는 지출은 'none'으로 묶는다.
  Future<Map<String, int>> getWeeklyEmotionTotals({
    required String userId,
    required DateTime weekStart,
  }) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final totals = <String, int>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amountValue = data['amount'];
      final amount = amountValue is num
          ? amountValue.toInt()
          : int.tryParse(amountValue?.toString() ?? '') ?? 0;
      if (amount <= 0) continue;

      final emotion = data['emotionTag'];
      final key = (emotion is String && emotion.isNotEmpty) ? emotion : 'none';
      totals[key] = (totals[key] ?? 0) + amount;
    }
    return totals;
  }
}
