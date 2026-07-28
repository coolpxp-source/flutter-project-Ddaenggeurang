import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/category_summary_model.dart';

/// 카테고리 집계 화면에서 선택할 수 있는 조회 기간
enum CategorySummaryPeriod {
  /// 선택한 하루
  day,

  /// 선택한 날짜가 포함된 월요일부터 일요일까지
  week,

  /// 선택한 날짜가 포함된 한 달
  month,
}

/// 기간별 카테고리 집계 결과
///
/// 현재 기간과 바로 이전 기간의 총지출을 함께 가지고 있어
/// 화면에서 "지난 기간보다 몇 % 증가/감소" 문구를 만들 수 있다.
class CategorySummaryPeriodResult {
  /// 현재 기간의 카테고리별 집계 목록
  final List<CategorySummaryModel> summaries;

  /// 현재 기간의 전체 지출
  final int totalAmount;

  /// 이전 기간의 전체 지출
  final int previousTotalAmount;

  /// 현재 기간 시작일
  final DateTime startDate;

  /// 현재 기간 종료일
  ///
  /// 실제 조회 조건에서는 이 날짜를 포함하지 않는다.
  final DateTime endDate;

  const CategorySummaryPeriodResult({
    required this.summaries,
    required this.totalAmount,
    required this.previousTotalAmount,
    required this.startDate,
    required this.endDate,
  });

  /// 이전 기간 대비 지출 금액 차이
  ///
  /// 양수면 증가, 음수면 감소, 0이면 동일하다.
  int get differenceAmount => totalAmount - previousTotalAmount;

  /// 이전 기간과 비교할 수 있는지 여부
  ///
  /// 이전 기간 지출이 0원이면 증감률의 기준값이 없으므로
  /// 퍼센트 대신 "비교할 이전 지출이 없어요" 같은 문구를 보여주는 것이 좋다.
  bool get canCompare => previousTotalAmount > 0;

  /// 이전 기간 대비 증감률
  ///
  /// 이전 기간 지출이 0원이면 계산할 수 없으므로 null을 반환한다.
  double? get changeRate {
    if (!canCompare) {
      return null;
    }

    return differenceAmount / previousTotalAmount * 100;
  }
}

/// expenses 컬렉션을 기준으로
/// 월별/주별/일별/최근 지출 통계를 계산하는 서비스
class CategorySummaryService {
  final FirebaseFirestore _firestore;

  CategorySummaryService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  /// 현재 프로젝트에서 사용 중인 최상위 expenses 컬렉션
  CollectionReference<Map<String, dynamic>> get _expenseCollection {
    return _firestore.collection('expenses');
  }

  /// 카테고리 이름과 키를 저장하는 categories 컬렉션
  CollectionReference<Map<String, dynamic>> get _categoryCollection {
    return _firestore.collection('categories');
  }

  // =========================================================
  // 1. 일간/주간/월간 카테고리 집계 + 이전 기간 비교
  // =========================================================

