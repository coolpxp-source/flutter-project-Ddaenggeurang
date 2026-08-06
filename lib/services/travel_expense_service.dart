import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/travel_expense_model.dart';
import '../models/travel_model.dart';

class TravelExpenseService {
  TravelExpenseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore =
      firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>
  get _expenseCollection {
    return _firestore.collection('travelExpenses');
  }

  CollectionReference<Map<String, dynamic>>
  get _travelCollection {
    return _firestore.collection('travels');
  }

  String get _currentUserId {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('로그인이 필요한 기능입니다.');
    }

    return user.uid;
  }

  /// 현재 사용자가 여행 생성자 또는 참여자인지 검사
  Future<TravelModel> _requireTravelParticipant(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('여행 ID가 비어 있습니다.');
    }

    final DocumentSnapshot<Map<String, dynamic>> document =
    await _travelCollection.doc(trimmedTravelId).get();

    if (!document.exists || document.data() == null) {
      throw StateError('여행 정보를 찾을 수 없습니다.');
    }

    final TravelModel travel =
    TravelModel.fromFirestore(document);

    if (travel.isDeleted) {
      throw StateError('삭제된 여행입니다.');
    }

    if (!travel.isParticipant(_currentUserId)) {
      throw StateError(
        '여행 생성자와 초대를 수락한 회원만 이용할 수 있습니다.',
      );
    }

    return travel;
  }

  /// 여행 경비 등록
  Future<String> createExpense({
    required String travelId,
    required String payerId,
    required String payerName,
    required int amount,
    required String category,
    required String place,
    required String memo,
    required DateTime expenseDate,
  }) async {
    final String trimmedTravelId = travelId.trim();
    final String trimmedPayerId = payerId.trim();
    final String trimmedPayerName = payerName.trim();
    final String trimmedCategory = category.trim();
    final String trimmedPlace = place.trim();
    final String trimmedMemo = memo.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('여행 ID가 비어 있습니다.');
    }

    if (trimmedPayerId.isEmpty) {
      throw ArgumentError('결제자를 선택해주세요.');
    }

    if (trimmedPayerName.isEmpty) {
      throw ArgumentError('결제자 이름이 비어 있습니다.');
    }

    if (amount <= 0) {
      throw ArgumentError('경비 금액은 0원보다 커야 합니다.');
    }

    if (trimmedCategory.isEmpty) {
      throw ArgumentError('경비 카테고리를 선택해주세요.');
    }

    final TravelModel travel =
    await _requireTravelParticipant(trimmedTravelId);

    if (!travel.isParticipant(trimmedPayerId)) {
      throw StateError(
        '여행에 참여한 회원만 결제자로 선택할 수 있습니다.',
      );
    }

    final String userId = _currentUserId;

    final DocumentReference<Map<String, dynamic>> document =
    _expenseCollection.doc();

    final TravelExpenseModel expense = TravelExpenseModel(
      expenseId: document.id,
      travelId: trimmedTravelId,
      userId: userId,
      payerId: trimmedPayerId,
      payerName: trimmedPayerName,
      amount: amount,
      category: trimmedCategory,
      place: trimmedPlace,
      memo: trimmedMemo,
      expenseDate: expenseDate,
      createdAt: DateTime.now(),
      isDeleted: false,
      deletedAt: null,
    );

    try {
      await document.set(<String, dynamic>{
        ...expense.toFirestore(),
        'expenseId': document.id,
        'createdById': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 경비 등록 성공: ${document.id}');

      return document.id;
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 경비 등록 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage: '여행 경비 저장에 실패했습니다.',
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('여행 경비 등록 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 여행 참여자가 전체 경비를 실시간 조회
  Stream<List<TravelExpenseModel>>
  watchExpensesByTravelId(String travelId) async* {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      yield <TravelExpenseModel>[];
      return;
    }

    await _requireTravelParticipant(trimmedTravelId);

    yield* _expenseCollection
        .where(
      'travelId',
      isEqualTo: trimmedTravelId,
    )
        .where(
      'isDeleted',
      isEqualTo: false,
    )
        .snapshots()
        .map((snapshot) {
      final List<TravelExpenseModel> expenses =
      snapshot.docs
          .map(TravelExpenseModel.fromFirestore)
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
    });
  }

  /// 여행 참여자가 전체 경비를 한 번 조회
  Future<List<TravelExpenseModel>>
  getExpensesByTravelId(String travelId) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      return <TravelExpenseModel>[];
    }

    await _requireTravelParticipant(trimmedTravelId);

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await _expenseCollection
          .where(
        'travelId',
        isEqualTo: trimmedTravelId,
      )
          .where(
        'isDeleted',
        isEqualTo: false,
      )
          .get();

      final List<TravelExpenseModel> expenses =
      snapshot.docs
          .map(TravelExpenseModel.fromFirestore)
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
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 경비 목록 조회 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage: '여행 경비 목록을 불러오지 못했습니다.',
        ),
      );
    }
  }

  /// 경비 한 건 조회
  Future<TravelExpenseModel?> getExpenseById(
      String expenseId,
      ) async {
    final String trimmedExpenseId = expenseId.trim();

    if (trimmedExpenseId.isEmpty) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
      await _expenseCollection
          .doc(trimmedExpenseId)
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      final TravelExpenseModel expense =
      TravelExpenseModel.fromFirestore(document);

      if (expense.isDeleted) {
        return null;
      }

      await _requireTravelParticipant(expense.travelId);

      return expense;
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 경비 단건 조회 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage: '여행 경비 정보를 불러오지 못했습니다.',
        ),
      );
    }
  }

  /// 여행 경비 수정
  ///
  /// 경비를 등록한 회원만 수정할 수 있다.
  Future<void> updateExpense({
    required String expenseId,
    String? payerId,
    String? payerName,
    required int amount,
    required String category,
    required String place,
    required String memo,
    required DateTime expenseDate,
  }) async {
    final String trimmedExpenseId = expenseId.trim();
    final String trimmedCategory = category.trim();
    final String trimmedPlace = place.trim();
    final String trimmedMemo = memo.trim();

    if (trimmedExpenseId.isEmpty) {
      throw ArgumentError('경비 ID가 비어 있습니다.');
    }

    if (amount <= 0) {
      throw ArgumentError('경비 금액은 0원보다 커야 합니다.');
    }

    if (trimmedCategory.isEmpty) {
      throw ArgumentError('경비 카테고리를 선택해주세요.');
    }

    final TravelExpenseModel? expense =
    await getExpenseById(trimmedExpenseId);

    if (expense == null) {
      throw StateError('수정할 여행 경비를 찾을 수 없습니다.');
    }

    if (expense.userId != _currentUserId) {
      throw StateError(
        '경비를 등록한 회원만 수정할 수 있습니다.',
      );
    }

    final TravelModel travel =
    await _requireTravelParticipant(expense.travelId);

    final String updatedPayerId =
    payerId?.trim().isNotEmpty == true
        ? payerId!.trim()
        : expense.effectivePayerId;

    final String updatedPayerName =
    payerName?.trim().isNotEmpty == true
        ? payerName!.trim()
        : expense.payerName.trim();

    if (!travel.isParticipant(updatedPayerId)) {
      throw StateError(
        '여행에 참여한 회원만 결제자로 선택할 수 있습니다.',
      );
    }

    try {
      await _expenseCollection
          .doc(trimmedExpenseId)
          .update(<String, dynamic>{
        'payerId': updatedPayerId,
        'payerName': updatedPayerName,
        'amount': amount,
        'category': trimmedCategory,
        'place': trimmedPlace,
        'memo': trimmedMemo,
        'expenseDate': Timestamp.fromDate(expenseDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 경비 수정 성공: $trimmedExpenseId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 경비 수정 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage: '여행 경비 수정에 실패했습니다.',
        ),
      );
    }
  }

  /// 여행 경비 소프트 삭제
  ///
  /// 경비를 등록한 회원만 삭제할 수 있다.
  Future<void> deleteExpense(String expenseId) async {
    final String trimmedExpenseId = expenseId.trim();

    if (trimmedExpenseId.isEmpty) {
      throw ArgumentError('경비 ID가 비어 있습니다.');
    }

    final TravelExpenseModel? expense =
    await getExpenseById(trimmedExpenseId);

    if (expense == null) {
      throw StateError('삭제할 여행 경비를 찾을 수 없습니다.');
    }

    if (expense.userId != _currentUserId) {
      throw StateError(
        '경비를 등록한 회원만 삭제할 수 있습니다.',
      );
    }

    await _requireTravelParticipant(expense.travelId);

    try {
      await _expenseCollection
          .doc(trimmedExpenseId)
          .update(<String, dynamic>{
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 경비 삭제 성공: $trimmedExpenseId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 경비 삭제 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage: '여행 경비 삭제에 실패했습니다.',
        ),
      );
    }
  }

  /// 여행 전체 사용 금액
  Future<int> getTotalExpenseAmount(
      String travelId,
      ) async {
    final List<TravelExpenseModel> expenses =
    await getExpensesByTravelId(travelId);

    return expenses.fold<int>(
      0,
          (
          int total,
          TravelExpenseModel expense,
          ) {
        return total + expense.amount;
      },
    );
  }

  /// 카테고리별 사용 금액
  Future<Map<String, int>> getCategoryTotals(
      String travelId,
      ) async {
    final List<TravelExpenseModel> expenses =
    await getExpensesByTravelId(travelId);

    final Map<String, int> totals = <String, int>{};

    for (final TravelExpenseModel expense in expenses) {
      totals.update(
        expense.category,
            (int currentAmount) {
          return currentAmount + expense.amount;
        },
        ifAbsent: () {
          return expense.amount;
        },
      );
    }

    final List<MapEntry<String, int>> entries =
    totals.entries.toList()
      ..sort(
            (
            MapEntry<String, int> first,
            MapEntry<String, int> second,
            ) {
          return second.value.compareTo(first.value);
        },
      );

    return Map<String, int>.fromEntries(entries);
  }

  /// 결제자별 총 결제 금액
  Future<Map<String, int>> getPayerTotals(
      String travelId,
      ) async {
    final List<TravelExpenseModel> expenses =
    await getExpensesByTravelId(travelId);

    final Map<String, int> totals = <String, int>{};

    for (final TravelExpenseModel expense in expenses) {
      totals.update(
        expense.effectivePayerId,
            (int currentAmount) {
          return currentAmount + expense.amount;
        },
        ifAbsent: () {
          return expense.amount;
        },
      );
    }

    return totals;
  }

  /// 여행에 등록된 경비 개수
  Future<int> getExpenseCount(String travelId) async {
    final List<TravelExpenseModel> expenses =
    await getExpensesByTravelId(travelId);

    return expenses.length;
  }

  String _firebaseErrorMessage(
      FirebaseException error, {
        required String defaultMessage,
      }) {
    switch (error.code) {
      case 'permission-denied':
        return '여행 참여 권한이 없습니다.';
      case 'unauthenticated':
        return '로그인이 필요한 기능입니다.';
      case 'unavailable':
        return '네트워크 상태를 확인해주세요.';
      default:
        return defaultMessage;
    }
  }

  void _printFirebaseError(
      String title,
      FirebaseException error,
      StackTrace stackTrace,
      ) {
    debugPrint(title);
    debugPrint('오류 코드: ${error.code}');
    debugPrint('오류 메시지: ${error.message}');
    debugPrintStack(stackTrace: stackTrace);
  }
}