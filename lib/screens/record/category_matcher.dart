import 'package:cloud_firestore/cloud_firestore.dart';

/// 실제 카테고리 문서 하나를 표현하는 가벼운 값 객체.
/// categories(기본) / customCategories(커스텀) 두 컬렉션에서 공통으로 뽑아 쓴다.
class CategoryOption {
  final String id;
  final String name;
  final bool isCustom;

  const CategoryOption({
    required this.id,
    required this.name,
    required this.isCustom,
  });
}

/// expense_input_screen.dart 등 입력 화면이 쓰는 것과 동일한 방식으로
/// 기본 카테고리(categories, isCustom=false) + 내 커스텀 카테고리(customCategories)를
/// 함께 불러온다.
///
/// [transactionType]: 'expense' | 'income' | 'saving'
Future<List<CategoryOption>> loadCategoryOptions({
  required String userId,
  required String transactionType,
}) async {
  final db = FirebaseFirestore.instance;

  final defaultSnap = await db
      .collection('categories')
      .where('transactionType', isEqualTo: transactionType)
      .get();
  final customSnap =
  await db.collection('customCategories').where('userId', isEqualTo: userId).get();

  final List<CategoryOption> options = <CategoryOption>[];

  for (final doc in defaultSnap.docs) {
    final data = doc.data();
    options.add(CategoryOption(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      isCustom: false,
    ));
  }

  for (final doc in customSnap.docs) {
    final data = doc.data();
    if (data['transactionType'] != transactionType) continue;
    if (data['isHidden'] == true) continue;
    options.add(CategoryOption(
      id: doc.id,
      name: (data['name'] ?? '').toString(),
      isCustom: true,
    ));
  }

  return options;
}

/// AI가 자유 텍스트로 뱉은 카테고리명(예: "카페비")과 상호명(예: "스타벅스")을
/// 실제 카테고리 목록과 매칭한다. 매칭 성공 시 categoryId를 반환하고,
/// 실패하면 null을 반환한다(호출부에서 '미분류' 등으로 처리).
///
/// 우선순위:
///  1) 내 커스텀 카테고리를 기본 카테고리보다 먼저 확인한다.
///     (예: '배달' 커스텀 카테고리를 직접 만들었다면 그게 우선 선택됨)
///  2) 각 단계 안에서는:
///     a) 실제 카테고리명이 AI 텍스트/상호명에 그대로 포함되는지 먼저 보고,
///     b) 상호명이 GS25/스타벅스처럼 명확한 브랜드/체인점이면 그걸 최우선으로
///        매칭한다. (AI가 category를 "식비"처럼 뭉뚱그려 적어도, 상호명이
///        분명하면 그쪽을 신뢰한다.)
///     c) 그래도 안 되면 아래 일반 키워드 규칙을 순서대로 시도한다. 키워드는
///        앞에 있는 것부터 시도하므로, '배달' 카테고리가 없는 사람은 자연스럽게
///        다음 후보인 '식사'로 넘어간다.
String? matchCategoryId({
  required String aiCategoryText,
  required String merchant,
  required List<CategoryOption> options,
}) {
  final String normalizedCategory = _normalize(aiCategoryText);
  final String normalizedMerchant = _normalize(merchant);
  final String? brandKeyword = _brandKeyword(normalizedMerchant);
  final List<String> keywordCandidates = _keywordCandidates(
    normalizedCategory,
    normalizedMerchant,
  );

  CategoryOption? findByKeyword(List<CategoryOption> pool, String keyword) {
    for (final CategoryOption opt in pool) {
      if (_normalize(opt.name).contains(keyword)) return opt;
    }
    return null;
  }

  CategoryOption? findIn(List<CategoryOption> pool) {
    // 1) AI 카테고리 텍스트/상호명 안에 실제 카테고리명이 그대로 들어있는 경우
    for (final CategoryOption opt in pool) {
      final String name = _normalize(opt.name);
      if (name.isEmpty) continue;
      if (normalizedCategory.contains(name) || normalizedMerchant.contains(name)) {
        return opt;
      }
    }
    // 2) 상호명이 명확한 브랜드/체인점이면 일반 키워드보다 먼저 매칭
    if (brandKeyword != null) {
      final CategoryOption? byBrand = findByKeyword(pool, brandKeyword);
      if (byBrand != null) return byBrand;
    }
    // 3) 일반 키워드 후보를 순서대로 시도 (앞쪽 후보가 우선)
    for (final String keyword in keywordCandidates) {
      final CategoryOption? byKeyword = findByKeyword(pool, keyword);
      if (byKeyword != null) return byKeyword;
    }
    return null;
  }

  final List<CategoryOption> customPool =
  options.where((CategoryOption o) => o.isCustom).toList();
  final List<CategoryOption> defaultPool =
  options.where((CategoryOption o) => !o.isCustom).toList();

  return (findIn(customPool) ?? findIn(defaultPool))?.id;
}