  /// 선택한 기간의 카테고리별 지출과 이전 기간의 총지출을 반환한다.
  ///
  /// 화면의 일간/주간/월간 탭에서 공통으로 사용할 메서드다.
  ///
  /// 사용 예:
  ///
  /// final result = await service.getCategorySummaryByPeriod(
  ///   userId: uid,
  ///   selectedDate: DateTime.now(),
  ///   period: CategorySummaryPeriod.month,
  /// );
  Future<CategorySummaryPeriodResult> getCategorySummaryByPeriod({
    required String userId,
    required DateTime selectedDate,
    required CategorySummaryPeriod period,
  }) async {
    final _DateRange currentRange = _getDateRange(
      selectedDate: selectedDate,
      period: period,
    );

    final _DateRange previousRange = _getPreviousDateRange(
      currentRange: currentRange,
      period: period,
    );

    if (userId.trim().isEmpty) {
      return CategorySummaryPeriodResult(
        summaries: const <CategorySummaryModel>[],
        totalAmount: 0,
        previousTotalAmount: 0,
        startDate: currentRange.start,
        endDate: currentRange.end,
      );
    }

    /// 지출을 한 번만 조회한 뒤 현재 기간과 이전 기간을 각각 계산한다.
    final List<_ExpenseData> expenses = await _loadUserExpenses(
      userId: userId,
    );

    final Map<String, _CategoryInfo> categoryInfoMap =
    await _loadCategoryInfoMap();

    final List<_ExpenseData> currentExpenses = _filterExpensesByRange(
      expenses: expenses,
      range: currentRange,
    );

    final List<_ExpenseData> previousExpenses = _filterExpensesByRange(
      expenses: expenses,
      range: previousRange,
    );

    final List<CategorySummaryModel> summaries = _buildCategorySummaries(
      expenses: currentExpenses,
      categoryInfoMap: categoryInfoMap,
    );

    final int totalAmount = _calculateTotal(currentExpenses);
    final int previousTotalAmount = _calculateTotal(previousExpenses);

    debugPrint(
      '[기간별 카테고리 집계] '
          'userId=$userId, '
          'period=${period.name}, '
          'start=${currentRange.start}, '
          'end=${currentRange.end}, '
          'categoryCount=${summaries.length}, '
          'total=$totalAmount, '
          'previousTotal=$previousTotalAmount',
    );

    return CategorySummaryPeriodResult(
      summaries: summaries,
      totalAmount: totalAmount,
      previousTotalAmount: previousTotalAmount,
      startDate: currentRange.start,
      endDate: currentRange.end,
    );
  }

  // =========================================================
  // 2. 기존 월별 카테고리 집계
  // =========================================================

  /// 선택한 월의 지출을 categoryId별로 합산한다.
  ///
  /// 기존 화면이나 다른 파일에서 사용하던 호출이 깨지지 않도록
  /// 메서드 이름과 매개변수를 그대로 유지한다.
  Future<List<CategorySummaryModel>> getCategorySummary({
    required String userId,
    required int year,
    required int month,
  }) async {
    final CategorySummaryPeriodResult result =
    await getCategorySummaryByPeriod(
      userId: userId,
      selectedDate: DateTime(year, month, 1),
      period: CategorySummaryPeriod.month,
    );

    return result.summaries;
  }

  // =========================================================
  // 3. 기존 주간 총지출
  // =========================================================

  /// [weekStart]부터 7일 동안의 지출 합계를 반환한다.
  ///
  /// 기존 홈 화면 등에서 사용할 수 있도록 유지한 메서드다.
  Future<int> getWeeklyTotalExpense({
    required String userId,
    required DateTime weekStart,
  }) async {
    if (userId.trim().isEmpty) {
      return 0;
    }

    final DateTime normalizedStart = _normalizeDate(weekStart);
    final _DateRange range = _DateRange(
      start: normalizedStart,
      end: normalizedStart.add(const Duration(days: 7)),
    );

    final List<_ExpenseData> expenses = await _loadUserExpenses(
      userId: userId,
    );

    final List<_ExpenseData> weeklyExpenses = _filterExpensesByRange(
      expenses: expenses,
      range: range,
    );

    return _calculateTotal(weeklyExpenses);
  }

  // =========================================================
  // 4. 기존 월별 일자 지출 합계
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

    final _DateRange monthRange = _DateRange(
      start: DateTime(year, month, 1),
      end: DateTime(year, month + 1, 1),
    );

    final List<_ExpenseData> expenses = await _loadUserExpenses(
      userId: userId,
    );

    final List<_ExpenseData> monthlyExpenses = _filterExpensesByRange(
      expenses: expenses,
      range: monthRange,
    );

    final Map<int, int> dailyTotals = <int, int>{};

    for (final _ExpenseData expense in monthlyExpenses) {
      final int day = expense.date.day;
      dailyTotals[day] = (dailyTotals[day] ?? 0) + expense.amount;
    }

