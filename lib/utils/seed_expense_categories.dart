import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../services/category_service.dart';

/// 기본 지출 카테고리(고정비/변동비/기타)를 categories 컬렉션에 채워 넣는 함수.
///
/// ⚠️ 딱 한 번만 실행해야 함 — 여러 번 실행하면 같은 카테고리가 중복으로 쌓임.
Future<void> seedExpenseCategories() async {
  final service = CategoryService();

  final categories = <Map<String, dynamic>>[
    // ----------------------------------------
    // 📌 고정비 (Fixed)
    // ----------------------------------------
    // 1. 주거비
    {'name': '월세', 'parent': '주거비', 'nature': ExpenseNature.fixed},
    {'name': '관리비', 'parent': '주거비', 'nature': ExpenseNature.fixed},
    {'name': '공과금', 'parent': '주거비', 'nature': ExpenseNature.fixed},

    // 2. 통신비
    {'name': '휴대폰요금', 'parent': '통신비', 'nature': ExpenseNature.fixed},
    {'name': '인터넷', 'parent': '통신비', 'nature': ExpenseNature.fixed},

    // 3. 금융/보험
    {'name': '대출이자', 'parent': '금융/보험', 'nature': ExpenseNature.fixed},
    {'name': '보험료', 'parent': '금융/보험', 'nature': ExpenseNature.fixed},

    // 4. 정기구독
    {'name': 'OTT', 'parent': '정기구독', 'nature': ExpenseNature.fixed},
    {'name': '음원스트리밍', 'parent': '정기구독', 'nature': ExpenseNature.fixed},
    {'name': '정기후원', 'parent': '정기구독', 'nature': ExpenseNature.fixed},

    // ----------------------------------------
    // 📌 변동비 (Variable)
    // ----------------------------------------
    // 5. 식비
    {'name': '식사', 'parent': '식비', 'nature': ExpenseNature.variable},
    {'name': '카페/디저트', 'parent': '식비', 'nature': ExpenseNature.variable},
    {'name': '마트/장보기', 'parent': '식비', 'nature': ExpenseNature.variable},
    {'name': '편의점', 'parent': '식비', 'nature': ExpenseNature.variable},

    // 6. 교통/차량
    {'name': '대중교통', 'parent': '교통/차량', 'nature': ExpenseNature.variable},
    {'name': '택시', 'parent': '교통/차량', 'nature': ExpenseNature.variable},
    {'name': '주유', 'parent': '교통/차량', 'nature': ExpenseNature.variable},
    {'name': '주차/통행료', 'parent': '교통/차량', 'nature': ExpenseNature.variable},
    {'name': '차량정비', 'parent': '교통/차량', 'nature': ExpenseNature.variable},

    // 7. 패션/미용
    {'name': '의류/잡화', 'parent': '패션/미용', 'nature': ExpenseNature.variable},
    {'name': '화장품', 'parent': '패션/미용', 'nature': ExpenseNature.variable},
    {'name': '미용실', 'parent': '패션/미용', 'nature': ExpenseNature.variable},

    // 8. 생활/쇼핑
    {'name': '생필품', 'parent': '생활/쇼핑', 'nature': ExpenseNature.variable},
    {'name': '전자기기', 'parent': '생활/쇼핑', 'nature': ExpenseNature.variable},

    // 9. 문화/여가
    {'name': '영화/공연', 'parent': '문화/여가', 'nature': ExpenseNature.variable},
    {'name': '일반도서', 'parent': '문화/여가', 'nature': ExpenseNature.variable},
    {'name': '운동', 'parent': '문화/여가', 'nature': ExpenseNature.variable},
    {'name': '여행/숙박', 'parent': '문화/여가', 'nature': ExpenseNature.variable},
    {'name': '게임/취미', 'parent': '문화/여가', 'nature': ExpenseNature.variable},

    // 10. 건강/의료
    {'name': '병원', 'parent': '건강/의료', 'nature': ExpenseNature.variable},
    {'name': '약국', 'parent': '건강/의료', 'nature': ExpenseNature.variable},
    {'name': '영양제', 'parent': '건강/의료', 'nature': ExpenseNature.variable},

    // 11. 교육/학습
    {'name': '학원비', 'parent': '교육/학습', 'nature': ExpenseNature.variable},
    {'name': '인터넷강의', 'parent': '교육/학습', 'nature': ExpenseNature.variable},
    {'name': '시험응시료', 'parent': '교육/학습', 'nature': ExpenseNature.variable},
    {'name': '교재/수험서', 'parent': '교육/학습', 'nature': ExpenseNature.variable},

    // ----------------------------------------
    // 📌 기타 (Other)
    // ----------------------------------------
    // 12. 경조사/선물
    {'name': '축의금/조의금', 'parent': '경조사/선물', 'nature': ExpenseNature.other},
    {'name': '생일선물', 'parent': '경조사/선물', 'nature': ExpenseNature.other},
    {'name': '명절용돈', 'parent': '경조사/선물', 'nature': ExpenseNature.other},
    {'name': '일회성기부', 'parent': '경조사/선물', 'nature': ExpenseNature.other},

    // 13. 미분류
    {'name': '기타', 'parent': '미분류', 'nature': ExpenseNature.other},
  ];

  for (final c in categories) {
    final category = CategoryModel(
      categoryId: '',
      name: c['name'] as String,
      parentName: c['parent'] as String,
      transactionType: TransactionType.expense,
      nature: c['nature'] as ExpenseNature,
      isCustom: false,
    );
    await service.addCustomCategory(category);
  }
}