String _normalize(String s) => s.replaceAll(RegExp(r'\s'), '').toLowerCase();

/// 상호명이 특정 체인/브랜드로 명확히 식별되면 그 카테고리 키워드를 반환한다.
/// 상호명 전용이라 category 텍스트("식비" 등)는 절대 안 보고, merchant만 본다.
/// 애매하면 null을 반환해서 일반 키워드 매칭으로 넘어가게 한다.
String? _brandKeyword(String normalizedMerchant) {
  final List<MapEntry<RegExp, String>> brandPatterns = <MapEntry<RegExp, String>>[
    MapEntry(RegExp('gs25|씨유|\\bcu\\b|세븐일레븐|이마트24'), '편의점'),
    MapEntry(RegExp('스타벅스|이디야|메가커피|투썸|커피빈|빽다방|컴포즈'), '카페'),
    MapEntry(RegExp('배달의민족|배민|요기요|쿠팡이츠'), '배달'),
    MapEntry(RegExp('이마트(?!24)|롯데마트|홈플러스|코스트코'), '마트'),
    MapEntry(RegExp('올리브영'), '화장품'),
    MapEntry(RegExp('cgv|메가박스|롯데시네마'), '영화'),
    MapEntry(RegExp('넷플릭스|왓챠|웨이브|디즈니'), 'ott'),
    MapEntry(RegExp('멜론|지니|스포티파이'), '음원'),
    MapEntry(RegExp('에어비앤비'), '여행'),
  ];

  for (final MapEntry<RegExp, String> entry in brandPatterns) {
    if (entry.key.hasMatch(normalizedMerchant)) return entry.value;
  }
  return null;
}

