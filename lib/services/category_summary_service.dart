import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/category_summary_model.dart';

class CategorySummaryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Firestore 카테고리 키와 화면 표시 이름
  static const Map<String, String> categoryNames = {
    'food': '식비',
    'transport': '교통',
    'shopping': '쇼핑',
    'culture': '문화',
    'housing': '주거',
    'etc': '기타',
  };

  /// 현재 로그인 사용자 확인
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

  /// 사용자의 expenses 서브컬렉션
  ///
  /// 경로:
  /// users/{userId}/expenses/{expenseId}
  CollectionReference<Map<String, dynamic>> _expenseCollection(
      String userId,
      ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses');
  }

  /// 조회 월의 시작일
  DateTime _getMonthStart({
    required int year,
    required int month,
  }) {
    return DateTime(year, month, 1);
  }

  /// 다음 달 시작일
  DateTime _getNextMonthStart({
    required int year,
    required int month,
  }) {
    return DateTime(year, month + 1, 1);
  }

  /// 특정 월의 카테고리별 지출 집계
  Future<List<CategorySummaryModel>> getCategorySummary({
    required String userId,
    required int year,
    required int month,
  }) async {
    _requireCurrentUser(userId);

    final DateTime monthStart = _getMonthStart(
      year: year,
      month: month,
    );

    final DateTime nextMonthStart = _getNextMonthStart(
      year: year,
      month: month,
    );

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _expenseCollection(userId)
        .where(
      'date',
      isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
    )
        .where(
      'date',
      isLessThan: Timestamp.fromDate(nextMonthStart),
    )
        .get();

    final Map<String, int> categoryTotals = {
      for (final String key in categoryNames.keys) key: 0,
    };

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final int amount = (data['amount'] as num?)?.toInt() ?? 0;

      if (amount <= 0) {
        continue;
      }

      // 설계 기준 필드명은 categoryId
      final String categoryId =
          data['categoryId'] as String? ?? 'etc';

      final String normalizedCategory =
      categoryNames.containsKey(categoryId)
          ? categoryId
          : 'etc';

      categoryTotals[normalizedCategory] =
          (categoryTotals[normalizedCategory] ?? 0) + amount;
    }

    final int totalExpense = categoryTotals.values.fold<int>(
      0,
          (int sum, int amount) => sum + amount,
    );

    final List<CategorySummaryModel> summaries =
    categoryTotals.entries
        .where(
          (MapEntry<String, int> entry) => entry.value > 0,
    )
        .map(
          (MapEntry<String, int> entry) {
        final double percentage = totalExpense == 0
            ? 0
            : entry.value / totalExpense * 100;

        return CategorySummaryModel(
          categoryKey: entry.key,
          categoryName:
          categoryNames[entry.key] ?? '기타',
          totalAmount: entry.value,
          percentage: percentage,
        );
      },
    )
        .toList();

    summaries.sort(
          (
          CategorySummaryModel a,
          CategorySummaryModel b,
          ) =>
          b.totalAmount.compareTo(a.totalAmount),
    );

    return summaries;
  }

  /// 특정 월의 전체 지출 합계
  Future<int> getMonthlyTotalExpense({
    required String userId,
    required int year,
    required int month,
  }) async {
    final List<CategorySummaryModel> summaries =
    await getCategorySummary(
      userId: userId,
      year: year,
      month: month,
    );

    return summaries.fold<int>(
      0,
          (
          int sum,
          CategorySummaryModel item,
          ) =>
      sum + item.totalAmount,
    );
  }

  /// [weekStart] 00:00부터 7일간의 지출 합계 (홈 대시보드 "이번 주 지출" 카드용)
  Future<int> getWeeklyTotalExpense({
    required String userId,
    required DateTime weekStart,
  }) async {
    _requireCurrentUser(userId);

    final DateTime start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final DateTime end = start.add(const Duration(days: 7));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _expenseCollection(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.fold<int>(0, (int sum, doc) {
      final int amount = (doc.data()['amount'] as num?)?.toInt() ?? 0;
      return amount > 0 ? sum + amount : sum;
    });
  }

  /// 특정 월의 일자별 지출 합계 — 홈 대시보드 주간 달력 스트립용 (key = 일(day))
  Future<Map<int, int>> getDailyTotals({
    required String userId,
    required int year,
    required int month,
  }) async {
    _requireCurrentUser(userId);

    final DateTime monthStart = _getMonthStart(year: year, month: month);
    final DateTime nextMonthStart = _getNextMonthStart(year: year, month: month);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _expenseCollection(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('date', isLessThan: Timestamp.fromDate(nextMonthStart))
        .get();

    final Map<int, int> totals = {};
    for (final doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final int amount = (data['amount'] as num?)?.toInt() ?? 0;
      final DateTime? date = (data['date'] as Timestamp?)?.toDate();
      if (date == null || amount <= 0) continue;
      totals[date.day] = (totals[date.day] ?? 0) + amount;
    }
    return totals;
  }

  /// 최근 지출 N건 (최신순) — 홈 대시보드 "최근 지출" 목록용
  Future<List<RecentExpenseEntry>> getRecentExpenses({
    required String userId,
    int limit = 5,
  }) async {
    _requireCurrentUser(userId);

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _expenseCollection(userId)
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final Map<String, dynamic> data = doc.data();
      final int amount = (data['amount'] as num?)?.toInt() ?? 0;
      final String categoryId = data['categoryId'] as String? ?? 'etc';
      final DateTime date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
      return RecentExpenseEntry(
        categoryKey: categoryId,
        categoryName: categoryNames[categoryId] ?? '기타',
        amount: amount,
        date: date,
      );
    }).toList();
  }
}