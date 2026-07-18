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

  /// 전체 접속 날짜 목록("yyyy-MM-dd" 집합)을 실시간으로 구독한다.
  /// 사용자 한 명당 최대 하루 1건이라 1년치도 365개 안팎이라 기간 필터 없이
  /// 통째로 가져와도 부담 없다 — 화면에서 월 단위로 걸러서 보여준다.
  Stream<Set<String>> watchActiveDates(String uid) {
    return _col(uid).snapshots().map((snap) => snap.docs.map((d) => d.id).toSet());
  }
}
