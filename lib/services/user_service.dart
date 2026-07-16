import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/coach_tone.dart';

class UserService {
  final _users = FirebaseFirestore.instance.collection('users');

  /// 신규 가입자인지 판별 (users 문서 존재 여부)
  Future<bool> isNewUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return !doc.exists;
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  /// 실시간 구독 (마이페이지/홈에서 사용)
  Stream<UserModel?> watchUser(String uid) => _users.doc(uid).snapshots().map(
          (doc) => doc.exists ? UserModel.fromFirestore(doc) : null);

  /// 회원 문서 생성 (04_회원가입_추가정보)
  Future<void> createUser(UserModel user) async {
    await _users.doc(user.userId).set(user.toFirestore());
  }

  Future<void> updateProfile(
      String uid, {
        String? nickname,
        int? salary,
        String? ageGroup,
        String? job,
      }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (nickname != null) data['nickname'] = nickname;
    if (salary != null) data['salary'] = salary;
    if (ageGroup != null) data['ageGroup'] = ageGroup;
    if (job != null) data['job'] = job;
    await _users.doc(uid).update(data);
  }

  /// 113_잔소리캐릭터설정
  Future<void> updateCoachTone(String uid, CoachTone tone) async {
    await _users.doc(uid).update({
      'nagCharacterStyle': tone.code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 112_알림설정
  Future<void> updateNotificationSettings(
      String uid, NotificationSettings s) async {
    await _users.doc(uid).update({
      'notificationSettings': s.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 연속 접속 스트릭 갱신 — 오늘 이미 접속 처리됐으면 아무 것도 하지 않는다.
  /// 어제 접속한 상태로 오늘 다시 열면 스트릭 +1, 하루 이상 건너뛰었으면 1로 리셋.
  Future<void> touchLoginStreak(String uid, UserModel current) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (current.lastLoginDate == today) return;

    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final newStreak =
    current.lastLoginDate == yesterday ? current.loginStreak + 1 : 1;

    await _users.doc(uid).update({
      'lastLoginDate': today,
      'loginStreak': newStreak,
    });
  }

  /// 닉네임 중복 검사
  Future<bool> isNicknameTaken(String nickname, {String? exceptUid}) async {
    final snap =
    await _users.where('nickname', isEqualTo: nickname).limit(2).get();
    return snap.docs.any((d) => d.id != exceptUid);
  }

  /// 포인트 100당 레벨 1 — 아바타 상점의 AvatarItemModel.unlockLevel(레벨 기반
  /// 잠금)이 이미 있는데 레벨을 올려주는 로직이 어디에도 없어서, 포인트가 쌓여도
  /// Lv.2 이상 요구 아이템은 영원히 잠긴 채였다. 여기서 포인트와 함께 계산해서 저장한다.
  int _levelForPoints(int points) => 1 + (points ~/ 100);

  /// 포인트 지급(미션 보상 등) — 현재 값을 읽어서 더하는 트랜잭션이라
  /// 동시에 여러 보상이 들어와도 유실되지 않는다. 레벨도 함께 갱신한다.
  Future<void> addPoints(String uid, int amount) async {
    if (amount == 0) return;
    final ref = _users.doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      final currentPoints = (snap.data()?['points'] as num?)?.toInt() ?? 0;
      final newPoints = currentPoints + amount;
      transaction.update(ref, {
        'points': newPoints,
        'level': _levelForPoints(newPoints),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}