/// AI 텍스트/상호명에서 대표 키워드 후보를 순서대로 뽑는다.
/// 필요한 패턴은 여기에 계속 추가하면 됨. 뒤에 추가한 키워드일수록
/// "없으면 이걸로 대체" 순서로 동작한다.
List<String> _keywordCandidates(String normalizedCategory, String normalizedMerchant) {
  final String combined = '$normalizedCategory $normalizedMerchant';
  final List<String> result = <String>[];

  void addIfMatch(RegExp pattern, List<String> keywords) {
    if (pattern.hasMatch(combined)) result.addAll(keywords);
  }

  addIfMatch(RegExp('카페|커피|스타벅스|이디야|메가|투썸|커피빈|빽다방|컴포즈'), ['카페']);
  // 배달 전문 카테고리가 없는 사람은 자연스럽게 '식사'로 넘어가도록 둘 다 후보에 넣음
  addIfMatch(RegExp('배달|배민|요기요|쿠팡이츠|배달의민족'), ['배달', '식사']);
  // '식비'는 AI가 프롬프트상 매우 자주 쓰는 자유 텍스트라 '식사'와 별도로 반드시 포함
  addIfMatch(
    RegExp('식사|식비|밥|점심|저녁|식당|맛집|파스타|한식|중식|일식|양식|분식|치킨|피자|버거|국밥|김밥|고기'),
    ['식사'],
  );
  addIfMatch(RegExp('마트|장보기|이마트|롯데마트|홈플러스|코스트코|생필품|생활용품'), ['마트']);
  addIfMatch(RegExp('편의점|씨유|gs25|세븐일레븐|이마트24'), ['편의점']);
  addIfMatch(RegExp('지하철|버스|전철|대중교통|교통카드|교통비'), ['대중교통']);
  addIfMatch(RegExp('택시|카카오택시|우버'), ['택시']);
  addIfMatch(RegExp('주유|기름|주유소'), ['주유']);
  addIfMatch(RegExp('주차|통행료|하이패스'), ['주차']);
  addIfMatch(RegExp('정비|카센터|엔진오일'), ['차량정비']);
  addIfMatch(RegExp('병원|의원|진료'), ['병원']);
  addIfMatch(RegExp('약국'), ['약국']);
  addIfMatch(RegExp('영양제|비타민|건강기능식품'), ['영양제']);
  addIfMatch(RegExp('옷|의류|잡화|패션'), ['의류']);
  addIfMatch(RegExp('화장품|올리브영|뷰티'), ['화장품']);
  addIfMatch(RegExp('미용실|헤어|파마|염색'), ['미용실']);
  addIfMatch(RegExp('전자기기|가전|디지털'), ['전자기기']);
  addIfMatch(RegExp('영화|공연|극장|cgv|메가박스|롯데시네마'), ['영화']);
  addIfMatch(RegExp('도서|책|서점|교보문고'), ['도서']);
  addIfMatch(RegExp('운동|헬스|피트니스|필라테스|요가'), ['운동']);
  addIfMatch(RegExp('여행|숙박|호텔|모텔|에어비앤비'), ['여행']);
  addIfMatch(RegExp('게임|취미|스팀|플스'), ['게임']);
  addIfMatch(RegExp('학원|인강|강의|시험응시료|토익|자격증'), ['학원']);
  addIfMatch(RegExp('구독|ott|넷플릭스|왓챠|웨이브|디즈니'), ['ott', '구독'],);
  addIfMatch(RegExp('음원|멜론|지니|스포티파이'), ['음원']);
  addIfMatch(RegExp('통신|휴대폰|핸드폰요금'), ['휴대폰']);
  addIfMatch(RegExp('인터넷|와이파이'), ['인터넷']);
  addIfMatch(RegExp('보험'), ['보험']);
  addIfMatch(RegExp('월세|임대료'), ['월세']);
  addIfMatch(RegExp('관리비'), ['관리비']);
  addIfMatch(RegExp('공과금|전기세|수도세|가스비'), ['공과금']);
  addIfMatch(RegExp('경조사|축의금|조의금'), ['경조사']);
  addIfMatch(RegExp('선물'), ['선물']);
  addIfMatch(RegExp('급여|월급|급여이체|월급이체'), ['정기급여', '급여']);
  // 어떤 키워드에도 안 걸리면 최후 폴백으로 '미분류'류 카테고리를 시도
  result.addAll(['미분류', '기타']);

  return result;
}

/// expense/income/saving 카테고리를 한 번에 묶어서 들고 다니기 위한 값 객체.
/// draft_mapper와 DraftReviewScreen이 Firestore를 각자 따로 조회하지 않고
/// 이 객체 하나를 공유해서 쓰도록 하기 위함.
class AllCategoryOptions {
  final List<CategoryOption> expense;
  final List<CategoryOption> income;
  final List<CategoryOption> saving;

  const AllCategoryOptions({
    required this.expense,
    required this.income,
    required this.saving,
  });
}

Future<AllCategoryOptions> loadAllCategoryOptions({required String userId}) async {
  final List<List<CategoryOption>> results = await Future.wait([
    loadCategoryOptions(userId: userId, transactionType: 'expense'),
    loadCategoryOptions(userId: userId, transactionType: 'income'),
    loadCategoryOptions(userId: userId, transactionType: 'saving'),
  ]);
  return AllCategoryOptions(expense: results[0], income: results[1], saving: results[2]);
}