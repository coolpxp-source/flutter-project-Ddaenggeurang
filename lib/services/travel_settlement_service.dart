import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/travel_expense_model.dart';
import '../models/travel_member_model.dart';
import '../models/travel_settlement_model.dart';

class TravelSettlementService {
  TravelSettlementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
  get _settlementCollection {
    return _db.collection('travelSettlements');
  }

  CollectionReference<Map<String, dynamic>>
  get _memberCollection {
    return _db.collection('travelMembers');
  }

  CollectionReference<Map<String, dynamic>>
  get _expenseCollection {
    return _db.collection('travelExpenses');
  }

  String get _currentUserId {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('로그인이 필요한 기능입니다.');
    }

    return user.uid;
  }

  /// Firestore 데이터를 불러와 정산 결과 계산
  Future<TravelSettlementModel> calculateFromFirestore(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    try {
      final List<dynamic> results =
      await Future.wait<dynamic>(
        <Future<dynamic>>[
          _getMembers(trimmedTravelId),
          _getExpenses(trimmedTravelId),
        ],
      );

      final List<TravelMemberModel> members =
      results[0] as List<TravelMemberModel>;

      final List<TravelExpenseModel> expenses =
      results[1] as List<TravelExpenseModel>;

      return calculateSettlement(
        travelId: trimmedTravelId,
        members: members,
        expenses: expenses,
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 정산 데이터 조회 실패');
      debugPrint('travelId: $trimmedTravelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
        '정산 데이터를 불러오지 못했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    } catch (error, stackTrace) {
      debugPrint('여행 정산 계산 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 참여자와 경비 목록으로 정산 결과 계산
  TravelSettlementModel calculateSettlement({
    required String travelId,
    required List<TravelMemberModel> members,
    required List<TravelExpenseModel> expenses,
  }) {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    final List<TravelMemberModel> activeMembers =
    members
        .where(
          (TravelMemberModel member) =>
      !member.isDeleted &&
          member.memberId.trim().isNotEmpty,
    )
        .toList();

    if (activeMembers.isEmpty) {
      throw StateError(
        '등록된 여행 참여자가 없습니다.\n'
            '참여자를 먼저 추가해 주세요.',
      );
    }

    final List<TravelExpenseModel> activeExpenses =
    expenses
        .where(
          (TravelExpenseModel expense) =>
      !expense.isDeleted &&
          expense.amount > 0,
    )
        .toList();

    final int totalAmount =
    activeExpenses.fold<int>(
      0,
          (
          int total,
          TravelExpenseModel expense,
          ) {
        return total + expense.amount;
      },
    );

    final int memberCount = activeMembers.length;
    final int perPersonAmount =
        totalAmount ~/ memberCount;
    final int remainderAmount =
        totalAmount % memberCount;

    final Map<String, int> paidAmounts =
    <String, int>{
      for (final TravelMemberModel member
      in activeMembers)
        member.memberId: 0,
    };

    for (final TravelExpenseModel expense
    in activeExpenses) {
      final TravelMemberModel? payer = _findPayer(
        expense: expense,
        members: activeMembers,
      );

      if (payer == null) {
        final String expenseName =
        expense.place.trim().isEmpty
            ? expense.category
            : expense.place;

        throw StateError(
          '$expenseName 경비의 결제자가 '
              '여행 참여자 목록에 없습니다.\n'
              '경비의 결제자를 다시 선택해 주세요.',
        );
      }

      paidAmounts[payer.memberId] =
          (paidAmounts[payer.memberId] ?? 0) +
              expense.amount;
    }

    final List<SettlementMemberSummary> summaries =
    <SettlementMemberSummary>[];

    for (int index = 0;
    index < activeMembers.length;
    index++) {
      final TravelMemberModel member =
      activeMembers[index];

      // 나누어떨어지지 않는 나머지는
      // 참여자 순서대로 1원씩 부담한다.
      final int extraAmount =
      index < remainderAmount ? 1 : 0;

      final int shareAmount =
          perPersonAmount + extraAmount;

      final int paidAmount =
          paidAmounts[member.memberId] ?? 0;

      summaries.add(
        SettlementMemberSummary(
          memberId: member.memberId,
          memberName: member.displayName,
          paidAmount: paidAmount,
          shareAmount: shareAmount,
          balance: paidAmount - shareAmount,
        ),
      );
    }

    final List<SettlementTransferModel> transfers =
    _calculateTransfers(summaries);

    return TravelSettlementModel(
      settlementId: trimmedTravelId,
      travelId: trimmedTravelId,
      totalAmount: totalAmount,
      memberCount: memberCount,
      perPersonAmount: perPersonAmount,
      remainderAmount: remainderAmount,
      memberSummaries: summaries,
      transfers: transfers,
      isCompleted: false,
      createdAt: DateTime.now(),
      completedAt: null,
    );
  }

  /// 정산 결과 저장
  Future<void> saveSettlement(
      TravelSettlementModel settlement,
      ) async {
    final String travelId =
    settlement.travelId.trim();

    if (travelId.isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    try {
      final DocumentReference<Map<String, dynamic>>
      document =
      _settlementCollection.doc(travelId);

      await document.set(
        <String, dynamic>{
          'settlementId': document.id,
          'travelId': travelId,
          'totalAmount': settlement.totalAmount,
          'memberCount': settlement.memberCount,
          'perPersonAmount':
          settlement.perPersonAmount,
          'remainderAmount':
          settlement.remainderAmount,
          'memberSummaries': settlement.memberSummaries
              .map(
                (SettlementMemberSummary summary) =>
                summary.toMap(),
          )
              .toList(),
          'transfers': settlement.transfers
              .map(
                (SettlementTransferModel transfer) =>
                transfer.toMap(),
          )
              .toList(),
          'isCompleted': settlement.isCompleted,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'completedAt':
          settlement.completedAt == null
              ? null
              : Timestamp.fromDate(
            settlement.completedAt!,
          ),
        },
        SetOptions(merge: true),
      );

      debugPrint(
        '여행 정산 저장 성공: $travelId',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 정산 저장 실패');
      debugPrint('travelId: $travelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
        '정산 결과 저장에 실패했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    } catch (error, stackTrace) {
      debugPrint('여행 정산 저장 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 정산 계산 후 저장
  Future<TravelSettlementModel> calculateAndSave(
      String travelId,
      ) async {
    final TravelSettlementModel settlement =
    await calculateFromFirestore(travelId);

    await saveSettlement(settlement);

    return settlement;
  }

  /// 저장된 정산 결과 조회
  Future<TravelSettlementModel?> getSettlement(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      return null;
    }

    // 로그인 상태를 먼저 확인한다.
    _currentUserId;

    try {
      final DocumentSnapshot<Map<String, dynamic>>
      document = await _settlementCollection
          .doc(trimmedTravelId)
          .get();

      if (!document.exists ||
          document.data() == null) {
        return null;
      }

      return TravelSettlementModel.fromFirestore(
        document,
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 정산 조회 실패');
      debugPrint('travelId: $trimmedTravelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
        '정산 결과를 불러오지 못했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 저장된 정산 결과 실시간 조회
  Stream<TravelSettlementModel?> watchSettlement(
      String travelId,
      ) {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      return Stream<TravelSettlementModel?>.value(
        null,
      );
    }

    _currentUserId;

    return _settlementCollection
        .doc(trimmedTravelId)
        .snapshots()
        .map(
          (
          DocumentSnapshot<Map<String, dynamic>>
          document,
          ) {
        if (!document.exists ||
            document.data() == null) {
          return null;
        }

        return TravelSettlementModel.fromFirestore(
          document,
        );
      },
    );
  }

  /// 정산 완료
  Future<void> completeSettlement(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    _currentUserId;

    try {
      await _settlementCollection
          .doc(trimmedTravelId)
          .update(<String, dynamic>{
        'isCompleted': true,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '여행 정산 완료: $trimmedTravelId',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 정산 완료 처리 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
        '정산 완료 처리에 실패했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 정산 완료 취소
  Future<void> reopenSettlement(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    _currentUserId;

    try {
      await _settlementCollection
          .doc(trimmedTravelId)
          .update(<String, dynamic>{
        'isCompleted': false,
        'completedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '여행 정산 완료 취소: $trimmedTravelId',
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 정산 완료 취소 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      throw Exception(
        '정산 완료 취소에 실패했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 여행 참여자 조회
  Future<List<TravelMemberModel>> _getMembers(
      String travelId,
      ) async {
    _currentUserId;

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _memberCollection
        .where(
      'travelId',
      isEqualTo: travelId,
    )
        .get();

    final List<TravelMemberModel> members =
    snapshot.docs
        .map(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) {
        return TravelMemberModel.fromFirestore(
          document,
        );
      },
    )
        .where(
          (TravelMemberModel member) =>
      !member.isDeleted,
    )
        .toList();

    members.sort(
          (
          TravelMemberModel first,
          TravelMemberModel second,
          ) {
        if (first.isOwner != second.isOwner) {
          return first.isOwner ? -1 : 1;
        }

        return first.createdAt.compareTo(
          second.createdAt,
        );
      },
    );

    return members;
  }

  /// 로그인 사용자의 여행 경비 조회
  Future<List<TravelExpenseModel>> _getExpenses(
      String travelId,
      ) async {
    // 로그인 상태를 확인한다.
    // Firestore 규칙에서 해당 여행의 참여자인지도 다시 검사한다.
    _currentUserId;

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _expenseCollection
        .where(
      'travelId',
      isEqualTo: travelId,
    )
        .where(
      'isDeleted',
      isEqualTo: false,
    )
        .get();

    final List<TravelExpenseModel> expenses =
    snapshot.docs
        .map(
          (
          QueryDocumentSnapshot<
              Map<String, dynamic>>
          document,
          ) {
        return TravelExpenseModel.fromFirestore(
          document,
        );
      },
    )
        .toList();

    expenses.sort(
          (
          TravelExpenseModel first,
          TravelExpenseModel second,
          ) {
        return second.expenseDate.compareTo(
          first.expenseDate,
        );
      },
    );

    return expenses;
  }

  /// 경비 결제자와 참여자 연결
  TravelMemberModel? _findPayer({
    required TravelExpenseModel expense,
    required List<TravelMemberModel> members,
  }) {
    final String payerId =
        expense.effectivePayerId;

    // 새 경비는 참여자 문서 ID가 payerId에 저장된다.
    for (final TravelMemberModel member in members) {
      if (member.memberId == payerId) {
        return member;
      }
    }

    // 기존 경비는 등록자 UID만 있으므로
    // 참여자의 Firebase UID와 비교한다.
    for (final TravelMemberModel member in members) {
      if (member.userId.trim().isNotEmpty &&
          member.userId.trim() == payerId) {
        return member;
      }
    }

    return null;
  }

  /// 받을 사람과 보낼 사람 연결
  List<SettlementTransferModel> _calculateTransfers(
      List<SettlementMemberSummary> summaries,
      ) {
    final List<_SettlementBalance> debtors =
    summaries
        .where(
          (SettlementMemberSummary summary) =>
      summary.balance < 0,
    )
        .map(
          (SettlementMemberSummary summary) =>
          _SettlementBalance(
            memberId: summary.memberId,
            memberName: summary.memberName,
            amount: summary.balance.abs(),
          ),
    )
        .toList();

    final List<_SettlementBalance> creditors =
    summaries
        .where(
          (SettlementMemberSummary summary) =>
      summary.balance > 0,
    )
        .map(
          (SettlementMemberSummary summary) =>
          _SettlementBalance(
            memberId: summary.memberId,
            memberName: summary.memberName,
            amount: summary.balance,
          ),
    )
        .toList();

    final List<SettlementTransferModel> transfers =
    <SettlementTransferModel>[];

    int debtorIndex = 0;
    int creditorIndex = 0;

    while (debtorIndex < debtors.length &&
        creditorIndex < creditors.length) {
      final _SettlementBalance debtor =
      debtors[debtorIndex];

      final _SettlementBalance creditor =
      creditors[creditorIndex];

      final int transferAmount =
      debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      if (transferAmount > 0) {
        transfers.add(
          SettlementTransferModel(
            fromMemberId: debtor.memberId,
            fromMemberName: debtor.memberName,
            toMemberId: creditor.memberId,
            toMemberName: creditor.memberName,
            amount: transferAmount,
          ),
        );
      }

      debtor.amount -= transferAmount;
      creditor.amount -= transferAmount;

      if (debtor.amount == 0) {
        debtorIndex++;
      }

      if (creditor.amount == 0) {
        creditorIndex++;
      }
    }

    return transfers;
  }
}

class _SettlementBalance {
  final String memberId;
  final String memberName;

  int amount;

  _SettlementBalance({
    required this.memberId,
    required this.memberName,
    required this.amount,
  });
}
