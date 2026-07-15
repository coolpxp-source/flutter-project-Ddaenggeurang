class CategorySummaryModel {
  // Firestore에 저장된 카테고리 키
  // food, transport, shopping 등
  final String categoryKey;

  // 화면에 표시할 카테고리 이름
  // 식비, 교통, 쇼핑 등
  final String categoryName;

  // 해당 카테고리의 총지출 금액
  final int totalAmount;

  // 전체 지출에서 해당 카테고리가 차지하는 비율
  final double percentage;

  const CategorySummaryModel({
    required this.categoryKey,
    required this.categoryName,
    required this.totalAmount,
    required this.percentage,
  });

  CategorySummaryModel copyWith({
    String? categoryKey,
    String? categoryName,
    int? totalAmount,
    double? percentage,
  }) {
    return CategorySummaryModel(
      categoryKey: categoryKey ?? this.categoryKey,
      categoryName: categoryName ?? this.categoryName,
      totalAmount: totalAmount ?? this.totalAmount,
      percentage: percentage ?? this.percentage,
    );
  }
}