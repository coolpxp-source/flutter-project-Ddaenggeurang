import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_stat_model.dart';

class CommunityService {
  final _db = FirebaseFirestore.instance;

  // 랭킹 (저축률 높은 순, 상위 N개)
  Stream<List<CommunityStat>> getRanking({int limit = 50}) {
    return _db
        .collection('communityStats')
        .orderBy('savingRate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => CommunityStat.fromFirestore(d)).toList());
  }

  // 또래 비교: 같은 ageGroup+job 그룹 평균 저축률
  Future<double> getPeerAverageSavingRate({
    required String ageGroup,
    required String job,
  }) async {
    final snap = await _db
        .collection('communityStats')
        .where('ageGroup', isEqualTo: ageGroup)
        .where('job', isEqualTo: job)
        .get();

    if (snap.docs.isEmpty) return 0;
    final total = snap.docs.fold<num>(
      0,
          (sum, d) => sum + (d['savingRate'] ?? 0),
    );
    return total / snap.docs.length;
  }

  // 내 저축 비율 공유/갱신 (61_저축비율공유)
  Future<void> updateMyStat(String userId, CommunityStat stat) async {
    await _db.collection('communityStats').doc(userId).set(stat.toMap());
  }
}