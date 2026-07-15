import '../models/category_model.dart';
import '../services/category_service.dart';

/// 저축/투자 카테고리 5개(청약/적금/예금/파킹통장/투자)를 categories 컬렉션에 채워 넣는 함수.
/// 지출 카테고리와 달리 nature(고정비/변동비/기타) 구분이 없음 — saving은 nature가 null.
///
/// ⚠️ 딱 한 번만 실행 (여러 번 실행하면 중복 생성됨)
Future<void> seedSavingCategories() async {
  final service = CategoryService();

  final categories = <Map<String, String>>[
    {'name': '청약', 'parent': '저축/투자'},
    {'name': '적금', 'parent': '저축/투자'},
    {'name': '예금', 'parent': '저축/투자'},
    {'name': '파킹통장', 'parent': '저축/투자'},
    {'name': '투자', 'parent': '저축/투자'},
  ];

  for (final c in categories) {
    final category = CategoryModel(
      categoryId: '',
      name: c['name']!,
      parentName: c['parent']!,
      transactionType: TransactionType.saving,
      isCustom: false,
      // nature는 saving 카테고리엔 해당 없음 (null)
    );
    await service.addCustomCategory(category);
  }
}