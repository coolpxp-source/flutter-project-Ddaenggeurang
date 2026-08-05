import 'package:flutter_test/flutter_test.dart';
import 'package:ddaenggeurang/models/expense_model.dart';
import 'package:ddaenggeurang/services/ai_service.dart';
import 'package:ddaenggeurang/screens/record/category_matcher.dart';
import 'package:ddaenggeurang/screens/record/draft_mapper.dart';

void main() {
  test('AI type이 "기타"면 nature가 other로 매핑돼야 함', () async {
    final testList = [
      ParsedExpense(
        amount: 5000,
        merchant: '테스트가게',
        memo: '',
        category: '미분류',
        type: '기타', // ← 핵심 케이스
        transactionType: '지출',
      ),
      ParsedExpense(
        amount: 3000,
        merchant: '테스트가게2',
        memo: '',
        category: '미분류',
        type: '고정비',
        transactionType: '지출',
      ),
      ParsedExpense(
        amount: 7000,
        merchant: '테스트가게3',
        memo: '',
        category: '미분류',
        type: '변동비',
        transactionType: '지출',
      ),
    ];

    // 카테고리 목록은 비어있어도 무방 (nature 매핑만 검증하는 게 목적)
    const emptyCategories = AllCategoryOptions(
      expense: [],
      income: [],
      saving: [],
    );

    final drafts = await mapParsedExpensesToDrafts(
      testList,
      categories: emptyCategories,
    );

    expect(drafts.length, 3);
    expect(drafts[0].nature, ExpenseNature.other);    // "기타" → other 확인
    expect(drafts[1].nature, ExpenseNature.fixed);    // "고정비" → fixed 유지 확인
    expect(drafts[2].nature, ExpenseNature.variable); // "변동비" → variable 유지 확인
  });
}