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

  /// 닉네임 중복 검사
  Future<bool> isNicknameTaken(String nickname, {String? exceptUid}) async {
    final snap =
    await _users.where('nickname', isEqualTo: nickname).limit(2).get();
    return snap.docs.any((d) => d.id != exceptUid);
  }
}