    return dailyTotals;
  }

  // =========================================================
  // 5. 최근 지출
  // =========================================================

  /// 최근 지출을 최신순으로 반환한다.
  ///
  /// [RecentExpenseEntry]는 category_summary_model.dart에 정의된 모델을
  /// 그대로 사용한다.
  Future<List<RecentExpenseEntry>> getRecentExpenses({
    required String userId,
    int limit = 5,
  }) async {
    if (userId.trim().isEmpty || limit <= 0) {
      return <RecentExpenseEntry>[];
    }

    final List<_ExpenseData> expenses = await _loadUserExpenses(
      userId: userId,
    );

    final Map<String, _CategoryInfo> categoryInfoMap =
    await _loadCategoryInfoMap();

    /// 원본 목록을 최신 날짜순으로 정렬한다.
    expenses.sort(
          (_ExpenseData first, _ExpenseData second) {
        return second.date.compareTo(first.date);
      },
    );

    return expenses.take(limit).map(
          (_ExpenseData expense) {
        final _CategoryInfo? categoryInfo =
        categoryInfoMap[expense.categoryId];

        return RecentExpenseEntry(
          categoryKey: categoryInfo?.key ?? expense.categoryId,
          categoryName: categoryInfo?.name ?? expense.categoryId,
          amount: expense.amount,
          date: expense.date,
        );
      },
    ).toList();
  }

  // =========================================================
  // 기간 계산
  // =========================================================

  /// 선택한 날짜와 조회 단위에 맞는 시작일/종료일을 만든다.
  ///
  /// 종료일은 조회 범위에 포함하지 않는다.
  /// 예: 7월 월간 조회는 7월 1일 이상, 8월 1일 미만이다.
  _DateRange _getDateRange({
    required DateTime selectedDate,
    required CategorySummaryPeriod period,
  }) {
    final DateTime normalizedDate = _normalizeDate(selectedDate);

    switch (period) {
      case CategorySummaryPeriod.day:
        return _DateRange(
          start: normalizedDate,
          end: normalizedDate.add(const Duration(days: 1)),
        );

      case CategorySummaryPeriod.week:
      /// DateTime.weekday는 월요일=1, 일요일=7이다.
        final DateTime weekStart = normalizedDate.subtract(
          Duration(days: normalizedDate.weekday - DateTime.monday),
        );

        return _DateRange(
          start: weekStart,
          end: weekStart.add(const Duration(days: 7)),
        );

      case CategorySummaryPeriod.month:
        return _DateRange(
          start: DateTime(normalizedDate.year, normalizedDate.month, 1),
          end: DateTime(normalizedDate.year, normalizedDate.month + 1, 1),
        );
    }
  }

  /// 현재 기간의 바로 이전 기간을 계산한다.
  _DateRange _getPreviousDateRange({
    required _DateRange currentRange,
    required CategorySummaryPeriod period,
  }) {
    switch (period) {
      case CategorySummaryPeriod.day:
        final DateTime previousStart = currentRange.start.subtract(
          const Duration(days: 1),
        );

        return _DateRange(
          start: previousStart,
          end: currentRange.start,
        );

      case CategorySummaryPeriod.week:
        final DateTime previousStart = currentRange.start.subtract(
          const Duration(days: 7),
        );

        return _DateRange(
          start: previousStart,
          end: currentRange.start,
        );

      case CategorySummaryPeriod.month:
        final DateTime previousStart = DateTime(
          currentRange.start.year,
          currentRange.start.month - 1,
          1,
        );

        return _DateRange(
          start: previousStart,
          end: currentRange.start,
        );
    }
  }

  /// 시간 정보를 제거하고 연/월/일만 남긴다.
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // =========================================================
  // 집계 계산
  // =========================================================

  /// 전체 지출 중에서 지정한 날짜 범위에 포함되는 지출만 반환한다.
  List<_ExpenseData> _filterExpensesByRange({
    required List<_ExpenseData> expenses,
    required _DateRange range,
  }) {
    return expenses.where(
          (_ExpenseData expense) {
        return !expense.date.isBefore(range.start) &&
            expense.date.isBefore(range.end);
      },
    ).toList();
  }

  /// 카테고리별 총액과 전체 지출 대비 비율을 계산한다.
  List<CategorySummaryModel> _buildCategorySummaries({
    required List<_ExpenseData> expenses,
    required Map<String, _CategoryInfo> categoryInfoMap,
  }) {
    final Map<String, int> categoryTotals = <String, int>{};

    for (final _ExpenseData expense in expenses) {
      categoryTotals[expense.categoryId] =
          (categoryTotals[expense.categoryId] ?? 0) + expense.amount;
    }

    final int totalAmount = categoryTotals.values.fold<int>(
      0,
          (int sum, int amount) => sum + amount,
    );

    if (totalAmount <= 0) {
      return <CategorySummaryModel>[];
    }

    final List<CategorySummaryModel> summaries =
    categoryTotals.entries.map((MapEntry<String, int> entry) {
      final _CategoryInfo? categoryInfo = categoryInfoMap[entry.key];

      return CategorySummaryModel(
        categoryKey: categoryInfo?.key ?? entry.key,
        categoryName: categoryInfo?.name ?? entry.key,
        totalAmount: entry.value,
        percentage: entry.value / totalAmount * 100,
      );
    }).toList();

    /// 지출 금액이 큰 카테고리부터 표시한다.
    summaries.sort(
          (CategorySummaryModel first, CategorySummaryModel second) {
        return second.totalAmount.compareTo(first.totalAmount);
      },
    );

    return summaries;
  }

  /// 지출 목록의 총합을 반환한다.
  int _calculateTotal(List<_ExpenseData> expenses) {
    return expenses.fold<int>(
      0,
          (int sum, _ExpenseData expense) => sum + expense.amount,
    );
  }

  // =========================================================
  // Firestore 공통 조회
  // =========================================================

  /// 현재 사용자의 삭제되지 않은 지출을 조회한다.
  ///
  /// 현재 프로젝트 구조에 맞춰 최상위 expenses 컬렉션에서
  /// userId가 일치하는 문서만 가져온다.
  Future<List<_ExpenseData>> _loadUserExpenses({
    required String userId,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _expenseCollection.where('userId', isEqualTo: userId).get();

    final List<_ExpenseData> result = <_ExpenseData>[];

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      /// 소프트 삭제된 문서는 통계에서 제외한다.
      if (data['isDeleted'] == true) {
        continue;
      }

      final DateTime? date = _toDateTime(data['date']);
      if (date == null) {
        continue;
      }

      final int amount = _toInt(data['amount']);
      if (amount <= 0) {
        continue;
      }

      final String categoryId = data['categoryId']?.toString().trim() ?? '';
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

  /// categories 컬렉션에서 문서 ID별 표시 이름과 카테고리 키를 조회한다.
  Future<Map<String, _CategoryInfo>> _loadCategoryInfoMap() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _categoryCollection.get();

    final Map<String, _CategoryInfo> result = <String, _CategoryInfo>{};

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in snapshot.docs) {
      final Map<String, dynamic> data = document.data();

      final String categoryName = _readFirstNonEmptyString(
        data,
        const <String>[
          'name',
          'categoryName',
          'label',
        ],
      ) ??
          document.id;

      /// categoryKey가 있으면 사용하고, 없으면 code 또는 문서 ID를 사용한다.
      final String categoryKey = _readFirstNonEmptyString(
        data,
        const <String>[
          'categoryKey',
          'key',
          'code',
        ],
      ) ??
          document.id;

      result[document.id] = _CategoryInfo(
        key: categoryKey,
        name: categoryName,
      );
    }

    return result;
  }

  /// Map 안에서 첫 번째 빈 값이 아닌 문자열을 찾는다.
  String? _readFirstNonEmptyString(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final String key in keys) {
      final String value = data[key]?.toString().trim() ?? '';

      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  /// Firestore 숫자 또는 문자열 숫자를 int로 변환한다.
  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Firestore Timestamp, DateTime, ISO 문자열을 DateTime으로 변환한다.
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

/// 서비스 내부에서만 사용하는 날짜 범위
class _DateRange {
  final DateTime start;
  final DateTime end;

  const _DateRange({
    required this.start,
    required this.end,
  });
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
