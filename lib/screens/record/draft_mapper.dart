import '../../models/expense_model.dart';
import '../../services/ai_service.dart';
import 'parsed_record_draft.dart';

/// AiService.parseBulkText()가 반환하는 List<ParsedExpense>를
/// 화면에서 쓰는 List<ParsedRecordDraft>로 변환합니다.
///
/// 영수증 촬영(receipt_upload_screen) / 문자내역 붙여넣기(sms_paste_screen) /
/// 직접 입력(bulk_record_screen) 세 화면이 모두 이 함수를 공유해요.
/// (텍스트가 어디서 왔는지만 다를 뿐, 파싱 이후 로직은 완전히 동일하기 때문)
List<ParsedRecordDraft> mapParsedExpensesToDrafts(List<ParsedExpense> parsedList) {
  final now = DateTime.now();

  return parsedList.map((item) {
    DateTime itemDate = now;
    if (item.date != null && item.date!.isNotEmpty) {
      try {
        itemDate = DateTime.parse(item.date!);
      } catch (_) {}
    }

    if (item.transactionType == '수입') {
      return ParsedRecordDraft.income(
        date: itemDate,
        memo: item.merchant,
        categoryName: item.category,
        amount: item.amount,
        categoryId: 'etc',
      );
    } else if (item.transactionType == '저축') {
      return ParsedRecordDraft.saving(
        date: itemDate,
        memo: item.merchant,
        categoryName: item.category,
        amount: item.amount,
        categoryId: 'deposit',
      );
    } else {
      return ParsedRecordDraft.expense(
        date: itemDate,
        memo: item.merchant,
        categoryName: item.category,
        amount: item.amount,
        nature: item.type == '고정비' ? ExpenseNature.fixed : ExpenseNature.variable,
      );
    }
  }).toList();
}