import '../../models/category_model.dart' show TransactionType;
import '../../models/expense_model.dart' show ExpenseNature;

class ParsedRecordDraft {
  TransactionType type;
  DateTime date;
  String label;
  int amount;
  bool isSelected;

  ExpenseNature? nature;
  String? emotionTag;

  String? categoryId;

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
    String categoryId = 'uncategorized',
  }) {
    return ParsedRecordDraft(
      type: TransactionType.income,
      date: date,
      label: label,
      amount: amount,
      categoryId: categoryId,
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