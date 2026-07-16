import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/expense_model.dart';
import '../models/mothly_briefing_model.dart';


/// 월간 브리핑에 필요한 데이터를 Firestore에서 조회하고
/// 화면에서 사용할 수 있도록 집계하는 서비스
class MonthlyBriefingService {
  /// Firestore 인스턴스
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  /// 선택한 월의 월간 브리핑 데이터를 조회한다.
  ///
  /// [userId]
  /// 현재 로그인한 사용자의 Firebase UID
  ///
  /// [selectedMonth]
  /// 사용자가 선택한 조회 월
  Future<MonthlyBriefingModel> getMonthlyBriefing({
    required String userId,
    required DateTime selectedMonth,
  }) async {
    /// 선택한 달의 첫 번째 날짜
    ///
    /// 예:
    /// selectedMonth가 2026년 7월이면
    /// 2026-07-01 00:00:00
    final DateTime startDate = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    /// 다음 달의 첫 번째 날짜
    ///
    /// 예:
    /// selectedMonth가 2026년 7월이면
    /// 2026-08-01 00:00:00
    ///
    /// 조회 조건에서 date < endDate로 사용한다.
    final DateTime endDate = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      1,
    );

    /// Firestore 월 문서 조회에 사용할 월 키
    ///
    /// 예:
    /// 2026-07
    final String monthKey =
        '${selectedMonth.year}-'
        '${selectedMonth.month.toString().padLeft(2, '0')}';

    /// 선택한 월의 지출 목록 조회
    final List<ExpenseModel> expenses =
    await _getMonthlyExpenses(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );

    /// categories 컬렉션에서
    /// 카테고리 문서 ID와 카테고리 이름 조회
    final Map<String, String> categoryNames =
    await _loadCategoryNames();

    /// 선택한 월의 전체 예산 조회
    final int totalBudget =
    await _loadMonthlyBudget(
      userId: userId,
      monthKey: monthKey,
    );

    /// 전체 지출 금액
    int totalSpent = 0;

    /// 고정비 총금액
    int fixedExpense = 0;

    /// 변동비 총금액
    int variableExpense = 0;

    /// 기타 지출 총금액
    int otherExpense = 0;

    /// 카테고리별 금액을 저장할 Map
    final Map<String, int> categoryAmounts = {};

    /// 감정 태그별 금액을 저장할 Map
    final Map<String, int> emotionAmounts = {};

    /// 선택한 월의 지출 목록을 순회하면서
    /// 필요한 금액을 집계한다.
    for (final ExpenseModel expense in expenses) {
      /// 총지출에 현재 지출 금액 추가
      totalSpent += expense.amount;

      /// 지출 성격에 따라 금액 분류
      switch (expense.nature) {
        case ExpenseNature.fixed:
          fixedExpense += expense.amount;
          break;

        case ExpenseNature.variable:
          variableExpense += expense.amount;
          break;

        case ExpenseNature.other:
          otherExpense += expense.amount;
          break;
      }

      /// expense에는 categoryId가 저장되어 있으므로
      /// categories 컬렉션에서 불러온 이름으로 변환한다.
      ///
      /// 카테고리를 찾지 못하면 미분류로 처리한다.
      final String categoryName =
          categoryNames[expense.categoryId] ??
              '미분류';

      /// 해당 카테고리가 이미 Map에 있으면 기존 금액에 더하고,
      /// 없으면 현재 지출 금액으로 새로 추가한다.
      categoryAmounts.update(
        categoryName,
            (int currentAmount) {
          return currentAmount + expense.amount;
        },
        ifAbsent: () {
          return expense.amount;
        },
      );

      /// 감정 태그는 변동비에만 저장될 수 있으며
      /// null일 수 있다.
      final String? emotionTag =
          expense.emotionTag;

      /// 감정 태그가 존재하는 경우에만 집계한다.
      if (emotionTag != null &&
          emotionTag.trim().isNotEmpty) {
        emotionAmounts.update(
          emotionTag,
              (int currentAmount) {
            return currentAmount + expense.amount;
          },
          ifAbsent: () {
            return expense.amount;
          },
        );
      }
    }

