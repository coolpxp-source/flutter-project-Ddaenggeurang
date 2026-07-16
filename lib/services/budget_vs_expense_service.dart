import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/budget_vs_expense_model.dart';

/// 예산 대비 지출 서비스
///
/// 예산 조회:
/// budgets/{userId}_{yyyy-MM}
///
/// 월별 지출 집계 조회 및 저장:
/// monthlySummary/{userId}_{yyyy-MM}
///
/// 월별 지출 집계의 원본:
/// expenses 컬렉션
class BudgetVsExpenseService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  BudgetVsExpenseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
      firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// budgets 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _budgetCollection {
    return _firestore.collection('budgets');
  }

  /// monthlySummary 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _monthlySummaryCollection {
    return _firestore.collection(
      'monthlySummary',
    );
  }

  /// expenses 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _expenseCollection {
    return _firestore.collection('expenses');
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

  /// 예산과 monthlySummary를 실시간 조회
  Stream<BudgetVsExpenseModel>
  watchBudgetVsExpense({
    required String userId,
    required String monthKey,
  }) {
    final documentId =
    createMonthlyDocumentId(
      userId: userId,
      monthKey: monthKey,
    );

    final controller =
    StreamController<
        BudgetVsExpenseModel>();

    int totalBudget = 0;
    int totalSpent = 0;

    bool budgetLoaded = false;
    bool summaryLoaded = false;

    /// 예산과 지출 조회가 모두 끝난 경우
    /// 화면에 데이터를 전달
    void emitData() {
      if (controller.isClosed) {
        return;
      }

      if (!budgetLoaded ||
          !summaryLoaded) {
        return;
      }

      controller.add(
        BudgetVsExpenseModel(
          totalBudget: totalBudget,
          totalSpent: totalSpent,
        ),
      );
    }

    /// budgets/{userId}_{monthKey} 조회
    final budgetSubscription =
    _budgetCollection
        .doc(documentId)
        .snapshots()
        .listen(
          (snapshot) {
        final data = snapshot.data();

        totalBudget = _toInt(
          data?['totalBudget'],
        );

        budgetLoaded = true;

        debugPrint(
          '[예산 조회] '
              'budgets/$documentId '
              'totalBudget=$totalBudget',
        );

        emitData();
      },
      onError: (
          Object error,
          StackTrace stackTrace,
          ) {
        debugPrint(
          '[예산 조회 실패] $error',
        );

        if (!controller.isClosed) {
          controller.addError(
            error,
            stackTrace,
          );
        }
      },
    );

    /// monthlySummary/{userId}_{monthKey} 조회
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

        debugPrint(
          '[월별 지출 조회] '
              'monthlySummary/$documentId '
              'totalSpent=$totalSpent',
        );

        emitData();
      },
      onError: (
          Object error,
          StackTrace stackTrace,
          ) {
        debugPrint(
          '[월별 지출 조회 실패] $error',
        );

        if (!controller.isClosed) {
          controller.addError(
            error,
            stackTrace,
          );
        }
      },
    );

    /// 화면이 종료되면 Firestore 구독 종료
    controller.onCancel = () async {
      await budgetSubscription.cancel();
      await summarySubscription.cancel();

      if (!controller.isClosed) {
        await controller.close();
      }
    };

    return controller.stream;
  }

  /// expenses 컬렉션을 조회해서
  /// 해당 사용자의 선택 월 지출을 합산한 뒤
  /// monthlySummary에 저장한다.
  ///
  /// 저장 위치:
  /// monthlySummary/{userId}_{monthKey}
  Future<void> rebuildMonthlySummary({
    required String userId,
    required String monthKey,
  }) async {
    if (userId.trim().isEmpty) {
      throw Exception(
        '사용자 UID가 비어 있습니다.',
      );
    }

    /// Firebase 로그인 여부 확인
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        '로그인된 사용자가 없습니다.',
      );
    }

    /// 화면에서 받은 UID와
    /// 실제 로그인 UID가 같은지 검사
    if (currentUser.uid != userId) {
      throw Exception(
        '화면 사용자 UID와 로그인 UID가 '
            '일치하지 않습니다.\n'
            '화면 UID: $userId\n'
            '로그인 UID: ${currentUser.uid}',
      );
    }

    final monthRange =
    _createMonthRange(monthKey);

    debugPrint(
      '================================',
    );
    debugPrint(
      '[monthlySummary 재계산 시작]',
    );
    debugPrint(
      '로그인 UID: ${currentUser.uid}',
    );
    debugPrint(
      '화면 UID: $userId',
    );
    debugPrint(
      '선택 월: $monthKey',
    );

    /// 현재 사용자의 expenses만 조회
    final expenseSnapshot =
    await _expenseCollection
        .where(
      'userId',
      isEqualTo: userId,
    )
        .get();

    debugPrint(
      '조회된 지출 문서 수: '
          '${expenseSnapshot.docs.length}',
    );

    int totalSpent = 0;
    int includedExpenseCount = 0;

    for (final document
    in expenseSnapshot.docs) {
      final data = document.data();

      debugPrint(
        '[지출 확인] '
            '문서 ID=${document.id}, '
            '데이터=$data',
      );

      /// 삭제된 지출 제외
      if (data['isDeleted'] == true) {
        debugPrint(
          '[지출 제외] 삭제된 문서',
        );
        continue;
      }

      /// 지출 날짜 읽기
      final expenseDate =
      _toDateTime(
        data['date'],
      );

      if (expenseDate == null) {
        debugPrint(
          '[지출 제외] date 필드 없음 '
              '또는 날짜 변환 실패',
        );
        continue;
      }

      /// 선택한 월에 포함되는지 검사
      final isSelectedMonth =
          !expenseDate.isBefore(
            monthRange.start,
          ) &&
              expenseDate.isBefore(
                monthRange.end,
              );

      if (!isSelectedMonth) {
        debugPrint(
          '[지출 제외] 다른 월 '
              'date=$expenseDate',
        );
        continue;
      }

      /// 지출 금액 읽기
      final amount = _toInt(
        data['amount'],
      );

      if (amount <= 0) {
        debugPrint(
          '[지출 제외] amount가 0 이하 '
              'amount=$amount',
        );
        continue;
      }

      totalSpent += amount;
      includedExpenseCount++;

      debugPrint(
        '[지출 합산] '
            'amount=$amount, '
            '누적=$totalSpent',
      );
    }

    final documentId =
    createMonthlyDocumentId(
      userId: userId,
      monthKey: monthKey,
    );

    debugPrint(
      '합산된 지출 문서 수: '
          '$includedExpenseCount',
    );

    debugPrint(
      '최종 지출 합계: $totalSpent',
    );

    debugPrint(
      '저장 경로: '
          'monthlySummary/$documentId',
    );

    /// monthlySummary 생성 또는 갱신
    await _monthlySummaryCollection
        .doc(documentId)
        .set(
      {
        'userId': userId,
        'monthKey': monthKey,
        'yearMonth': monthKey,
        'totalSpent': totalSpent,
        'expenseCount':
        includedExpenseCount,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
      SetOptions(
        merge: true,
      ),
    );

    debugPrint(
      '[monthlySummary 저장 완료]',
    );
    debugPrint(
      '================================',
    );
  }

  /// monthKey를 월 시작일과
  /// 다음 달 시작일로 변환
  ///
  /// 예:
  /// 2026-07
  ///
  /// start = 2026-07-01
  /// end = 2026-08-01
  _MonthRange _createMonthRange(
      String monthKey,
      ) {
    final parts = monthKey.split('-');

    if (parts.length != 2) {
      throw FormatException(
        'monthKey 형식이 잘못되었습니다: '
            '$monthKey',
      );
    }

    final year =
    int.tryParse(parts[0]);

    final month =
    int.tryParse(parts[1]);

    if (year == null ||
        month == null ||
        month < 1 ||
        month > 12) {
      throw FormatException(
        'monthKey 형식이 잘못되었습니다: '
            '$monthKey',
      );
    }

    return _MonthRange(
      start: DateTime(
        year,
        month,
        1,
      ),
      end: DateTime(
        year,
        month + 1,
        1,
      ),
    );
  }

  /// Firestore 숫자 값을 int로 변환
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
  DateTime? _toDateTime(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;
  }
}

/// 선택 월의 시작일과 종료일
class _MonthRange {
  final DateTime start;
  final DateTime end;

  const _MonthRange({
    required this.start,
    required this.end,
  });
}