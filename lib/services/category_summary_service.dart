import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_summary_model.dart';
import '../services/expense_service.dart';

/// 특정 월의 카테고리별 지출 집계.
///
/// ⚠️ 기존 초안과 다른 점:
/// - `users/{uid}/expenses` 서브컬렉션이 아니라, 실제 구조인 최상위 `expenses` 컬렉션
///   (+ userId 필드)을 그대로 쓰는 ExpenseService를 재사용함.
/// - categoryId가 'food'/'transport' 같은 하드코딩 키가 아니라 실제 Firestore 문서ID이므로,
///   categories 컬렉션에서 이름을 직접 조회해서 매칭함.
class CategorySummaryService {
  final _expenseService = ExpenseService();
  final _db = FirebaseFirestore.instance;

  /// 특정 월의 카테고리별 지출 집계
  Future<List<CategorySummaryModel>> getCategorySummary({
    required String userId,
    required int year,
    required int month,
  }) async {
    final monthStart = DateTime(year, month, 1);
    final nextMonthStart = DateTime(year, month + 1, 1);
    // 해당 월의 마지막 순간 (다음 달 시작 1ms 전)
    final monthEnd = nextMonthStart.subtract(const Duration(milliseconds: 1));

    // 1. 실제 지출 데이터 조회 (기존 expense_service 재사용)
    final expenses = await _expenseService.getExpensesByDateRangeOnce(
      userId: userId,
      start: monthStart,
      end: monthEnd,
    );

    if (expenses.isEmpty) return [];

    // 2. 지출에 등장하는 categoryId들의 실제 이름을 categories 컬렉션에서 조회
    final categoryIds = expenses.map((e) => e.categoryId).toSet();
    final categoryNames = await _fetchCategoryNames(categoryIds);

    // 3. categoryId 기준으로 합산
    final Map<String, int> totals = {};
    for (final expense in expenses) {
      totals[expense.categoryId] = (totals[expense.categoryId] ?? 0) + expense.amount;
    }

    final totalExpense = totals.values.fold<int>(0, (sum, v) => sum + v);
    if (totalExpense == 0) return [];

    final summaries = totals.entries.map((entry) {
      final percentage = entry.value / totalExpense * 100;
      return CategorySummaryModel(
        categoryKey: entry.key, // 실제 categoryId (Firestore 문서ID)
        categoryName: categoryNames[entry.key] ?? '알 수 없음',
        totalAmount: entry.value,
        percentage: percentage,
      );
    }).toList();

    summaries.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return summaries;
  }

  /// 특정 월의 전체 지출 합계
  Future<int> getMonthlyTotalExpense({
    required String userId,
    required int year,
    required int month,
  }) async {
    final summaries = await getCategorySummary(userId: userId, year: year, month: month);
    return summaries.fold<int>(0, (sum, item) => sum + item.totalAmount);
  }

  /// categoryId 목록을 받아서 {categoryId: name} 맵으로 반환.
  /// Firestore의 whereIn은 최대 30개 제한이 있어 넘으면 나눠서 조회.
  Future<Map<String, String>> _fetchCategoryNames(Set<String> categoryIds) async {
    if (categoryIds.isEmpty) return {};

    final ids = categoryIds.toList();
    final result = <String, String>{};

    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snap = await _db
          .collection('categories')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        result[doc.id] = doc.data()['name'] as String? ?? '알 수 없음';
      }
    }

    return result;
  }
}