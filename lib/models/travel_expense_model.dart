import 'package:cloud_firestore/cloud_firestore.dart';

class TravelExpenseModel {
  final String expenseId;
  final String travelId;
  final String userId;

  final int amount;
  final String category;
  final String place;
  final String memo;

  final DateTime expenseDate;
  final DateTime createdAt;

  final bool isDeleted;
  final DateTime? deletedAt;

  const TravelExpenseModel({
    required this.expenseId,
    required this.travelId,
    required this.userId,
    required this.amount,
    required this.category,
    required this.place,
    required this.memo,
    required this.expenseDate,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  factory TravelExpenseModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        '여행 경비 문서 데이터가 존재하지 않습니다: ${document.id}',
      );
    }

    return TravelExpenseModel(
      expenseId: document.id,
      travelId: data['travelId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      amount: _toInt(data['amount']),
      category: data['category'] as String? ?? '기타',
      place: data['place'] as String? ?? '',
      memo: data['memo'] as String? ?? '',
      expenseDate: _toDateTime(data['expenseDate']),
      createdAt: _toDateTime(data['createdAt']),
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: _toNullableDateTime(data['deletedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'travelId': travelId,
      'userId': userId,
      'amount': amount,
      'category': category,
      'place': place,
      'memo': memo,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'deletedAt':
      deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    };
  }

  TravelExpenseModel copyWith({
    String? expenseId,
    String? travelId,
    String? userId,
    int? amount,
    String? category,
    String? place,
    String? memo,
    DateTime? expenseDate,
    DateTime? createdAt,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TravelExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      travelId: travelId ?? this.travelId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      place: place ?? this.place,
      memo: memo ?? this.memo,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt ? null : deletedAt ?? this.deletedAt,
    );
  }

  static int _toInt(dynamic value) {
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

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}