import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget_vs_expense_model.dart';

/// 예산 대비 지출 조회 서비스
///
/// Firestore 구조:
///
/// budgets/{userId}_{monthKey}
/// monthlySummary/{userId}_{monthKey}
class BudgetVsExpenseService {
  final FirebaseFirestore _firestore;

  BudgetVsExpenseService({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  /// 월별 예산 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _budgetCollection {
    return _firestore.collection('budgets');
  }

  /// 월별 지출 집계 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _monthlySummaryCollection {
    return _firestore.collection('monthlySummary');
  }

  /// 월별 문서 ID 생성
  ///
  /// 예:
  /// 실제UID_2026-07
  String createMonthlyDocumentId({
    required String userId,
    required String monthKey,
  }) {
    return '${userId}_$monthKey';
  }

  /// 예산과 실제 지출을 동시에 실시간 조회
  Stream<BudgetVsExpenseModel> watchBudgetVsExpense({
    required String userId,
    required String monthKey,
  }) {
    final documentId = createMonthlyDocumentId(
      userId: userId,
      monthKey: monthKey,
    );

    final controller =
    StreamController<BudgetVsExpenseModel>();

    int totalBudget = 0;
    int totalSpent = 0;

    bool budgetLoaded = false;
    bool summaryLoaded = false;

    /// 두 문서의 조회가 끝나면 화면에 전달
    void emitData() {
      if (controller.isClosed) {
        return;
      }

      if (!budgetLoaded || !summaryLoaded) {
        return;
      }

      controller.add(
        BudgetVsExpenseModel(
          totalBudget: totalBudget,
          totalSpent: totalSpent,
        ),
      );
    }

    /// budgets/{실제UID}_{monthKey} 조회
    final budgetSubscription = _budgetCollection
        .doc(documentId)
        .snapshots()
        .listen(
          (snapshot) {
        final data = snapshot.data();

        totalBudget = _toInt(
          data?['totalBudget'],
        );

        budgetLoaded = true;
        emitData();
      },
      onError: (
          Object error,
          StackTrace stackTrace,
          ) {
        if (!controller.isClosed) {
          controller.addError(
            error,
            stackTrace,
          );
        }
      },
    );

    /// monthlySummary/{실제UID}_{monthKey} 조회
    final summarySubscription =
    _monthlySummaryCollection
        .doc(documentId)
        .snapshots()
        .listen(
          (snapshot) {
        final data = snapshot.data();

        totalSpent = _toInt(
          data?['totalSpent'],
        );

        summaryLoaded = true;
        emitData();
      },
      onError: (
          Object error,
          StackTrace stackTrace,
          ) {
        if (!controller.isClosed) {
          controller.addError(
            error,
            stackTrace,
          );
        }
      },
    );

    /// 화면이 닫히면 Firestore 구독 해제
    controller.onCancel = () async {
      await budgetSubscription.cancel();
      await summarySubscription.cancel();

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  /// Firestore 값을 int로 안전하게 변환
  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }
}