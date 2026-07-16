/// 매달 자동으로 생성되는 카테고리 절약 챌린지.
/// users/{uid}/spendingChallenges/{yyyy-MM} 문서 하나가 그 달의 챌린지 하나에 대응한다.
class SpendingChallengeModel {
  final String month; // yyyy-MM
  final String categoryKey;
  final String categoryName;
  final int targetAmount; // 이 금액 이하로 쓰면 성공
  final int previousAmount; // 목표 산정 기준이 된 전월 지출액
  final String status; // in_progress / success / failed
  final int pointsReward;

  const SpendingChallengeModel({
    required this.month,
    required this.categoryKey,
    required this.categoryName,
    required this.targetAmount,
    required this.previousAmount,
    required this.status,
    required this.pointsReward,
  });

  factory SpendingChallengeModel.fromMap(String month, Map<String, dynamic> data) {
    return SpendingChallengeModel(
      month: month,
      categoryKey: data['categoryKey'] as String? ?? '',
      categoryName: data['categoryName'] as String? ?? '',
      targetAmount: (data['targetAmount'] as num?)?.toInt() ?? 0,
      previousAmount: (data['previousAmount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'in_progress',
      pointsReward: (data['pointsReward'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryKey': categoryKey,
      'categoryName': categoryName,
      'targetAmount': targetAmount,
      'previousAmount': previousAmount,
      'status': status,
      'pointsReward': pointsReward,
    };
  }

  SpendingChallengeModel copyWith({String? status}) {
    return SpendingChallengeModel(
      month: month,
      categoryKey: categoryKey,
      categoryName: categoryName,
      targetAmount: targetAmount,
      previousAmount: previousAmount,
      status: status ?? this.status,
      pointsReward: pointsReward,
    );
  }
}
