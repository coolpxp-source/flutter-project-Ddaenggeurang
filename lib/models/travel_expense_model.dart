import 'package:cloud_firestore/cloud_firestore.dart';

class TravelExpenseModel {
  /// Firestore 경비 문서 ID
  final String expenseId;

  /// 경비가 속한 여행 문서 ID
  final String travelId;

  /// 경비를 등록한 사용자 UID
  final String userId;

  /// 실제 결제자 ID
  ///
  /// 기존 데이터에 값이 없으면 userId를 결제자 ID로 사용한다.
  final String payerId;

  /// 실제 결제자 이름
  final String payerName;

  /// 지출 금액
  final int amount;

  /// 지출 카테고리
  final String category;

  /// 지출 장소
  final String place;

  /// 지출 메모
  final String memo;

  /// 실제 지출 날짜
  final DateTime expenseDate;

  /// 문서 생성 날짜
  final DateTime createdAt;

  /// 소프트 삭제 여부
  final bool isDeleted;

  /// 삭제 날짜
  final DateTime? deletedAt;

  const TravelExpenseModel({
    required this.expenseId,
    required this.travelId,
    required this.userId,
    this.payerId = '',
    this.payerName = '',
    required this.amount,
    required this.category,
    required this.place,
    required this.memo,
    required this.expenseDate,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// 실제 정산에 사용할 결제자 ID
  ///
  /// 기존 경비 데이터에 payerId가 없으면
  /// 경비 등록자 userId를 결제자로 처리한다.
  String get effectivePayerId {
    if (payerId.trim().isNotEmpty) {
      return payerId.trim();
    }

    return userId.trim();
  }

  /// 화면에 표시할 결제자 이름
  String get displayPayerName {
    if (payerName.trim().isNotEmpty) {
      return payerName.trim();
    }

    return '결제자 미지정';
  }

  /// Firestore 문서를 TravelExpenseModel로 변환
  factory TravelExpenseModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw StateError(
        '여행 경비 문서 데이터가 존재하지 않습니다: ${document.id}',
      );
    }

    final String userId = _toString(data['userId']);
    final String payerId = _toString(data['payerId']);

    return TravelExpenseModel(
      expenseId: document.id,
      travelId: _toString(data['travelId']),
      userId: userId,
      payerId: payerId.isEmpty ? userId : payerId,
      payerName: _toString(data['payerName']),
      amount: _toInt(data['amount']),
      category: _toCategory(data['category']),
      place: _toString(data['place']),
      memo: _toString(data['memo']),
      expenseDate: _toDateTime(
        data['expenseDate'],
      ),
      createdAt: _toDateTime(
        data['createdAt'],
      ),
      isDeleted: _toBool(
        data['isDeleted'],
      ),
      deletedAt: _toNullableDateTime(
        data['deletedAt'],
      ),
    );
  }

  /// TravelExpenseModel을 Firestore 데이터로 변환
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'expenseId': expenseId,
      'travelId': travelId.trim(),
      'userId': userId.trim(),
      'payerId': effectivePayerId,
      'payerName': payerName.trim(),
      'amount': amount,
      'category': category.trim().isEmpty
          ? '기타'
          : category.trim(),
      'place': place.trim(),
      'memo': memo.trim(),
      'expenseDate': Timestamp.fromDate(
        expenseDate,
      ),
      'createdAt': Timestamp.fromDate(
        createdAt,
      ),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt == null
          ? null
          : Timestamp.fromDate(
        deletedAt!,
      ),
    };
  }

  /// 모델 일부 값 변경
  TravelExpenseModel copyWith({
    String? expenseId,
    String? travelId,
    String? userId,
    String? payerId,
    String? payerName,
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
      payerId: payerId ?? this.payerId,
      payerName: payerName ?? this.payerName,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      place: place ?? this.place,
      memo: memo ?? this.memo,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt
          ? null
          : deletedAt ?? this.deletedAt,
    );
  }

  /// Map 데이터로 변환
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'expenseId': expenseId,
      'travelId': travelId,
      'userId': userId,
      'payerId': payerId,
      'effectivePayerId': effectivePayerId,
      'payerName': payerName,
      'amount': amount,
      'category': category,
      'place': place,
      'memo': memo,
      'expenseDate': expenseDate,
      'createdAt': createdAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

  /// dynamic 값을 문자열로 변환
  static String _toString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  /// 카테고리 변환
  static String _toCategory(dynamic value) {
    final String category = _toString(value);

    if (category.isEmpty) {
      return '기타';
    }

    return category;
  }

  /// dynamic 값을 int로 변환
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

    final String stringValue =
        value?.toString().replaceAll(',', '').trim() ?? '';

    return int.tryParse(stringValue) ?? 0;
  }

  /// dynamic 값을 bool로 변환
  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String stringValue =
        value?.toString().trim().toLowerCase() ?? '';

    return stringValue == 'true' ||
        stringValue == '1' ||
        stringValue == 'y';
  }

  /// dynamic 값을 DateTime으로 변환
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

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    }

    return DateTime.now();
  }

  /// nullable DateTime 변환
  static DateTime? _toNullableDateTime(
      dynamic value,
      ) {
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
      if (value.trim().isEmpty) {
        return null;
      }

      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    }

    return null;
  }

  @override
  String toString() {
    return 'TravelExpenseModel('
        'expenseId: $expenseId, '
        'travelId: $travelId, '
        'userId: $userId, '
        'payerId: $payerId, '
        'payerName: $payerName, '
        'amount: $amount, '
        'category: $category, '
        'place: $place, '
        'memo: $memo, '
        'expenseDate: $expenseDate, '
        'createdAt: $createdAt, '
        'isDeleted: $isDeleted, '
        'deletedAt: $deletedAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is TravelExpenseModel &&
        other.expenseId == expenseId &&
        other.travelId == travelId &&
        other.userId == userId &&
        other.payerId == payerId &&
        other.payerName == payerName &&
        other.amount == amount &&
        other.category == category &&
        other.place == place &&
        other.memo == memo &&
        other.expenseDate == expenseDate &&
        other.createdAt == createdAt &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      expenseId,
      travelId,
      userId,
      payerId,
      payerName,
      amount,
      category,
      place,
      memo,
      expenseDate,
      createdAt,
      isDeleted,
      deletedAt,
    );
  }
}