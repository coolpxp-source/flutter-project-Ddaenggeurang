import 'package:cloud_firestore/cloud_firestore.dart';

/// 참여자 간 송금 정보
class SettlementTransferModel {
  /// 돈을 보내야 하는 참여자 ID
  final String fromMemberId;

  /// 돈을 보내야 하는 참여자 이름
  final String fromMemberName;

  /// 돈을 받을 참여자 ID
  final String toMemberId;

  /// 돈을 받을 참여자 이름
  final String toMemberName;

  /// 송금 금액
  final int amount;

  const SettlementTransferModel({
    required this.fromMemberId,
    required this.fromMemberName,
    required this.toMemberId,
    required this.toMemberName,
    required this.amount,
  });

  factory SettlementTransferModel.fromMap(
      Map<String, dynamic> data,
      ) {
    return SettlementTransferModel(
      fromMemberId: _toString(data['fromMemberId']),
      fromMemberName: _toString(data['fromMemberName']),
      toMemberId: _toString(data['toMemberId']),
      toMemberName: _toString(data['toMemberName']),
      amount: _toInt(data['amount']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'fromMemberId': fromMemberId.trim(),
      'fromMemberName': fromMemberName.trim(),
      'toMemberId': toMemberId.trim(),
      'toMemberName': toMemberName.trim(),
      'amount': amount,
    };
  }

  SettlementTransferModel copyWith({
    String? fromMemberId,
    String? fromMemberName,
    String? toMemberId,
    String? toMemberName,
    int? amount,
  }) {
    return SettlementTransferModel(
      fromMemberId:
      fromMemberId ?? this.fromMemberId,
      fromMemberName:
      fromMemberName ?? this.fromMemberName,
      toMemberId: toMemberId ?? this.toMemberId,
      toMemberName: toMemberName ?? this.toMemberName,
      amount: amount ?? this.amount,
    );
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString().replaceAll(',', '').trim() ??
          '',
    ) ??
        0;
  }

  @override
  String toString() {
    return '$fromMemberName → $toMemberName: $amount원';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is SettlementTransferModel &&
        other.fromMemberId == fromMemberId &&
        other.fromMemberName == fromMemberName &&
        other.toMemberId == toMemberId &&
        other.toMemberName == toMemberName &&
        other.amount == amount;
  }

  @override
  int get hashCode {
    return Object.hash(
      fromMemberId,
      fromMemberName,
      toMemberId,
      toMemberName,
      amount,
    );
  }
}

/// 참여자별 정산 요약
class SettlementMemberSummary {
  /// 참여자 ID
  final String memberId;

  /// 참여자 이름
  final String memberName;

  /// 실제로 결제한 총금액
  final int paidAmount;

  /// 최종 부담 금액
  final int shareAmount;

  /// 결제 금액 - 부담 금액
  ///
  /// 양수이면 돈을 받아야 하고,
  /// 음수이면 돈을 보내야 한다.
  final int balance;

  const SettlementMemberSummary({
    required this.memberId,
    required this.memberName,
    required this.paidAmount,
    required this.shareAmount,
    required this.balance,
  });

  bool get shouldReceive => balance > 0;

  bool get shouldSend => balance < 0;

  bool get isSettled => balance == 0;

  int get transferAmount => balance.abs();

  factory SettlementMemberSummary.fromMap(
      Map<String, dynamic> data,
      ) {
    return SettlementMemberSummary(
      memberId: _toString(data['memberId']),
      memberName: _toString(data['memberName']),
      paidAmount: _toInt(data['paidAmount']),
      shareAmount: _toInt(data['shareAmount']),
      balance: _toInt(data['balance']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'memberId': memberId.trim(),
      'memberName': memberName.trim(),
      'paidAmount': paidAmount,
      'shareAmount': shareAmount,
      'balance': balance,
    };
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString().replaceAll(',', '').trim() ??
          '',
    ) ??
        0;
  }
}

/// 여행 정산 결과
class TravelSettlementModel {
  /// Firestore 정산 문서 ID
  final String settlementId;

