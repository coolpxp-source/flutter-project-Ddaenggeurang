import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_summary_model.dart';
import '../models/spending_challenge_model.dart';
import 'category_summary_service.dart';
import 'user_service.dart';

/// 매달 "지난달 대비 가장 많이 늘어난 카테고리"를 골라 절약 챌린지를 만든다.
/// category_summary_service.dart(임예림 소유)는 공개 메서드만 호출하고,
/// 챌린지 상태는 users/{uid}/spendingChallenges 서브컬렉션(김은동 소유)에 저장한다.
class SpendingChallengeService {
  final _firestore = FirebaseFirestore.instance;
  static const _defaultReward = 50;

  CollectionReference<Map<String, dynamic>> _challenges(String uid) =>
      _firestore.collection('users').doc(uid).collection('spendingChallenges');

  String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  int _amountFor(List<CategorySummaryModel> summary, String categoryKey) {
    for (final s in summary) {
      if (s.categoryKey == categoryKey) return s.totalAmount;
    }
    return 0;
  }

  /// 이번 달 챌린지를 반환한다. 없으면 지난달 챌린지를 먼저 정산(성공 시 포인트 지급)하고
  /// 이번 달 새 챌린지를 만든다. 비교할 지출 이력이 전혀 없으면 null을 반환한다.
  Future<SpendingChallengeModel?> getOrCreateCurrentChallenge(String uid) async {
    final now = DateTime.now();
    final thisMonthKey = _monthKey(now);

    final existing = await _challenges(uid).doc(thisMonthKey).get();
    if (existing.exists) {
      return SpendingChallengeModel.fromMap(thisMonthKey, existing.data()!);
    }

    await _settlePreviousChallenge(uid, now);
    return _createChallenge(uid, now);
  }

  Future<void> _settlePreviousChallenge(String uid, DateTime now) async {
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final lastMonthKey = _monthKey(lastMonthDate);
    final lastDoc = await _challenges(uid).doc(lastMonthKey).get();
    if (!lastDoc.exists) return;

    final last = SpendingChallengeModel.fromMap(lastMonthKey, lastDoc.data()!);
    if (last.status != 'in_progress') return;

    final finalSummary = await CategorySummaryService().getCategorySummary(
        userId: uid, year: lastMonthDate.year, month: lastMonthDate.month);
    final finalAmount = _amountFor(finalSummary, last.categoryKey);
    final success = finalAmount <= last.targetAmount;

    await _challenges(uid).doc(lastMonthKey).update({'status': success ? 'success' : 'failed'});
    if (success) {
      await UserService().addPoints(uid, last.pointsReward);
    }
  }

  Future<SpendingChallengeModel?> _createChallenge(String uid, DateTime now) async {
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final twoMonthsAgoDate = DateTime(now.year, now.month - 2, 1);

    final lastMonthSummary = await CategorySummaryService()
        .getCategorySummary(userId: uid, year: lastMonthDate.year, month: lastMonthDate.month);
    if (lastMonthSummary.isEmpty) return null;

    final twoMonthsAgoSummary = await CategorySummaryService().getCategorySummary(
        userId: uid, year: twoMonthsAgoDate.year, month: twoMonthsAgoDate.month);

    CategorySummaryModel? target;
    int bestGrowth = -1 << 30;
    for (final s in lastMonthSummary) {
      final prior = _amountFor(twoMonthsAgoSummary, s.categoryKey);
      final growth = s.totalAmount - prior;
      if (growth > bestGrowth) {
        bestGrowth = growth;
        target = s;
      }
    }
    if (target == null) return null;

    final challenge = SpendingChallengeModel(
      month: _monthKey(now),
      categoryKey: target.categoryKey,
      categoryName: target.categoryName,
      targetAmount: (target.totalAmount * 0.8).round(),
      previousAmount: target.totalAmount,
      status: 'in_progress',
      pointsReward: _defaultReward,
    );

    await _challenges(uid).doc(challenge.month).set(challenge.toMap());
    return challenge;
  }

  /// 이번 달 진행 중인 카테고리 지출을 실시간으로 조회한다(진행률 표시용).
  Future<int> getCurrentSpend(String uid, String categoryKey) async {
    final now = DateTime.now();
    final summary = await CategorySummaryService()
        .getCategorySummary(userId: uid, year: now.year, month: now.month);
    return _amountFor(summary, categoryKey);
  }
}
