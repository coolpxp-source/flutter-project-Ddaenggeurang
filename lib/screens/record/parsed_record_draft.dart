import '../../models/transaction_type.dart';
import '../../models/expense_model.dart' show ExpenseNature;

class ParsedRecordDraft {
  TransactionType type;
  DateTime date;

  // 💡 기존의 label 대신 memo와 categoryName이 들어옵니다.
  String memo;
  String categoryName;

  int amount;
  bool isSelected;

  ExpenseNature? nature;
  String? emotionTag;
  String? categoryId;
  String? accountName;

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
  });

  factory ParsedRecordDraft.expense({
    required DateTime date,
    required String memo,          // 💡 label 대신 memo 받기
    required String categoryName,  // 💡 categoryName 받기
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