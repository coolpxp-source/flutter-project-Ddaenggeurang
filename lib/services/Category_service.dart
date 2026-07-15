
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/category_summary_model.dart';

class CategorySummaryService {
  /// Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// FirebaseAuth 인스턴스
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Firestore에 저장되는 카테고리 키와
  /// 화면에 표시할 한글 이름
  static const Map<String, String> categoryNames = {
    'food': '식비',
    'transport': '교통',
    'shopping': '쇼핑',
    'culture': '문화',
    'housing': '주거',
    'etc': '기타',
  };

  /// 현재 로그인 사용자 확인
  void _checkUser(String userId) {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자가 일치하지 않습니다.');
    }
  }

  /// ============================================================
  /// 카테고리별 통계 조회
  /// ============================================================
  Future<List<CategorySummaryModel>> getCategorySummary({
    required String userId,
    required int year,
    required int month,
  }) async {
    _checkUser(userId);

    final DateTime monthStart = DateTime(year, month, 1);
    final DateTime nextMonth = DateTime(year, month + 1, 1);

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where(
      'date',
      isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
    )
        .where(
      'date',
      isLessThan: Timestamp.fromDate(nextMonth),
    )
        .get();

    /// 카테고리별 금액 저장
    final Map<String, int> totals = {
      for (String key in categoryNames.keys) key: 0,
    };

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
    in snapshot.docs) {
      final data = doc.data();

      final int amount =
          (data['amount'] as num?)?.toInt() ?? 0;

      if (amount <= 0) continue;

      final String category =
      (data['categoryId'] ??
          data['category'] ??
          'etc')
          .toString();

      final String key =
      categoryNames.containsKey(category)
          ? category
          : 'etc';

      totals[key] = (totals[key] ?? 0) + amount;
    }

    /// 전체 지출
    final int totalExpense =
    totals.values.fold<int>(
      0,
          (int sum, int value) => sum + value,
    );

    /// 결과 리스트
    final List<CategorySummaryModel> result = [];

    totals.forEach((key, value) {
      if (value == 0) return;

      result.add(
        CategorySummaryModel(
          categoryKey: key,
          categoryName: categoryNames[key]!,
          totalAmount: value,
          percentage: totalExpense == 0
              ? 0
              : value / totalExpense * 100,
        ),
      );
    });

    /// 금액 내림차순
    result.sort(
          (CategorySummaryModel a,
          CategorySummaryModel b) =>
          b.totalAmount.compareTo(a.totalAmount),
    );

    return result;
  }

  /// ============================================================
  /// 이번 달 총 지출
  /// ============================================================
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

    int total = 0;

    for (final CategorySummaryModel item
    in summaries) {
      total += item.totalAmount;
    }

    return total;
  }

  /// ============================================================
  /// 카테고리별 금액 Map
  /// ============================================================
  Future<Map<String, int>> getCategoryAmountMap({
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

    final Map<String, int> map = {};

    for (final CategorySummaryModel item
    in summaries) {
      map[item.categoryKey] = item.totalAmount;
    }

    return map;
  }

  /// ============================================================
  /// 가장 많이 소비한 카테고리
  /// ============================================================
  Future<CategorySummaryModel?> getTopCategory({
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

    if (summaries.isEmpty) {
      return null;
    }

    return summaries.first;
  }
}