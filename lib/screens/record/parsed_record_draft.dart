import '../../models/transaction_type.dart';
import '../../models/expense_model.dart' show ExpenseNature;

class ParsedRecordDraft {
  TransactionType type;
  DateTime date;

  String memo;
  String categoryName;

  int amount;
  bool isSelected;

  ExpenseNature? nature;
  String? emotionTag;
  String? categoryId;
  String? accountName;

  /// 정기결제(지출) / 정기수입(수입)로 등록할지 여부.
  /// true면 저장 시 RecurringPaymentModel(지출) 또는
  /// RecurringIncomeTemplate(수입)을 함께 생성한다.
  bool isRecurring;

  /// 정기결제 주기 — 지출이고 isRecurring일 때만 의미 있음. 'monthly' | 'yearly'
  String? billingCycle;

  /// 정기수입 매월 입금일 — 수입이고 isRecurring일 때만 의미 있음
  int? recurringPayDay;

  ParsedRecordDraft({
    required this.type,
    required this.date,
    required this.memo,
    required this.categoryName,
    required this.amount,
    this.isSelected = true,
    this.nature,
    this.emotionTag,
    this.categoryId,
    this.accountName,
    this.isRecurring = false,
    this.billingCycle,
    this.recurringPayDay,
  });

  factory ParsedRecordDraft.expense({
    required DateTime date,
    required String memo,
    required String categoryName,
    required int amount,
    String categoryId = 'uncategorized',
    required ExpenseNature nature,
  }) {
    return ParsedRecordDraft(
      type: TransactionType.expense,
      date: date,
      memo: memo,
      categoryName: categoryName,
      amount: amount,
      nature: nature,
      categoryId: categoryId,
    );
  }

  factory ParsedRecordDraft.income({
    required DateTime date,
    required String memo,
    required String categoryName,
    required int amount,
    String categoryId = 'uncategorized',
  }) {
    return ParsedRecordDraft(
      type: TransactionType.income,
      date: date,
      memo: memo,
      categoryName: categoryName,
      amount: amount,
      categoryId: categoryId,
    );
  }

  factory ParsedRecordDraft.saving({
    required DateTime date,
    required String memo,
    required String categoryName,
    required int amount,
    String categoryId = 'deposit',
    String? accountName,
  }) {
    return ParsedRecordDraft(
      type: TransactionType.saving,
      date: date,
      memo: memo,
      categoryName: categoryName,
      amount: amount,
      categoryId: categoryId,
      accountName: accountName,
    );
  }
}