    /// 가장 지출 금액이 높은 카테고리 찾기
    final MapEntry<String, int>? topCategory =
    _findHighestEntry(
      categoryAmounts,
    );

    /// 가장 지출 금액이 높은 감정 태그 찾기
    final MapEntry<String, int>? topEmotion =
    _findHighestEntry(
      emotionAmounts,
    );

    /// 남은 예산 계산
    ///
    /// 예산보다 많이 지출했다면 음수가 된다.
    final int remainingBudget =
        totalBudget - totalSpent;

    /// 예산 사용률 계산
    ///
    /// 예산이 설정되어 있지 않으면
    /// 0으로 나누는 오류를 방지하기 위해 0을 반환한다.
    final double budgetUsageRate =
    totalBudget <= 0
        ? 0
        : totalSpent / totalBudget * 100;

    /// 하루 평균 지출 계산에 사용할 일수
    final int calculationDays =
    _getCalculationDays(
      selectedMonth,
    );

    /// 하루 평균 지출 금액 계산
    final double dailyAverage =
    calculationDays <= 0
        ? 0
        : totalSpent / calculationDays;

    /// 모든 집계 데이터를 모델로 반환
    return MonthlyBriefingModel(
      monthKey: monthKey,
      totalBudget: totalBudget,
      totalSpent: totalSpent,
      remainingBudget: remainingBudget,
      fixedExpense: fixedExpense,
      variableExpense: variableExpense,
      otherExpense: otherExpense,
      budgetUsageRate: budgetUsageRate,
      dailyAverage: dailyAverage,
      topCategoryName: topCategory?.key,
      topCategoryAmount: topCategory?.value ?? 0,
      topEmotionName: topEmotion?.key,
      topEmotionAmount: topEmotion?.value ?? 0,
      expenseCount: expenses.length,
      categoryAmounts: categoryAmounts,
      emotionAmounts: emotionAmounts,
    );
  }

  /// 선택한 월의 지출 데이터를 조회한다.
  Future<List<ExpenseModel>> _getMonthlyExpenses({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final QuerySnapshot<Map<String, dynamic>>
    snapshot = await _firestore
        .collection('expenses')

    /// 현재 로그인 사용자 데이터만 조회
        .where(
      'userId',
      isEqualTo: userId,
    )

    /// 소프트 삭제되지 않은 데이터만 조회
        .where(
      'isDeleted',
      isEqualTo: false,
    )

    /// 선택한 달의 첫날 이상
        .where(
      'date',
      isGreaterThanOrEqualTo:
      Timestamp.fromDate(startDate),
    )

    /// 다음 달 첫날 미만
    ///
    /// 예:
    /// 7월 데이터를 조회할 때
    /// date < 8월 1일
        .where(
      'date',
      isLessThan:
      Timestamp.fromDate(endDate),
    )

    /// 최신 지출부터 정렬
        .orderBy(
      'date',
      descending: true,
    )
        .get();

    /// Firestore 문서를 ExpenseModel 목록으로 변환
    return snapshot.docs.map(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) {
        return ExpenseModel.fromFirestore(
          document,
        );
      },
    ).toList();
  }

  /// categories 컬렉션에서 카테고리 이름을 조회한다.
  ///
  /// 반환 예:
  /// {
  ///   'category_document_id_1': '식비',
  ///   'category_document_id_2': '교통비',
  /// }
  Future<Map<String, String>>
  _loadCategoryNames() async {
    final QuerySnapshot<Map<String, dynamic>>
    snapshot = await _firestore
        .collection('categories')
        .get();

    final Map<String, String> categoryNames =
    {};

    for (final QueryDocumentSnapshot<
        Map<String, dynamic>>
    document in snapshot.docs) {
      categoryNames[document.id] =
          document.data()['name']?.toString() ??
              '이름 없음';
    }

    return categoryNames;
  }

  /// 선택한 월의 예산을 budgets 컬렉션에서 조회한다.
  Future<int> _loadMonthlyBudget({
    required String userId,
    required String monthKey,
  }) async {
    /// 현재 BudgetService에서 사용하는 문서 ID 형식
    ///
    /// 예:
    /// 사용자UID_2026-07
    final String documentId =
        '${userId}_$monthKey';

    /// 먼저 문서 ID로 예산 문서를 조회한다.
    final DocumentSnapshot<Map<String, dynamic>>
    document = await _firestore
        .collection('budgets')
        .doc(documentId)
        .get();

    /// 문서 ID 방식으로 예산을 찾은 경우
    if (document.exists) {
      return _extractTotalBudget(
        document.data(),
      );
    }

    /// 문서 ID 형식이 다른 경우를 대비해서
    /// userId와 monthKey 필드로 한 번 더 조회한다.
    final QuerySnapshot<Map<String, dynamic>>
    querySnapshot = await _firestore
        .collection('budgets')
        .where(
      'userId',
      isEqualTo: userId,
    )
        .where(
      'monthKey',
      isEqualTo: monthKey,
    )
        .limit(1)
        .get();

    /// 예산 문서가 없는 경우
    if (querySnapshot.docs.isEmpty) {
      return 0;
    }

    /// 조회한 예산 문서에서 전체 예산 값을 추출
    return _extractTotalBudget(
      querySnapshot.docs.first.data(),
    );
  }

  /// budgets 문서에서 전체 예산 값을 추출한다.
  ///
  /// 프로젝트 내 필드명이 다를 가능성을 고려하여
  /// totalBudget, budgetAmount, amount 순서로 확인한다.
  int _extractTotalBudget(
      Map<String, dynamic>? data,
      ) {
    /// 문서 데이터가 없는 경우
    if (data == null) {
      return 0;
    }

    /// 사용할 수 있는 예산 필드 확인
    final dynamic budgetValue =
        data['totalBudget'] ??
            data['budgetAmount'] ??
            data['amount'];

    /// Firestore에서 int로 조회된 경우
    if (budgetValue is int) {
      return budgetValue;
    }

    /// Firestore에서 double로 조회된 경우
    if (budgetValue is double) {
      return budgetValue.toInt();
    }

    /// 문자열로 저장된 경우 int로 변환
    return int.tryParse(
      budgetValue?.toString() ?? '',
    ) ??
        0;
  }

  /// Map에서 금액이 가장 높은 항목을 찾는다.
  ///
  /// 예:
  /// {
  ///   '식비': 300000,
  ///   '쇼핑': 500000,
  /// }
  ///
  /// 반환:
  /// MapEntry('쇼핑', 500000)
  MapEntry<String, int>? _findHighestEntry(
      Map<String, int> values,
      ) {
    /// 데이터가 없으면 null 반환
    if (values.isEmpty) {
      return null;
    }

    MapEntry<String, int>? highestEntry;

    /// 모든 항목을 비교하면서
    /// 가장 높은 금액을 가진 항목을 저장한다.
    for (final MapEntry<String, int> entry
    in values.entries) {
      if (highestEntry == null ||
          entry.value > highestEntry.value) {
        highestEntry = entry;
      }
    }

    return highestEntry;
  }

  /// 하루 평균 지출 계산에 사용할 일수를 구한다.
  int _getCalculationDays(
      DateTime selectedMonth,
      ) {
    final DateTime now = DateTime.now();

    /// 선택한 월이 현재 월인지 확인
    final bool isCurrentMonth =
        selectedMonth.year == now.year &&
            selectedMonth.month == now.month;

    /// 현재 월이라면 오늘 날짜까지의 일수를 사용한다.
    ///
    /// 예:
    /// 오늘이 7월 16일이면 16일로 계산
    if (isCurrentMonth) {
      return now.day;
    }

    /// 과거 월이라면 해당 월의 마지막 날짜를 사용한다.
    ///
    /// month + 1의 0일을 만들면
    /// 이전 달의 마지막 날짜가 된다.
    final DateTime lastDay = DateTime(
      selectedMonth.year,
      selectedMonth.month + 1,
      0,
    );

    return lastDay.day;
  }
}