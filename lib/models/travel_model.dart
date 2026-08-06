import 'package:cloud_firestore/cloud_firestore.dart';

class TravelModel {
  /// 생성자 UID
  final String userId;

  final String travelId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int? budgetAmount;
  final bool isActive;

  /// 초대를 수락한 회원 UID 목록
  ///
  /// 여행 생성자 userId도 포함한다.
  final List<String> memberIds;

  /// 아직 초대를 수락하지 않은 회원 UID 목록
  final List<String> pendingMemberIds;

  /// 생성자를 포함한 최대 여행 인원
  final int maxMembers;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TravelModel({
    required this.travelId,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.budgetAmount,
    this.isActive = true,
    this.memberIds = const [],
    this.pendingMemberIds = const [],
    this.maxMembers = 8,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// 여행 생성자인지 확인
  bool isOwner(String targetUserId) {
    return userId == targetUserId;
  }

  /// 초대를 수락한 여행 참여자인지 확인
  bool isMember(String targetUserId) {
    return memberIds.contains(targetUserId);
  }

  /// 여행 생성자 또는 참여자인지 확인
  bool isParticipant(String targetUserId) {
    return isOwner(targetUserId) || isMember(targetUserId);
  }

  /// 해당 회원이 초대 대기 중인지 확인
  bool isPendingMember(String targetUserId) {
    return pendingMemberIds.contains(targetUserId);
  }

  /// 지출 입력 권한 확인
  ///
  /// 여행 생성자와 초대를 수락한 참여자만 입력할 수 있다.
  bool canWriteExpense(String targetUserId) {
    return !isDeleted && isParticipant(targetUserId);
  }

  /// 여행 및 정산 내용 조회 권한 확인
  bool canViewSettlement(String targetUserId) {
    return !isDeleted && isParticipant(targetUserId);
  }

  /// 현재 참여 인원
  int get memberCount {
    final members = <String>{
      userId,
      ...memberIds,
    };

    members.removeWhere((id) => id.trim().isEmpty);
    return members.length;
  }

  /// 초대 대기 인원까지 포함한 전체 인원
  int get totalReservedMemberCount {
    final members = <String>{
      userId,
      ...memberIds,
      ...pendingMemberIds,
    };

    members.removeWhere((id) => id.trim().isEmpty);
    return members.length;
  }

  /// 새로운 회원을 초대할 수 있는지 확인
  bool get canInviteMember {
    return totalReservedMemberCount < maxMembers;
  }

  /// 해당 지출을 현재 여행의 지출로 자동 태깅할 수 있는지 판단
  bool shouldAutoTag({
    required DateTime expenseDate,
    required bool isFixedNature,
    required bool hasInstallmentPlan,
    required bool hasRecurringPayment,
  }) {
    if (!isActive || isDeleted) {
      return false;
    }

    final expenseDay = DateTime(
      expenseDate.year,
      expenseDate.month,
      expenseDate.day,
    );

    final travelStartDay = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final travelEndDay = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    final isOutsideTravelPeriod =
        expenseDay.isBefore(travelStartDay) ||
            expenseDay.isAfter(travelEndDay);

    if (isOutsideTravelPeriod) {
      return false;
    }

    if (isFixedNature ||
        hasInstallmentPlan ||
        hasRecurringPayment) {
      return false;
    }

    return true;
  }

  factory TravelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();

    if (data == null || data is! Map<String, dynamic>) {
      throw StateError(
        '여행 문서 데이터가 존재하지 않습니다: ${doc.id}',
      );
    }

    final userId = data['userId'] as String? ?? '';

    final savedMemberIds = List<String>.from(
      data['memberIds'] as List<dynamic>? ?? const [],
    );

    /*
     * 기존 여행 문서에는 memberIds가 없을 수 있으므로
     * 생성자 UID를 자동으로 참여자 목록에 포함한다.
     */
    final memberIds = <String>{
      userId,
      ...savedMemberIds,
    }.where((id) => id.trim().isNotEmpty).toList();

    return TravelModel(
      travelId: doc.id,
      userId: userId,
      title: data['title'] as String? ?? '',
      startDate:
      (data['startDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      endDate:
      (data['endDate'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      budgetAmount:
      (data['budgetAmount'] as num?)?.toInt(),
      isActive: data['isActive'] as bool? ?? true,
      memberIds: memberIds,
      pendingMemberIds: List<String>.from(
        data['pendingMemberIds'] as List<dynamic>? ??
            const [],
      ),
      maxMembers:
      (data['maxMembers'] as num?)?.toInt() ?? 8,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt:
      (data['deletedAt'] as Timestamp?)?.toDate(),
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt:
      (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    final normalizedMemberIds = <String>{
      userId,
      ...memberIds,
    }.where((id) => id.trim().isNotEmpty).toList();

    return {
      'travelId': travelId,
      'userId': userId,
      'title': title.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budgetAmount': budgetAmount,
      'isActive': isActive,
      'memberIds': normalizedMemberIds,
      'pendingMemberIds': pendingMemberIds,
      'maxMembers': maxMembers,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null
          ? Timestamp.fromDate(deletedAt!)
          : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  TravelModel copyWith({
    String? userId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    int? budgetAmount,
    bool? isActive,
    List<String>? memberIds,
    List<String>? pendingMemberIds,
    int? maxMembers,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? updatedAt,
  }) {
    return TravelModel(
      travelId: travelId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      isActive: isActive ?? this.isActive,
      memberIds: memberIds ?? this.memberIds,
      pendingMemberIds:
      pendingMemberIds ?? this.pendingMemberIds,
      maxMembers: maxMembers ?? this.maxMembers,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}