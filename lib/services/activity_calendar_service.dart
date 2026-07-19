import 'package:cloud_firestore/cloud_firestore.dart';

/// 날짜별 접속 기록 — users/{uid}/activityDays 서브컬렉션.
/// 문서 id를 "yyyy-MM-dd"로 써서 같은 날 여러 번 호출돼도 항상 같은 문서에
/// merge되므로 하루에 1건만 남는다. 마이페이지 접속 히트맵 캘린더에서 쓴다.
class ActivityCalendarService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('activityDays');

  Future<void> markActive(String uid, String date) {
    return _col(uid).doc(date).set({'date': date}, SetOptions(merge: true));
  }

  /// 이 기능(접속 캘린더)을 배포하기 전부터 쌓여 있던 users.loginStreak은
  /// 실제 연속 접속 일수를 정확히 알고 있는데, activityDays는 배포 시점부터만
  /// 기록되기 시작해서 화면에 뜨는 두 숫자가 서로 안 맞는 문제가 있었다.
  /// lastLoginDate에서 loginStreak일만큼 거꾸로 날짜를 역산해서 한 번만
  /// 채워 넣어 두 값을 일치시킨다(스트릭은 하루도 안 끊긴 연속 기록이라
  /// "최근 날짜부터 스트릭 일수만큼"이 곧 실제 접속한 날짜들과 같다).
  Future<void> backfillFromStreak(
    String uid, {
    required String lastLoginDate,
    required int loginStreak,
  }) async {
    if (loginStreak <= 0) return;
    final lastDate = DateTime.parse(lastLoginDate);
    final batch = _db.batch();
    for (int i = 0; i < loginStreak; i++) {
      final d = lastDate.subtract(Duration(days: i));
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      batch.set(_col(uid).doc(key), {'date': key}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// 전체 접속 날짜 목록("yyyy-MM-dd" 집합)을 실시간으로 구독한다.
  /// 사용자 한 명당 최대 하루 1건이라 1년치도 365개 안팎이라 기간 필터 없이
  /// 통째로 가져와도 부담 없다 — 화면에서 월 단위로 걸러서 보여준다.
  Stream<Set<String>> watchActiveDates(String uid) {
    return _col(uid).snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());
  }
}
