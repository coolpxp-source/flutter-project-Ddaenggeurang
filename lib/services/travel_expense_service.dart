import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/travel_expense_model.dart';

class TravelExpenseService {
  TravelExpenseService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _expenseCollection {
    return _firestore.collection('travelExpenses');
  }

  String get _currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('로그인이 필요한 기능입니다.');
    }

    return user.uid;
  }

  /// 여행 경비 등록
  Future<String> createExpense({
    required String travelId,
    required int amount,
    required String category,
    required String place,
    required String memo,
    required DateTime expenseDate,
  }) async {
    if (travelId.trim().isEmpty) {
      throw ArgumentError('여행 ID가 비어 있습니다.');
    }

    if (amount <= 0) {
      throw ArgumentError('경비 금액은 0원보다 커야 합니다.');
    }

    if (category.trim().isEmpty) {
      throw ArgumentError('경비 카테고리를 선택해야 합니다.');
    }

    final userId = _currentUserId;
    final document = _expenseCollection.doc();

    final expense = TravelExpenseModel(
      expenseId: document.id,
      travelId: travelId.trim(),
      userId: userId,
      amount: amount,
      category: category.trim(),
      place: place.trim(),
      memo: memo.trim(),
      expenseDate: expenseDate,
      createdAt: DateTime.now(),
      isDeleted: false,
      deletedAt: null,
    );

    try {
      await document.set(expense.toFirestore());

      return document.id;
    } on FirebaseException catch (error) {
      throw Exception(
        '여행 경비 저장에 실패했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 여행별 경비 실시간 조회
  Stream<List<TravelExpenseModel>> watchExpensesByTravelId(
      String travelId,
      ) {
    final userId = _currentUserId;

    return _expenseCollection
        .where('userId', isEqualTo: userId)
        .where('travelId', isEqualTo: travelId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      final expenses = snapshot.docs
          .map(TravelExpenseModel.fromFirestore)
          .toList();

      expenses.sort(
            (a, b) => b.expenseDate.compareTo(a.expenseDate),
      );

      return expenses;
    });
  }

  /// 여행별 경비 1회 조회
  Future<List<TravelExpenseModel>> getExpensesByTravelId(
      String travelId,
      ) async {
    final userId = _currentUserId;

    try {
      final snapshot = await _expenseCollection
          .where('userId', isEqualTo: userId)
          .where('travelId', isEqualTo: travelId)
          .where('isDeleted', isEqualTo: false)
          .get();

      final expenses = snapshot.docs
          .map(TravelExpenseModel.fromFirestore)
          .toList();

      expenses.sort(
            (a, b) => b.expenseDate.compareTo(a.expenseDate),
      );

      return expenses;
    } on FirebaseException catch (error) {
      throw Exception(
        '여행 경비 목록을 불러오지 못했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 경비 한 건 조회
  Future<TravelExpenseModel?> getExpenseById(
      String expenseId,
      ) async {
    final userId = _currentUserId;

    try {
      final document = await _expenseCollection.doc(expenseId).get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      final expense = TravelExpenseModel.fromFirestore(document);

      if (expense.userId != userId || expense.isDeleted) {
        return null;
      }

      return expense;
    } on FirebaseException catch (error) {
      throw Exception(
        '여행 경비 정보를 불러오지 못했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 여행 경비 수정
  Future<void> updateExpense({
    required String expenseId,
    required int amount,
    required String category,
    required String place,
    required String memo,
    required DateTime expenseDate,
  }) async {
    if (expenseId.trim().isEmpty) {
      throw ArgumentError('경비 ID가 비어 있습니다.');
    }

    if (amount <= 0) {
      throw ArgumentError('경비 금액은 0원보다 커야 합니다.');
    }

    if (category.trim().isEmpty) {
      throw ArgumentError('경비 카테고리를 선택해야 합니다.');
    }

    final expense = await getExpenseById(expenseId);

    if (expense == null) {
      throw StateError('수정할 여행 경비를 찾을 수 없습니다.');
    }

    try {
      await _expenseCollection.doc(expenseId).update({
        'amount': amount,
        'category': category.trim(),
        'place': place.trim(),
        'memo': memo.trim(),
        'expenseDate': Timestamp.fromDate(expenseDate),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw Exception(
        '여행 경비 수정에 실패했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 여행 경비 소프트 삭제
  Future<void> deleteExpense(String expenseId) async {
    final expense = await getExpenseById(expenseId);

    if (expense == null) {
      throw StateError('삭제할 여행 경비를 찾을 수 없습니다.');
    }

    try {
      await _expenseCollection.doc(expenseId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (error) {
      throw Exception(
        '여행 경비 삭제에 실패했습니다. '
            '[${error.code}] ${error.message ?? ''}',
      );
    }
  }

  /// 여행 전체 사용 금액
  Future<int> getTotalExpenseAmount(String travelId) async {
    final expenses = await getExpensesByTravelId(travelId);

    return expenses.fold<int>(
      0,
          (total, expense) => total + expense.amount,
    );
  }

  /// 카테고리별 사용 금액
  Future<Map<String, int>> getCategoryTotals(
      String travelId,
      ) async {
    final expenses = await getExpensesByTravelId(travelId);
    final totals = <String, int>{};

    for (final expense in expenses) {
      totals.update(
        expense.category,
            (currentAmount) => currentAmount + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return totals;
  }
}