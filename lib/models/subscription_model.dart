import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  final String id;
  final String name;
  final int amount;
  final int paymentDay;
  final bool isActive;
  final DateTime? createdAt;

  const SubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.paymentDay,
    required this.isActive,
    this.createdAt,
  });

  /// Firestore 문서를 SubscriptionModel로 변환
  factory SubscriptionModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? <String, dynamic>{};

    return SubscriptionModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paymentDay: (data['paymentDay'] as num?)?.toInt() ?? 1,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _timestampToDateTime(data['createdAt']),
    );
  }

  /// Map 데이터를 SubscriptionModel로 변환
  factory SubscriptionModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return SubscriptionModel(
      id: id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paymentDay: (data['paymentDay'] as num?)?.toInt() ?? 1,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: _timestampToDateTime(data['createdAt']),
    );
  }

  /// 새 구독 등록 시 사용하는 Map
  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'amount': amount,
      'paymentDay': validPaymentDay,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// 구독 수정 시 사용하는 Map
  ///
  /// 수정할 때 createdAt이 다시 저장되지 않도록 분리했습니다.
  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name.trim(),
      'amount': amount,
      'paymentDay': validPaymentDay,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 결제일을 1~31일 범위로 보정
  int get validPaymentDay {
    return paymentDay.clamp(1, 31);
  }

  /// 오늘 날짜
  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 다음 결제 예정일
  ///
  /// 예:
  /// 오늘이 8월 4일이고 paymentDay가 13이면 8월 13일
  /// 오늘이 8월 20일이고 paymentDay가 13이면 9월 13일
  DateTime get nextPaymentDate {
    final today = _today;

    DateTime paymentDate = _createSafePaymentDate(
      year: today.year,
      month: today.month,
      day: validPaymentDay,
    );

    if (paymentDate.isBefore(today)) {
      final nextMonth = DateTime(today.year, today.month + 1, 1);

      paymentDate = _createSafePaymentDate(
        year: nextMonth.year,
        month: nextMonth.month,
        day: validPaymentDay,
      );
    }

    return paymentDate;
  }

  /// 다음 결제일까지 남은 일수
  ///
  /// 오늘 결제면 0
  /// 내일 결제면 1
  int get daysUntilPayment {
    return nextPaymentDate.difference(_today).inDays;
  }

  /// D-Day 표시
  String get dDayText {
    final days = daysUntilPayment;

    if (days == 0) {
      return 'D-Day';
    }

    return 'D-$days';
  }

  /// 결제 예정 안내 문구
  String get paymentNoticeText {
    final formattedAmount = formatAmount(amount);
    final days = daysUntilPayment;

    if (days == 0) {
      return '오늘 $name $formattedAmount원 결제 예정';
    }

    if (days == 1) {
      return '내일 $name $formattedAmount원 결제 예정';
    }

    return '$days일 후 $name $formattedAmount원 결제 예정';
  }

  /// 하루 전 알림 문구
  String get oneDayBeforeNotificationText {
    return '내일 $name ${formatAmount(amount)}원이 결제될 예정이에요.';
  }

  /// 금액에 천 단위 쉼표 추가
  static String formatAmount(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  SubscriptionModel copyWith({
    String? id,
    String? name,
    int? amount,
    int? paymentDay,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paymentDay: paymentDay ?? this.paymentDay,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 해당 월에 존재하지 않는 날짜를 월의 마지막 날로 처리
  ///
  /// 예: 2월 31일 → 2월 28일 또는 29일
  static DateTime _createSafePaymentDate({
    required int year,
    required int month,
    required int day,
  }) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final safeDay = day.clamp(1, lastDayOfMonth);

    return DateTime(year, month, safeDay);
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  @override
  String toString() {
    return 'SubscriptionModel('
        'id: $id, '
        'name: $name, '
        'amount: $amount, '
        'paymentDay: $paymentDay, '
        'isActive: $isActive, '
        'createdAt: $createdAt'
        ')';
  }
}