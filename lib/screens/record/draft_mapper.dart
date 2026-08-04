import '../../models/expense_model.dart';
import '../../services/ai_service.dart';
import 'category_matcher.dart';
import 'parsed_record_draft.dart';

/// AiService.parseBulkText()가 반환하는 List<ParsedExpense>를
/// 화면에서 쓰는 List<ParsedRecordDraft>로 변환합니다.
///
/// 영수증 촬영(receipt_upload_screen) / 문자내역 붙여넣기(sms_paste_screen) /
/// 직접 입력(bulk_record_screen) 세 화면이 모두 이 함수를 공유해요.
/// (텍스트가 어디서 왔는지만 다를 뿐, 파싱 이후 로직은 완전히 동일하기 때문)
///
/// ⚠️ Firestore에서 실제 카테고리를 불러와 AI가 자유 텍스트로 뱉은
/// 카테고리("카페비" 등)를 진짜 categoryId로 매칭하기 때문에 비동기(Future)임.
/// 호출부에서 await 필요.
Future<List<ParsedRecordDraft>> mapParsedExpensesToDrafts(
    List<ParsedExpense> parsedList, {
      required AllCategoryOptions categories,
    }) async {
  final DateTime now = DateTime.now();
  final expenseOptions = categories.expense;
  final incomeOptions = categories.income;
  final savingOptions = categories.saving;

  String matchedName(List<CategoryOption> options, String? matchedId) {
    if (matchedId == null) return '미분류';
    final List<CategoryOption> found =
    options.where((CategoryOption o) => o.id == matchedId).toList();
    return found.isNotEmpty ? found.first.name : '미분류';
  }

  /// 화면에 보여줄 메모: 구매 내역(memo)이 있으면 그걸 우선 쓰고,
  /// 없으면 상호명(merchant)을 대신 보여준다.
  /// (예: "GS25 · 맥주"처럼 상호명과 내용이 겹치지 않게)
  String displayMemo(ParsedExpense item) {
    return item.memo.isNotEmpty ? item.memo : item.merchant;
  }

  /// 카테고리 매칭에는 상호명과 구매 내역을 같이 넣어서 힌트를 최대한 활용한다.
  /// (예: 상호명이 "편의점"처럼 뭉뚱그려져 있어도 memo에 "커피"가 있으면 도움됨)
  String matchText(ParsedExpense item) {
    return item.memo.isEmpty ? item.merchant : '${item.merchant} ${item.memo}';
  }

  return parsedList.map((ParsedExpense item) {
    DateTime itemDate = now;
    if (item.date != null && item.date!.isNotEmpty) {
      try {
        itemDate = DateTime.parse(item.date!);
      } catch (_) {}
    }

    if (item.transactionType == '수입') {
      final String? matchedId = matchCategoryId(
        aiCategoryText: item.category,
        merchant: matchText(item),
        options: incomeOptions,
      );
      return ParsedRecordDraft.income(
        date: itemDate,
        memo: displayMemo(item),
        categoryName: matchedName(incomeOptions, matchedId),
        amount: item.amount,
        categoryId: matchedId ?? 'uncategorized',
      );
    } else if (item.transactionType == '저축') {
      final String? matchedId = matchCategoryId(
        aiCategoryText: item.category,
        merchant: matchText(item),
        options: savingOptions,
      );
      return ParsedRecordDraft.saving(
        date: itemDate,
        memo: displayMemo(item),
        categoryName: matchedName(savingOptions, matchedId),
        amount: item.amount,
        categoryId: matchedId ?? 'deposit',
      );
    } else {
      final String? matchedId = matchCategoryId(
        aiCategoryText: item.category,
        merchant: matchText(item),
        options: expenseOptions,
      );
      return ParsedRecordDraft.expense(
        date: itemDate,
        memo: displayMemo(item),
        categoryName: matchedName(expenseOptions, matchedId),
        amount: item.amount,
        categoryId: matchedId ?? 'uncategorized',
        nature: item.type == '고정비' ? ExpenseNature.fixed : ExpenseNature.variable,
      );
    }
  }).toList();
}