/// 이 거래(지출/수입/저축)가 셋 중 어디에 속하는지
///
/// 원래 category_model.dart 안에 있었지만, CategoryModel/CategoryService는
/// 실제로 쓰이는 곳이 없어서 삭제하고 이 enum만 별도 파일로 분리했다.
/// (draft_review_screen.dart, parsed_record_draft.dart에서 계속 사용 중)
enum TransactionType {
  income('income', '수입'),
  expense('expense', '지출'),
  saving('saving', '저축/투자');

  final String code;
  final String label;
  const TransactionType(this.code, this.label);

  static TransactionType fromCode(String? code) => TransactionType.values.firstWhere(
        (e) => e.code == code,
    orElse: () => TransactionType.expense,
  );
}