class EmotionSummaryModel {
  final String emotionKey;
  final String emotionName;
  final int totalAmount;
  final double percentage;

  const EmotionSummaryModel({
    required this.emotionKey,
    required this.emotionName,
    required this.totalAmount,
    required this.percentage,
  });
}