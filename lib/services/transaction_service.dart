// lib/services/transaction_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_item.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/saving_model.dart';

/// 카테고리 마스터 캐시 항목 — 한글명 + 대분류명을 함께 들고 다님
class _CategoryMeta {
  final String name;
  final String parentName;
  const _CategoryMeta(this.name, this.parentName);
}

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 카테고리 마스터 테이블 캐싱 (categoryId → 한글명 + 대분류명 변환용)
  /// getMonthlyTransactions / getAllTransactions에서 공통으로 사용
  Future<Map<String, _CategoryMeta>> _loadCategoryMeta(String userId) async {
    final Map<String, _CategoryMeta> categoryMeta = {};
    try {
      // 기본 카테고리 긁어오기
      final basicCats = await _db.collection('categories').get();
      for (var doc in basicCats.docs) {
        final data = doc.data();
        categoryMeta[doc.id] = _CategoryMeta(
          data['name'] ?? '기타',
          data['parentName'] ?? '',
        );
      }
      // 커스텀 카테고리 긁어오기
      final customCats = await _db
          .collection('customCategories')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in customCats.docs) {
        final data = doc.data();
        categoryMeta[doc.id] = _CategoryMeta(
          data['name'] ?? '기타',
          data['parentName'] ?? '',
        );
      }
    } catch (e) {
      print('⚠️ 카테고리 로드 실패 (기본값 ID로 대체): $e');
    }
    return categoryMeta;
  }

  String _categoryName(Map<String, _CategoryMeta> meta, String categoryId) {
    return meta[categoryId]?.name ?? categoryId;
  }

  String? _categoryParent(Map<String, _CategoryMeta> meta, String categoryId) {
    final parent = meta[categoryId]?.parentName;
    return (parent == null || parent.isEmpty) ? null : parent;
  }

  TransactionInvestmentDetail? _mapInvestmentDetail(InvestmentDetail? detail) {
    if (detail == null) return null;
    return TransactionInvestmentDetail(
      brokerage: detail.brokerage,
      assetName: detail.assetName,
      quantity: detail.quantity,
    );
  }

  TransactionItem _mapExpense(ExpenseModel expense, Map<String, _CategoryMeta> categoryMeta) {
    return TransactionItem(
      id: expense.expenseId,
      type: 'expense',
      date: expense.date,
      amount: expense.amount,
      title: _categoryName(categoryMeta, expense.categoryId), // 카테고리 ID를 한글 이름으로 치환!
      subtitle: expense.memo,
      emotionTag: expense.emotionTag, // 감정 태그 코드 저장 ('stress', 'impulsive' 등)
      parentCategory: _categoryParent(categoryMeta, expense.categoryId),
      nature: expense.nature.code, // 고정비/변동비/기타
      isInstallment: expense.installmentPlanId != null,
      installmentTotalMonths: expense.installmentTotalMonths,
      isRecurring: expense.recurringPaymentId != null,
      recurringPaymentId: expense.recurringPaymentId,
      categoryId: expense.categoryId,
    );
  }

  TransactionItem _mapIncome(IncomeModel income, Map<String, _CategoryMeta> categoryMeta) {
    return TransactionItem(
      id: income.incomeId,
      type: 'income',
      date: income.date,
      amount: income.amount,
      title: _categoryName(categoryMeta, income.categoryId),
      subtitle: income.memo,
      parentCategory: _categoryParent(categoryMeta, income.categoryId),
      isRecurring: income.recurringIncomeTemplateId != null,
      recurringPayDay: income.recurringPayDay,
      categoryId: income.categoryId,
    );
  }

  TransactionItem _mapSaving(SavingModel saving, Map<String, _CategoryMeta> categoryMeta) {
    return TransactionItem(
      id: saving.savingId,
      type: 'saving',
      date: saving.date,
      amount: saving.amount,
      title: _categoryName(categoryMeta, saving.categoryId),
      subtitle: saving.memo,
      accountName: saving.accountName, // 구체적인 계좌명 적용
      savingStatus: saving.status.code,
      parentCategory: _categoryParent(categoryMeta, saving.categoryId),
      isRecurring: saving.isRecurring,
      investmentDetail: _mapInvestmentDetail(saving.investmentDetail),
      returnedAmount: saving.returnedAmount,
      categoryId: saving.categoryId,
    );
  }

  /// 특정 기간의 모든 지출, 수입, 저축을 긁어와 하나의 타임라인으로 병합 및 최신순 정렬
  Future<List<TransactionItem>> getMonthlyTransactions({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    List<TransactionItem> allTransactions = [];

    // 1. 카테고리 마스터 테이블 캐싱 (지출 categoryId를 한글명+대분류명으로 변환하기 위함)
    final categoryMeta = await _loadCategoryMeta(userId);

    // 2. 파이어스토어에서 3대 데이터 동시에 비동기 병렬 호출 (속도 극대화)
    final results = await Future.wait([
      _db.collection('expenses')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get(),
      _db.collection('incomes')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get(),
      _db.collection('savings')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get(),
    ]);

    // 3. 지출(Expense) 파싱 및 매핑
    for (var doc in results[0].docs) {
      allTransactions.add(_mapExpense(ExpenseModel.fromFirestore(doc), categoryMeta));
    }

    // 4. 수입(Income) 파싱 및 매핑
    for (var doc in results[1].docs) {
      allTransactions.add(_mapIncome(IncomeModel.fromFirestore(doc), categoryMeta));
    }

    // 5. 저축(Saving) 파싱 및 매핑
    for (var doc in results[2].docs) {
      allTransactions.add(_mapSaving(SavingModel.fromFirestore(doc), categoryMeta));
    }

    // 6. 날짜 기준 최신순 정렬
    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    return allTransactions;
  }

  /// 기간 제한 없이 유저의 지출/수입/저축 전체를 긁어옴 — 통합검색용
  /// (Firestore가 부분일치 검색을 지원하지 않아, 데이터를 통째로 받아 화면단에서 title/memo/accountName을 필터링하는 방식)
  Future<List<TransactionItem>> getAllTransactions({
    required String userId,
  }) async {
    List<TransactionItem> allTransactions = [];

    final categoryMeta = await _loadCategoryMeta(userId);

    final results = await Future.wait([
      _db.collection('expenses')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .get(),
      _db.collection('incomes')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .get(),
      _db.collection('savings')
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .get(),
    ]);

    for (var doc in results[0].docs) {
      allTransactions.add(_mapExpense(ExpenseModel.fromFirestore(doc), categoryMeta));
    }

    for (var doc in results[1].docs) {
      allTransactions.add(_mapIncome(IncomeModel.fromFirestore(doc), categoryMeta));
    }

    for (var doc in results[2].docs) {
      allTransactions.add(_mapSaving(SavingModel.fromFirestore(doc), categoryMeta));
    }

    allTransactions.sort((a, b) => b.date.compareTo(a.date));

    return allTransactions;
  }

  /// 내역 삭제 (Soft Delete: isDeleted 상태를 true로 변경)
  Future<void> deleteTransaction(String type, String id) async {
    String collectionName;

    // type에 따라 어떤 파이어베이스 컬렉션을 찌를지 결정합니다.
    if (type == 'expense') {
      collectionName = 'expenses';
    } else if (type == 'income') {
      collectionName = 'incomes';
    } else if (type == 'saving') {
      collectionName = 'savings';
    } else {
      return;
    }

    try {
      await _db.collection(collectionName).doc(id).update({
        'isDeleted': true,
      });
      print('✅ 삭제 완료: $collectionName 의 $id');
    } catch (e) {
      print('⚠️ 삭제 에러: $e');
    }
  }
}