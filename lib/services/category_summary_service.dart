import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/category_summary_model.dart';

/// expenses 컬렉션을 기준으로
/// 월별/주별/일별/최근 지출 통계를 계산하는 서비스
class CategorySummaryService {
  final FirebaseFirestore _firestore;

  CategorySummaryService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  /// 최상위 expenses 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _expenseCollection {
    return _firestore.collection('expenses');
  }

  /// categories 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _categoryCollection {
    return _firestore.collection('categories');
  }

  // =========================================================
  // 1. 월별 카테고리 집계
  // =========================================================

  /// 선택한 월의 지출을 categoryId별로 합산한다.
  ///
  /// 사용 예:
  ///
  /// getCategorySummary(
  ///   userId: uid,
  ///   year: 2026,
  ///   month: 7,
  /// );
  Future<List<CategorySummaryModel>>
  getCategorySummary({
    required String userId,
    required int year,
    required int month,
  }) async {
    if (userId.trim().isEmpty) {
      return <CategorySummaryModel>[];
    }

    final DateTime startDate = DateTime(
      year,
      month,
      1,
    );

    final DateTime endDate = DateTime(
      year,
      month + 1,
      1,
    );

    final List<_ExpenseData> expenses =
    await _loadUserExpenses(
      userId: userId,
    );

    /// categoryId별 지출 합계
    final Map<String, int> categoryTotals =
    <String, int>{};

    for (final _ExpenseData expense
    in expenses) {
      final bool isSelectedMonth =
          !expense.date.isBefore(startDate) &&
              expense.date.isBefore(endDate);

      if (!isSelectedMonth) {
        continue;
      }

      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ??
              0) +
              expense.amount;
    }

    final int totalExpense =
    categoryTotals.values.fold<int>(
      0,
          (
          int sum,
          int amount,
          ) {
        return sum + amount;
      },
    );

    if (totalExpense <= 0) {
      return <CategorySummaryModel>[];
    }

    final Map<String, _CategoryInfo>
    categoryInfoMap =
    await _loadCategoryInfoMap();

    final List<CategorySummaryModel> result =
    categoryTotals.entries.map((entry) {
      final _CategoryInfo? categoryInfo =
      categoryInfoMap[entry.key];

      final String categoryKey =
          categoryInfo?.key ?? entry.key;

      final String categoryName =
          categoryInfo?.name ?? entry.key;

      final double percentage =
          entry.value / totalExpense * 100;

      return CategorySummaryModel(
        categoryKey: categoryKey,
        categoryName: categoryName,
        totalAmount: entry.value,
        percentage: percentage,
      );
    }).toList();

    /// 지출 금액이 큰 순서로 정렬
    result.sort(
          (
          CategorySummaryModel first,
          CategorySummaryModel second,
          ) {
        return second.totalAmount.compareTo(
          first.totalAmount,
        );
      },
    );

    debugPrint(
      '[카테고리 집계] '
          'userId=$userId, '
          'year=$year, '
          'month=$month, '
          'count=${result.length}, '
          'total=$totalExpense',
    );

    return result;
  }

  // =========================================================
  // 2. 주간 총지출
  // =========================================================

  /// weekStart부터 7일 동안 지출 합계를 반환한다.
  ///
  /// 사용 예:
  ///
  /// getWeeklyTotalExpense(
  ///   userId: uid,
  ///   weekStart: weekStart,
  /// );
  Future<int> getWeeklyTotalExpense({
    required String userId,
    required DateTime weekStart,
  }) async {
    if (userId.trim().isEmpty) {
      return 0;
    }

    final DateTime normalizedStart =
    DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final DateTime weekEnd =
    normalizedStart.add(
      const Duration(days: 7),
    );

    final List<_ExpenseData> expenses =
    await _loadUserExpenses(
      userId: userId,
    );

    int totalExpense = 0;

    for (final _ExpenseData expense
    in expenses) {
      final bool isInWeek =
          !expense.date.isBefore(
            normalizedStart,
          ) &&
              expense.date.isBefore(
                weekEnd,
              );

      if (!isInWeek) {
        continue;
      }

      totalExpense += expense.amount;
    }

    return totalExpense;
  }

  // =========================================================
  // 3. 월별 일자 지출 합계
  // =========================================================

  /// 선택한 월의 지출을 날짜 숫자별로 합산한다.
  ///
  /// 반환 예:
  ///
  /// {
  ///   1: 10000,
  ///   5: 32000,
  ///   15: 9000,
  /// }
  Future<Map<int, int>> getDailyTotals({
    required String userId,
    required int year,
    required int month,
  }) async {
    if (userId.trim().isEmpty) {
      return <int, int>{};
    }

    final DateTime startDate = DateTime(
      year,
      month,
      1,
    );

    final DateTime endDate = DateTime(
      year,
      month + 1,
      1,
    );

    final List<_ExpenseData> expenses =
    await _loadUserExpenses(
      userId: userId,
    );

    final Map<int, int> dailyTotals =
    <int, int>{};

    for (final _ExpenseData expense
    in expenses) {
      final bool isSelectedMonth =
          !expense.date.isBefore(startDate) &&
              expense.date.isBefore(endDate);

      if (!isSelectedMonth) {
        continue;
      }

      final int day = expense.date.day;

      dailyTotals[day] =
          (dailyTotals[day] ?? 0) +
              expense.amount;
    }

    return dailyTotals;
  }

  // =========================================================
  // 4. 최근 지출
  // =========================================================

  /// 최근 지출을 최신순으로 반환한다.
  ///
  /// RecentExpenseEntry는
  /// category_summary_model.dart에 정의된 것을 사용한다.
  Future<List<RecentExpenseEntry>>
  getRecentExpenses({
    required String userId,
    int limit = 5,
  }) async {
    if (userId.trim().isEmpty ||
        limit <= 0) {
      return <RecentExpenseEntry>[];
    }

    final List<_ExpenseData> expenses =
    await _loadUserExpenses(
      userId: userId,
    );

    final Map<String, _CategoryInfo>
    categoryInfoMap =
    await _loadCategoryInfoMap();

    /// 최신 날짜순 정렬
    expenses.sort(
          (
          _ExpenseData first,
          _ExpenseData second,
          ) {
        return second.date.compareTo(
          first.date,
        );
      },
    );

    return expenses.take(limit).map(
          (_ExpenseData expense) {
        final _CategoryInfo? categoryInfo =
        categoryInfoMap[
        expense.categoryId];

        return RecentExpenseEntry(
          categoryKey:
          categoryInfo?.key ??
              expense.categoryId,
          categoryName:
          categoryInfo?.name ??
              expense.categoryId,
          amount: expense.amount,
          date: expense.date,
        );
      },
    ).toList();
  }

  // =========================================================
  // 공통 내부 조회
  // =========================================================

  /// 현재 사용자의 삭제되지 않은 지출을 조회한다.
  Future<List<_ExpenseData>>
  _loadUserExpenses({
    required String userId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>>
    snapshot =
    await _expenseCollection
        .where(
      'userId',
      isEqualTo: userId,
    )
        .get();

    final List<_ExpenseData> result =
    <_ExpenseData>[];

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document in snapshot.docs) {
      final Map<String, dynamic> data =
      document.data();

      /// 소프트 삭제 문서는 제외
      if (data['isDeleted'] == true) {
        continue;
      }

      final DateTime? date =
      _toDateTime(
        data['date'],
      );

      if (date == null) {
        continue;
      }

      final int amount =
      _toInt(
        data['amount'],
      );

      if (amount <= 0) {
        continue;
      }

      final String categoryId =
          data['categoryId']
              ?.toString()
              .trim() ??
              '';

      if (categoryId.isEmpty) {
        continue;
      }

      result.add(
        _ExpenseData(
          categoryId: categoryId,
          amount: amount,
          date: date,
        ),
      );
    }

    return result;
  }

  /// categories 컬렉션에서
  /// 문서 ID별 이름과 카테고리 키를 조회한다.
  Future<Map<String, _CategoryInfo>>
  _loadCategoryInfoMap() async {
    final QuerySnapshot<Map<String, dynamic>>
    snapshot =
    await _categoryCollection.get();

    final Map<String, _CategoryInfo> result =
    <String, _CategoryInfo>{};

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document in snapshot.docs) {
      final Map<String, dynamic> data =
      document.data();

      final String categoryName =
          _readFirstNonEmptyString(
            data,
            const <String>[
              'name',
              'categoryName',
              'label',
            ],
          ) ??
              document.id;

      /// categoryKey가 있으면 사용하고,
      /// 없으면 code 또는 문서 ID 사용
      final String categoryKey =
          _readFirstNonEmptyString(
            data,
            const <String>[
              'categoryKey',
              'key',
              'code',
            ],
          ) ??
              document.id;

      result[document.id] =
          _CategoryInfo(
            key: categoryKey,
            name: categoryName,
          );
    }

    return result;
  }

  /// Map 안에서 첫 번째 빈 값이 아닌 문자열 찾기
  String? _readFirstNonEmptyString(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final String key in keys) {
      final String value =
          data[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  /// Firestore 숫자를 int로 변환
  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  /// Firestore 날짜 값을 DateTime으로 변환
  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}

/// 서비스 내부에서만 사용하는 지출 데이터
class _ExpenseData {
  final String categoryId;
  final int amount;
  final DateTime date;

  const _ExpenseData({
    required this.categoryId,
    required this.amount,
    required this.date,
  });
}

/// 서비스 내부에서만 사용하는 카테고리 정보
class _CategoryInfo {
  final String key;
  final String name;

  const _CategoryInfo({
    required this.key,
    required this.name,
  });
}