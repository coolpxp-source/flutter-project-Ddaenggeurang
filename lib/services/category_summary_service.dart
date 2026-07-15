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
}