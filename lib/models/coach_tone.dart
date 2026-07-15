/// 땡코치 3인방 — label은 학습 모델의 프롬프트 태그와 정확히 일치해야 함
enum CoachTone {
  ddaenggu('땡구', '🐶', '착한 잔소리', '다정하게 다독여주는 응원가', 'assets/images/dog.png'),
  ddaengjwi('땡쥐', '🐭', '현실적인 조언', '데이터로 뼈를 때리는 현실파', 'assets/images/mouse.png'),
  ddaengnyang('땡냥이', '🐱', '매운맛 독설', '츤데레 독설가, 칭찬도 툴툴', 'assets/images/cat.png');

  final String label;
  final String emoji;
  final String title;
  final String desc;

  /// 코치 캐릭터 아바타 이미지 (assets/images) — 이모지 대신 실제 캐릭터 그림을 보여줄 때 사용.
  final String imagePath;
  const CoachTone(this.label, this.emoji, this.title, this.desc, this.imagePath);

  /// Firestore 저장용 코드값 (ddaenggu | ddaengjwi | ddaengnyang)
  String get code => name;

  static CoachTone fromCode(String? code) => CoachTone.values.firstWhere(
        (t) => t.name == code,
    orElse: () => CoachTone.ddaengjwi,
  );
}