  /// 여행 ID
  final String travelId;

  /// 전체 여행 경비
  final int totalAmount;

  /// 참여자 수
  final int memberCount;

  /// 기본 1인당 부담 금액
  final int perPersonAmount;

  /// 나누어떨어지지 않고 남은 금액
  final int remainderAmount;

  /// 참여자별 정산 요약
  final List<SettlementMemberSummary> memberSummaries;

  /// 최종 송금 목록
  final List<SettlementTransferModel> transfers;

  /// 정산 완료 여부
  final bool isCompleted;

  /// 정산 계산 날짜
  final DateTime createdAt;

  /// 정산 완료 날짜
  final DateTime? completedAt;

  const TravelSettlementModel({
    required this.settlementId,
    required this.travelId,
    required this.totalAmount,
    required this.memberCount,
    required this.perPersonAmount,
    this.remainderAmount = 0,
    required this.memberSummaries,
    required this.transfers,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
  });

  factory TravelSettlementModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw StateError(
        '여행 정산 문서 데이터가 존재하지 않습니다: ${document.id}',
      );
    }

    final List<dynamic> summaryData =
    data['memberSummaries'] is List
        ? data['memberSummaries'] as List<dynamic>
        : <dynamic>[];

    final List<dynamic> transferData =
    data['transfers'] is List
        ? data['transfers'] as List<dynamic>
        : <dynamic>[];

    return TravelSettlementModel(
      settlementId: document.id,
      travelId: _toString(data['travelId']),
      totalAmount: _toInt(data['totalAmount']),
      memberCount: _toInt(data['memberCount']),
      perPersonAmount: _toInt(data['perPersonAmount']),
      remainderAmount: _toInt(data['remainderAmount']),
      memberSummaries: summaryData
          .whereType<Map>()
          .map(
            (Map item) =>
            SettlementMemberSummary.fromMap(
              Map<String, dynamic>.from(item),
            ),
      )
          .toList(),
      transfers: transferData
          .whereType<Map>()
          .map(
            (Map item) =>
            SettlementTransferModel.fromMap(
              Map<String, dynamic>.from(item),
            ),
      )
          .toList(),
      isCompleted: _toBool(data['isCompleted']),
      createdAt: _toDateTime(data['createdAt']),
      completedAt: _toNullableDateTime(
        data['completedAt'],
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'settlementId': settlementId,
      'travelId': travelId.trim(),
      'totalAmount': totalAmount,
      'memberCount': memberCount,
      'perPersonAmount': perPersonAmount,
      'remainderAmount': remainderAmount,
      'memberSummaries': memberSummaries
          .map(
            (SettlementMemberSummary summary) =>
            summary.toMap(),
      )
          .toList(),
      'transfers': transfers
          .map(
            (SettlementTransferModel transfer) =>
            transfer.toMap(),
      )
          .toList(),
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
    };
  }

  TravelSettlementModel copyWith({
    String? settlementId,
    String? travelId,
    int? totalAmount,
    int? memberCount,
    int? perPersonAmount,
    int? remainderAmount,
    List<SettlementMemberSummary>? memberSummaries,
    List<SettlementTransferModel>? transfers,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TravelSettlementModel(
      settlementId:
      settlementId ?? this.settlementId,
      travelId: travelId ?? this.travelId,
      totalAmount: totalAmount ?? this.totalAmount,
      memberCount: memberCount ?? this.memberCount,
      perPersonAmount:
      perPersonAmount ?? this.perPersonAmount,
      remainderAmount:
      remainderAmount ?? this.remainderAmount,
      memberSummaries:
      memberSummaries ?? this.memberSummaries,
      transfers: transfers ?? this.transfers,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt
          ? null
          : completedAt ?? this.completedAt,
    );
  }

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString().replaceAll(',', '').trim() ??
          '',
    ) ??
        0;
  }

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
      return DateTime.fromMillisecondsSinceEpoch(value);
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

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }
}