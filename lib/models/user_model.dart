import 'package:cloud_firestore/cloud_firestore.dart';
import 'coach_tone.dart';

class NotificationSettings {
  final bool fixedExpenseAlert;
  final bool subscriptionAlert;
  final bool cardPointExpiryAlert;

  const NotificationSettings({
    this.fixedExpenseAlert = true,
    this.subscriptionAlert = true,
    this.cardPointExpiryAlert = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic>? m) =>
      NotificationSettings(
        fixedExpenseAlert: m?['fixedExpenseAlert'] ?? true,
        subscriptionAlert: m?['subscriptionAlert'] ?? true,
        cardPointExpiryAlert: m?['cardPointExpiryAlert'] ?? true,
      );

  Map<String, dynamic> toMap() => {
    'fixedExpenseAlert': fixedExpenseAlert,
    'subscriptionAlert': subscriptionAlert,
    'cardPointExpiryAlert': cardPointExpiryAlert,
  };

  NotificationSettings copyWith({
    bool? fixedExpenseAlert,
    bool? subscriptionAlert,
    bool? cardPointExpiryAlert,
  }) =>
      NotificationSettings(
        fixedExpenseAlert: fixedExpenseAlert ?? this.fixedExpenseAlert,
        subscriptionAlert: subscriptionAlert ?? this.subscriptionAlert,
        cardPointExpiryAlert: cardPointExpiryAlert ?? this.cardPointExpiryAlert,
      );
}

class UserModel {
  final String userId;
  final String nickname;
  final String email;
  final String authProvider;   // google | kakao | naver | apple
  final int salary;            // 월 수입
  final String ageGroup;       // "20대"
  final String job;
  final int points;
  final int level;
  final Map<String, String?> equippedItems;
  final CoachTone coachTone;   // nagCharacterStyle
  final NotificationSettings notificationSettings;
  final String? lastLoginDate; // "yyyy-MM-dd" — 연속 접속 스트릭 계산용
  final int loginStreak;
  final int coachAffection; // AI상담 이용할 때마다 쌓이는 코치와의 친밀도
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.userId,
    required this.nickname,
    required this.email,
    this.authProvider = 'google',
    this.salary = 0,
    this.ageGroup = '',
    this.job = '',
    this.points = 0,
    this.level = 1,
    this.equippedItems = const {
      'hat': null, 'clothes': null, 'shoes': null, 'accessory': null,
    },
    this.coachTone = CoachTone.ddaengjwi,
    this.notificationSettings = const NotificationSettings(),
    this.lastLoginDate,
    this.loginStreak = 0,
    this.coachAffection = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      userId: doc.id,
      nickname: d['nickname'] ?? '',
      email: d['email'] ?? '',
      authProvider: d['authProvider'] ?? 'google',
      salary: (d['salary'] ?? 0).toInt(),
      ageGroup: d['ageGroup'] ?? '',
      job: d['job'] ?? '',
      points: (d['points'] ?? 0).toInt(),
      level: (d['level'] ?? 1).toInt(),
      equippedItems: Map<String, String?>.from(
          d['equippedItems'] ?? const {'hat': null, 'clothes': null, 'shoes': null, 'accessory': null}),
      coachTone: CoachTone.fromCode(d['nagCharacterStyle']),
      notificationSettings:
      NotificationSettings.fromMap(d['notificationSettings']),
      lastLoginDate: d['lastLoginDate'] as String?,
      loginStreak: (d['loginStreak'] ?? 0).toInt(),
      coachAffection: (d['coachAffection'] ?? 0).toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nickname': nickname,
    'email': email,
    'authProvider': authProvider,
    'salary': salary,
    'ageGroup': ageGroup,
    'job': job,
    'points': points,
    'level': level,
    'equippedItems': equippedItems,
    'nagCharacterStyle': coachTone.code,
    'notificationSettings': notificationSettings.toMap(),
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}