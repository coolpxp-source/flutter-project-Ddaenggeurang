// lib/services/transaction_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_item.dart';
import '../models/income_model.dart';
import '../models/expense_model.dart';
import '../models/saving_model.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 특정 기간의 모든 지출, 수입, 저축을 긁어와 하나의 타임라인으로 병합 및 최신순 정렬
  Future<List<TransactionItem>> getMonthlyTransactions({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    List<TransactionItem> allTransactions = [];

    // 1. 카테고리 마스터 테이블 캐싱 (지출 categoryId를 한글명으로 변환하기 위함)
    final Map<String, String> categoryNames = {};
    try {
      // 기본 카테고리 긁어오기
      final basicCats = await _db.collection('categories').get();
      for (var doc in basicCats.docs) {
        categoryNames[doc.id] = doc.data()['name'] ?? '기타';
      }
      // 커스텀 카테고리 긁어오기
      final customCats = await _db
          .collection('customCategories')
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in customCats.docs) {
        categoryNames[doc.id] = doc.data()['name'] ?? '기타';
      }
    } catch (e) {
      print('⚠️ 카테고리 로드 실패 (기본값 ID로 대체): $e');
    }

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
      final expense = ExpenseModel.fromFirestore(doc);
      allTransactions.add(TransactionItem(
        id: expense.expenseId,
        type: 'expense',
        date: expense.date,
        amount: expense.amount,
        title: categoryNames[expense.categoryId] ?? expense.categoryId, // 카테고리 ID를 한글 이름으로 치환!
        subtitle: expense.memo,
        emotionTag: expense.emotionTag, // 감정 태그 코드 저장 ('stress', 'impulsive' 등)
      ));
    }

    // 4. 수입(Income) 파싱 및 매핑
    for (var doc in results[1].docs) {
      final income = IncomeModel.fromFirestore(doc);
      allTransactions.add(TransactionItem(
        id: income.incomeId,
        type: 'income',
        date: income.date,
        amount: income.amount,
        title: income.incomeSource.label,
        subtitle: income.memo,
      ));
    }

    // 5. 저축(Saving) 파싱 및 매핑
    for (var doc in results[2].docs) {
      final saving = SavingModel.fromFirestore(doc);
      allTransactions.add(TransactionItem(
        id: saving.savingId,
        type: 'saving',
        date: saving.date,
        amount: saving.amount,
        title: saving.categoryId, // '적금', '투자' 등 카테고리명
        subtitle: saving.memo,
        accountName: saving.accountName, // 구체적인 계좌명 적용
        savingStatus: saving.status.code
      ));
    }

    // 6. 날짜 기준 최신순 정렬
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
        'isDeleted': true, // 👈 완전히 지우지 않고 상태만 변경 (기존 로직과 호환)
      });
      print('✅ 삭제 완료: $collectionName 의 $id');
    } catch (e) {
      print('⚠️ 삭제 에러: $e');
    }
  }
}

