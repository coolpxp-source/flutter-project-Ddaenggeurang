import '../../models/category_model.dart' show TransactionType;
import '../../models/expense_model.dart' show ExpenseNature;
import '../../models/income_model.dart' show IncomeSource;

/// AI 파싱(텍스트/사진 여러 장)으로 나온 항목 하나를 화면에서 편집 가능하게 담는 임시 그릇.
/// Firestore에 그대로 저장되는 모델이 아니라, "전체 저장" 누르는 순간
/// type에 따라 ExpenseModel/IncomeModel/SavingModel로 변환되어 각자의 서비스로 들어감.
///
/// TODO: 실제 파싱(로컬 AI or OCR)이 붙으면 이 클래스의 인스턴스 리스트를 만들어주는
///       파서 함수로 교체. 지금은 스텁(가짜 데이터)으로 화면/흐름만 완성.
class ParsedRecordDraft {
  TransactionType type;
  DateTime date;
  String label; // 인식된 이름 (예: "스타벅스", "택시")
  int amount;
  bool isSelected;

  // ── expense 전용 ──
  ExpenseNature? nature; // 기본값 variable (퉁치기는 대부분 일상 변동비)
  String? emotionTag;
  String? categoryId; // expense/saving 공통으로 씀 (의미는 타입별로 다름)

  // ── income 전용 ──
  IncomeSource? incomeSource;

  // ── saving 전용 ──
  String? accountName;

  ParsedRecordDraft({
    required this.type,
    required this.date,
    required this.label,
    required this.amount,
    this.isSelected = true,
    this.nature,
    this.emotionTag,
    this.categoryId,
    this.incomeSource,
    this.accountName,
  });

  factory ParsedRecordDraft.expense({
    required DateTime date,
    required String label,
    required int amount,
    String categoryId = 'uncategorized',
  }) {
    return ParsedRecordDraft(
      type: TransactionType.expense,
      date: date,
      label: label,
      amount: amount,
      nature: ExpenseNature.variable,
      categoryId: categoryId,
    );
  }

  factory ParsedRecordDraft.income({
    required DateTime date,
    required String label,
    required int amount,
    IncomeSource incomeSource = IncomeSource.etc,
  }) {
    return ParsedRecordDraft(
      type: TransactionType.income,
      date: date,
      label: label,
      amount: amount,
      incomeSource: incomeSource,
    );
  }

  factory ParsedRecordDraft.saving({
    required DateTime date,
    required String label,
    required int amount,
    String categoryId = 'deposit',
    String? accountName,
  }) {
    return ParsedRecordDraft(
      type: TransactionType.saving,
      date: date,
      label: label,
      amount: amount,
      categoryId: categoryId,
      accountName: accountName,
    );
  }
}