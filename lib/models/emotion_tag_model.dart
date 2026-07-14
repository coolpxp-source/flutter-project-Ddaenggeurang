/// 감정태그 4종 — 변동비(variable) 지출에만 적용 가능
/// label은 화면 표시용, code는 Firestore 저장값
enum EmotionTag {
  impulsive('impulsive', '충동적', '🔥'),
  stress('stress', '스트레스', '😩'),
  social('social', '사회적', '🤝'),
  planned('planned', '계획적', '📝');

  final String code;
  final String label;
  final String emoji;
  const EmotionTag(this.code, this.label, this.emoji);

  static EmotionTag? fromCode(String? code) {
    if (code == null) return null;
    return EmotionTag.values.firstWhere(
          (e) => e.code == code,
      orElse: () => EmotionTag.planned,
    );
  }
}