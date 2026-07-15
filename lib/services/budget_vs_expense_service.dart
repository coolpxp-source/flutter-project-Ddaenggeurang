import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget_vs_expense_model.dart';

class BudgetVsExpenseService {
  final FirebaseFirestore _firestore;

  BudgetVsExpenseService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _budgetCollection {
    return _firestore.collection('budgets');
  }

  CollectionReference<Map<String, dynamic>> get _monthlySummaryCollection {
    return _firestore.collection('monthlySummary');
  }

  /// 문서 ID 예시
  /// uid_2026-07
  String createMonthlyDocumentId({
    required String userId,
    required String monthKey,
  }) {
    return '${userId}_$monthKey';
  }

  /// budgets와 monthlySummary를 동시에 실시간 조회
  Stream<BudgetVsExpenseModel> watchBudgetVsExpense({
    required String userId,
    required String monthKey,
  }) {
    final documentId = createMonthlyDocumentId(
      userId: userId,
      monthKey: monthKey,
    );

    final controller = StreamController<BudgetVsExpenseModel>();

    int totalBudget = 0;
    int totalSpent = 0;

    void emitData() {
      if (!controller.isClosed) {
        controller.add(
          BudgetVsExpenseModel(
            totalBudget: totalBudget,
            totalSpent: totalSpent,
          ),
        );
      }
    }

    final budgetSubscription = _budgetCollection
        .doc(documentId)
        .snapshots()
        .listen(
          (snapshot) {
        final data = snapshot.data();

        totalBudget = _toInt(
          data?['totalBudget'],
        );

        emitData();
      },
      onError: controller.addError,
    );

    final summarySubscription = _monthlySummaryCollection
        .doc(documentId)
        .snapshots()
        .listen(
          (snapshot) {
        final data = snapshot.data();

        totalSpent = _toInt(
          data?['totalSpent'],
        );

        emitData();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await budgetSubscription.cancel();
      await summarySubscription.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}