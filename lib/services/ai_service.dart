// lib/services/ai_service.dart
// 땡그랑 - 땡코치 AI 서비스 (팀 공용 Ollama 서버)
//
// ★★★ 팀원들에게: 이 파일에서 건드릴 곳은 아래 [서버 설정] 딱 한 줄입니다 ★★★
//
// 제공 기능
//  1) generateNagging   - 일간 잔소리 (3톤: 땡구/땡쥐/땡냥이)
//  2) generateWeekly    - 주간 리포트
//  3) generateMonthly   - 월간 리포트
//  4) consult           - 살까말까 상담 (판정 + 근거, 하루 5회 제한)
//  5) parseExpense      - 카드 결제 알림 -> 지출 JSON
//  6) parseIncome       - 입금 알림 -> 수입 (정규식, AI 미사용)
//  7) analyzeType       - 소비 유형 분석 (테스트 결과 해석)
//
// 준비물 (프로젝트에 한 번만)
//  - pubspec.yaml:  http: ^1.2.0
//  - AndroidManifest.xml <application>에 android:usesCleartextTraffic="true"
//  - AndroidManifest.xml에 <uses-permission android:name="android.permission.INTERNET"/>

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/coach_tone.dart';
import 'package:flutter/foundation.dart';

export '../models/coach_tone.dart' show CoachTone;

// ═══════════════════════ [서버 설정] ═══════════════════════
// AI 서버 = 은동 PC. 은동 PC가 켜져 있어야 AI 기능이 동작합니다.
// IP가 바뀌면 이 값만 수정하세요. (은동 PC에서 ipconfig -> IPv4 주소)
//
// ※ AI 안 될 때: ① 은동 PC 켜져 있나 ② 같은 와이파이인가 ③ IP 바뀌었나
const String kAiServerIp = '192.168.30.55';
const String kAiServerPort = '11434';
const String kAiModel = 'ddaengcoach-v3';
// ════════════════════════════════════════════════════════════

/// 살까말까 판정
enum Verdict {
  buy('사도 됨'),
  hold('보류'),
  conditional('조건부');

  final String label;
  const Verdict(this.label);

  static Verdict? fromText(String s) {
    for (final v in Verdict.values) {
      if (s.contains(v.label)) return v;
    }
    return null;
  }
}

/// 상담 결과 (판정 + 코멘트)
class ConsultResult {
  final Verdict? verdict; // null이면 판정 파싱 실패 -> UI는 코멘트만 표시
  final String comment;
  ConsultResult({required this.verdict, required this.comment});
}

/// 파싱된 지출
class ParsedExpense {
  final int amount;
  final String merchant;
  final String memo; // 실제 구매 내용 (예: "삼각김밥, 커피"). 없으면 빈 문자열
  final String category;
  final String type; // 고정비 | 변동비
  final String? date;
  final String? transactionType; // 지출, 수입, 저축 구분용
  ParsedExpense({
    required this.amount,
    required this.merchant,
    this.memo = '',
    required this.category,
    required this.type,
    this.date,
    this.transactionType
  });
  @override
  String toString() =>
      '$date / $transactionType / $merchant / $memo / $amount원 / $category / $type';
}

/// 파싱된 수입
class ParsedIncome {
  final int amount;
  final String from;
  final String source; // 월급 | 알바 | 용돈 | 부수입 | 기타
  ParsedIncome({required this.amount, required this.from, required this.source});
  @override
  String toString() => '$from / $amount원 / $source';
}

class AiService {
  static const String _baseUrl = 'http://$kAiServerIp:$kAiServerPort';

  // 앱에서 사용하는 카테고리 화이트리스트 (모델 출력 보정용)
  static const List<String> categories = [
    '식사', '카페/디저트', '마트/장보기', '편의점',
    '대중교통', '택시', '주유', '주차/통행료', '차량정비',
    '의류/잡화', '화장품', '미용실', '전자기기', '쇼핑/뷰티',
    '영화/공연', '도서', '운동', '여행/숙박', '게임/취미',
    '병원', '약국', '영양제',
    '학원비', '인강', '시험응시료',
    'OTT구독', '음원스트리밍', '휴대폰요금', '인터넷', '보험료',
    '월세', '관리비', '공과금',
    '경조사', '선물', '미분류',
  ];

  // ── 서버 생존 확인 ─────────────────────────────────────────
  Future<bool> isServerAlive() async {
    try {
      final res =
      await http.get(Uri.parse(_baseUrl)).timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── 상담 Rate Limit (하루 5회) ─────────────────────────────
  // MVP: 메모리 카운터. 본 프로젝트에서는 Firestore users/{uid}에 날짜별 저장으로 교체할 것.
  // AiService()는 호출부마다 새 인스턴스라 static이어야 앱 전역에서 같은 카운트를 본다.
  static const int consultDailyLimit = 5;
  static int _consultCount = 0;
  static int _bonusCount = 0;          // 추가 — 광고 시청으로 얻은 보너스 횟수
  static String _consultDate = '';

  int get consultRemaining {
    _resetIfNewDay();
    return consultDailyLimit + _bonusCount - _consultCount;
  }

  void _resetIfNewDay() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_consultDate != today) {
      _consultDate = today;
      _consultCount = 0;
      _bonusCount = 0;   // 추가 — 날짜 바뀌면 보너스도 초기화
    }
  }

  /// 광고 시청 완료 시 호출 — 오늘 상담 가능 횟수를 늘려준다.
  void addBonusConsult({int amount = 1}) {
    _resetIfNewDay();
    _bonusCount += amount;
    debugPrint('🎯 보너스 적용 후 bonusCount=$_bonusCount, remaining=$consultRemaining');
  }

  // ═══════════════ 캐시 (잔소리/주간/월간 — 기간당 1회 생성, 재사용) ═══════════════
  // AiService()는 호출부마다 새로 생성되는 인스턴스라 캐시는 static으로 공유해야
  // 실제로 효과가 있다. 키에 dataSummary 원문을 그대로 넣기 때문에, 집계 숫자가
  // 바뀌면(=새 지출 발생) 자연히 캐시가 미스나며 재생성된다 — 별도 무효화 로직 불필요.
  static final Map<String, String> _reportCache = {};

  Future<String> _generateCached(String cacheKey, String prompt, String source) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final key = '$today|$cacheKey';
    final cached = _reportCache[key];
    if (cached != null) return cached;
    final result = await _generateChecked(prompt, source);
    _reportCache[key] = result;
    return result;
  }

  // ═══════════════ 1) 일간 잔소리 ═══════════════
  /// [dataSummary] 예: "배달비: 140,000원 (전월 대비 +40%), 스트레스 태그 비율: 70%"
  /// 집계/계산은 앱(Firestore + Dart)에서 끝내고, 완성된 숫자 문장만 넘길 것.
  /// 같은 날 동일한 톤+데이터 조합이면 재호출 없이 캐시된 문장을 재사용한다.
  Future<String> generateNagging(CoachTone tone, String dataSummary) {
    return _generateCached(
        'nagging|${tone.name}|$dataSummary', '[톤: ${tone.label}] $dataSummary', dataSummary);
  }

  // ═══════════════ 2) 주간 리포트 ═══════════════
  Future<String> generateWeekly(
      CoachTone tone, {
        required int totalSpent,
        required int budgetRemainPercent,
        required String topCategory,
        required int topCategoryPercent,
        required int noSpendDays,
        required int weekOverWeekPercent, // 음수 가능
      }) {
    final wow = weekOverWeekPercent >= 0
        ? '+$weekOverWeekPercent'
        : '$weekOverWeekPercent';
    final data = '이번 주 지출: ${_won(totalSpent)}, 주간 예산 잔여: $budgetRemainPercent%, '
        '최다 카테고리: $topCategory($topCategoryPercent%), 무지출: $noSpendDays일, 전주 대비: $wow%';
    return _generateCached('weekly|${tone.name}|$data', '[리포트: 주간] [톤: ${tone.label}] $data', data);
  }

  // ═══════════════ 3) 월간 리포트 ═══════════════
  Future<String> generateMonthly(
      CoachTone tone, {
        required int totalSpent,
        required int monthOverMonthPercent,
        required int income,
        required int savingRate,
        required String topCategory,
        required int topCategoryPercent,
        required int stressTagPercent,
        required int budgetAchieved,
        required int budgetTotal,
      }) {
    final mom = monthOverMonthPercent >= 0
        ? '+$monthOverMonthPercent'
        : '$monthOverMonthPercent';
    final data = '이번 달 총지출: ${_won(totalSpent)} (전월 대비 $mom%), 수입: ${_won(income)}, '
        '저축률: $savingRate%, 최다 카테고리: $topCategory($topCategoryPercent%), '
        '스트레스 태그 비율: $stressTagPercent%, 예산 달성: $budgetAchieved/$budgetTotal 카테고리';
    return _generateCached(
        'monthly|${tone.name}|$data', '[리포트: 월간] [톤: ${tone.label}] $data', data);
  }

  // ═══════════════ 3.5) 소비 챌린지 ═══════════════
  /// [dataSummary] 예: "카테고리: 배달, 목표: 80,000원 이하, 지난달: 100,000원"
  Future<String> generateChallenge(CoachTone tone, String dataSummary) {
    return _generateCached(
        'challenge|${tone.name}|$dataSummary', '[리포트: 챌린지] [톤: ${tone.label}] $dataSummary', dataSummary);
  }

  // ═══════════════ 4) 살까말까 상담 ═══════════════
  /// 출력 예:
  ///   판정: 보류
  ///   최근 충동 태그가 64%예요. 이 상태에서의 구매 결정은 후회 확률이 높아요...
  Future<ConsultResult> consult(
      CoachTone tone, {
        required String question,
        required int budgetRemain,
        required int budgetTotal,
        required int usedPercent,
        required int impulsePercent,
        required int daysToPayday,
      }) async {
    _resetIfNewDay();
    if (consultRemaining <= 0) {
      throw RateLimitException('오늘 상담 횟수를 모두 사용했어요. 내일 다시 만나요!');
    }
    _consultCount++;

    final context = '컨텍스트: 예산 잔액 ${_comma(budgetRemain)}원 / ${_comma(budgetTotal)}원 '
        '(사용률 $usedPercent%), 최근 30일 충동 태그 비율 $impulsePercent%, '
        '월급일 D-$daysToPayday';
    final raw = await _callOllama('[작업: 상담] [톤: ${tone.label}] $context 질문: $question');

    // "판정: xxx\n본문" 파싱
    final lines = raw.split('\n');
    Verdict? verdict;
    var body = raw;
    if (lines.isNotEmpty && lines.first.contains('판정')) {
      verdict = Verdict.fromText(lines.first);
      body = lines.skip(1).join('\n').trim();
    }
    return ConsultResult(verdict: verdict, comment: body.isEmpty ? raw : body);
  }

  // ═══════════════ 5) 지출 파싱 (AI) ═══════════════
  /// 권장 파이프라인: ① 정규식으로 금액 추출 → ② 키워드 룰로 카테고리 →
  ///                  ③ 룰 미스일 때만 이 함수 호출 → ④ 실패 시 '미분류'
  Future<ParsedExpense?> parseExpense(String notificationText) async {
    final raw = await _callOllama('[작업: 지출파싱] $notificationText');
    try {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start == -1 || end == -1) return null;

      final j = jsonDecode(raw.substring(start, end + 1)) as Map<String, dynamic>;
      final amount = (j['amount'] as num?)?.toInt();
      final merchant = j['merchant'] as String?;
      if (amount == null || merchant == null) return null;

      // 환각 방어: 금액이 원문에 실제로 있는가
      if (!notificationText.contains('$amount') &&
          !notificationText.contains(_comma(amount))) {
        return null;
      }

      return ParsedExpense(
        amount: amount,
        merchant: merchant,
        category: _normalizeCategory(j['category'] as String?),
        type: (j['type'] as String?) == '고정비' ? '고정비' : '변동비',
      );
    } catch (_) {
      return null;
    }
  }

  /// 모델이 "카페"처럼 축약해서 뱉는 경우가 있어 화이트리스트로 보정
  String _normalizeCategory(String? raw) {
    if (raw == null || raw.isEmpty) return '미분류';
    if (categories.contains(raw)) return raw;
    for (final c in categories) {
      if (c.contains(raw) || raw.contains(c)) return c;
    }
    return '미분류';
  }

  // ═══════════════ 6) 수입 파싱 (정규식, AI 미사용) ═══════════════
  /// 입금 문자는 포맷이 단순해서 코드로 처리하는 편이 정확하고 빠름.
  /// 예: "[Web발신] 신한은행 입금 2,200,000원 (주)더조은컴퍼니 급여"
  ParsedIncome? parseIncome(String text) {
    if (!RegExp(r'입금|입금됐|급여|이체').hasMatch(text)) return null;

    final m = RegExp(r'([\d,]{4,})\s*원').firstMatch(text);
    if (m == null) return null;
    final amount = int.tryParse(m.group(1)!.replaceAll(',', ''));
    if (amount == null) return null;

    var from = text
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'(신한|국민|KB|하나|우리|농협|NH|카카오뱅크|토스|기업|SC)\s*(은행)?'), '')
        .replaceAll(RegExp(r'입금(됐어요)?|이체|잔액|원|[\d,]+|\d{2}/\d{2}|\d{2}:\d{2}|·'), '')
        .trim();
    if (from.isEmpty) from = '알 수 없음';

    return ParsedIncome(amount: amount, from: from, source: _guessSource(text));
  }

  String _guessSource(String t) {
    if (RegExp(r'급여|월급|정기|봉급').hasMatch(t)) return '월급';
    if (RegExp(r'알바|시급|파트').hasMatch(t)) return '알바';
    if (RegExp(r'용돈|엄마|아빠|어머니|아버지|할머니|할아버지').hasMatch(t)) return '용돈';
    if (RegExp(r'정산|판매|당근|중고|쿠팡플렉스|배민커넥트|크몽|부수입').hasMatch(t)) return '부수입';
    return '기타';
  }

  // ═══════════════ 7) 소비 유형 분석 ═══════════════
  /// 출력 예: "유형: 번개손 토끼\n마음에 들면 이미 결제 완료!..."
  Future<({String typeName, String description})> analyzeType({
    required int impulse,
    required int planned,
    required int stress,
    required int social,
  }) async {
    final data = '충동 $impulse%, 계획 $planned%, 스트레스 $stress%, 사회적 $social%';
    final raw = await _callOllama('[작업: 유형분석] $data');

    final lines = raw.split('\n');
    var typeName = '균형 부엉이';
    var desc = raw;
    if (lines.isNotEmpty && lines.first.contains('유형')) {
      typeName = lines.first.replaceFirst(RegExp(r'^유형\s*:\s*'), '').trim();
      desc = lines.skip(1).join('\n').trim();
    }
    return (typeName: typeName, description: desc.isEmpty ? raw : desc);
  }

  // ═══════════════ 내부 구현 ═══════════════

  /// 생성 + 숫자 검증 (불일치 시 1회 재생성, 그래도 실패하면 원문 반환)
  Future<String> _generateChecked(String prompt, String source) async {
    String last = '';
    for (var i = 0; i < 2; i++) {
      last = await _callOllama(prompt);
      if (_numbersValid(last, source)) return last;
    }
    return last; // 문장은 살리되, 필요하면 호출부에서 경고 표시
  }

  Future<String> _callOllama(String prompt) async {
    final http.Response res;
    try {
      res = await http
          .post(
        Uri.parse('$_baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': kAiModel,
          'prompt': prompt,
          'stream': false,
          // memo 필드가 추가되면서 응답이 길어져 모델 기본 출력 한도에 걸릴 수 있어
          // 넉넉하게 명시해준다. (기본값이 짧으면 항목이 중간에서 계속 잘림)
          'options': {
            'num_predict': 1024,
          },
        }),
      )
          .timeout(const Duration(seconds: 90)); // CPU 서빙 + 공용, 넉넉하게
    } catch (e) {
      throw AiServerException('AI 서버에 연결할 수 없어요. 은동 PC가 켜져 있는지, 같은 와이파이인지 확인!');
    }
    if (res.statusCode != 200) {
      throw AiServerException('Ollama 응답 오류: ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['response'] as String).trim();
  }

  /// 출력의 3자리 이상 숫자가 전부 입력에 존재하는지 (수치 환각 방어)
  bool _numbersValid(String output, String source) {
    final src = _extractNumbers(source);
    for (final n in _extractNumbers(output)) {
      if (n.length >= 3 && !src.contains(n)) return false;
    }
    return true;
  }

  Set<String> _extractNumbers(String text) {
    final out = <String>{};
    for (final m in RegExp(r'\d[\d,]*').allMatches(text)) {
      out.add(m.group(0)!.replaceAll(',', ''));
    }
    // "14만 3천원" -> 143000 복원해서 대조
    for (final m in RegExp(r'(\d+)만(?:\s*(\d+)천)?').allMatches(text)) {
      final man = int.parse(m.group(1)!);
      final cheon = int.tryParse(m.group(2) ?? '') ?? 0;
      out.add((man * 10000 + cheon * 1000).toString());
    }
    return out;
  }

  static String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  static String _won(int n) {
    if (n < 10000) return '${_comma(n)}원';
    final man = n ~/ 10000;
    final rest = n % 10000;
    return rest == 0 ? '$man만원' : '$man만 ${rest ~/ 1000}천원';
  }

  // ═══════════════ 8) 대량 텍스트 일괄 파싱 (퉁치기 / 한번에 기록하기용) ═══════════════
  Future<List<ParsedExpense>> parseBulkText(String bulkText, {List<String>? userCategories}) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    // 유저 카테고리가 있으면 프롬프트 룰을 동적으로 생성
    final categoryRule = (userCategories != null && userCategories.isNotEmpty)
        ? '\n13. 현재 사용자가 직접 설정한 카테고리 목록: [${userCategories.join(', ')}]\n'
        '반드시 이 목록에 있는 단어 중 문맥에 가장 잘 맞는 것을 우선적으로 선택해. '
        '(예: 배달앱 결제내역인데 목록에 "배달"이 있다면 "식사" 대신 "배달"을 선택할 것)'
        : '';

    final prompt = '''[작업: 대량지출파싱] 오늘 날짜는 $today야. 다음 텍스트를 분석해서 항목별로 분리해줘.
      1. 텍스트의 문맥(샀다, 들어왔다, 이체했다 등)을 파악해서 '지출', '수입', '저축' 중 하나로 분류해.
      2. 카테고리(category)는 내용에 맞게 '식비', '월급', '중고거래', '교통비', '모임/회비' 등으로 자유롭게 적어.
      3. 지출일 경우 성격(type)을 '고정비' 또는 '변동비'로 적고, 수입이나 저축이면 "기타"로 둬.
      4. 텍스트에 '오늘', '어제' 같은 말이 있으면 $today 를 기준으로 계산해.
      5. merchant는 실제 상호명이나 장소명(예: "스타벅스", "편의점", "GS25")을 적고,
         memo에는 무엇을 샀는지/구매 내역을 구체적으로 적어(예: "삼각김밥, 커피",
         "파스타", "화장품"). 텍스트에 특별한 구매 내역 언급이 없으면 memo는 빈 문자열로 둬.
      5-1. 예를 들어 "GS25 8,500원"처럼 구체적 품목 언급이 없으면 memo는 반드시 ""로 남겨.
          품목을 추측해서 지어내면 안 돼. (틀린 예: "삼각김밥, 커피" / 맞는 예: "")
      6. 각 항목의 merchant/memo/category는 반드시 그 항목 자신의 문장에 나온
         내용만 담아야 해. 앞뒤에 있는 다른 날짜/다른 항목의 문장 내용을
         섞어서 넣지 마.

      ── 영수증(상품명·단가·수량·금액이 여러 줄 나열된 텍스트)을 만났을 때 ──
      7. 영수증처럼 상품이 여러 줄 나열돼 있어도 절대로 상품 하나하나를
         별개 항목으로 쪼개지 마. 영수증 전체를 통틀어 딱 1개의 항목으로만 만들어.
      8. 영수증에서 실제로 쓸 정보는 딱 2가지, ①상호명(맨 위에 크게 적힌 가게 이름)과
         ②최종 결제 총액, 이 둘뿐이야. 이 둘을 제외한 나머지 텍스트
         (상품명, 단가, 수량, 개별 금액, 부가세, 공급가액, 주문합계, 판매총액 세부,
         거래종류, 거래일시, 승인번호, 카드번호/카드사, 사업자번호, 대표자명,
         주소, 포인트, 적립/사용, 바코드 숫자 등)는 전부 무시해. 이 문구들이
         merchant/memo/category/amount 어디에도 절대 들어가면 안 돼.
      9. amount(최종 총액)를 찾는 순서는 다음과 같아:
         a) "Total"이라는 영문 라벨이 있으면 그 옆 숫자를 최우선으로 써.
         b) 없으면 "합계금액", "받을금액", "청구금액" 옆 숫자를 써.
         c) "부가세", "공급가액", "주문합계 세부내역"처럼 총액보다 작은
            중간 계산값은 최종 총액이 아니니 amount로 쓰면 안 돼.
         d) 개별 상품 금액들을 네가 직접 더해서 amount를 만들지 마.
            (부가세·할인 때문에 오차가 남)
      10. merchant는 영수증 맨 위 상호명만 짧게 적어. (예: "TOMNTOMS", "농협")
      11. memo는 영수증일 때는 구매 품목을 적지 말고 merchant와 똑같은
          상호명을 그대로 적어. (예: merchant가 "TOMNTOMS"면 memo도 "TOMNTOMS")
      12. category는 반드시 상호명(merchant)을 보고 아래 매핑 중 가장 가까운
          큰 분류 하나만 적어. 모르면 "미분류"라고 적고, 절대 "교통비"처럼
          엉뚱한 카테고리를 지어내지 마.
          - 대형마트/농협/하나로마트/슈퍼 → "마트/장보기"
          - 편의점(GS25/CU/세븐일레븐/이마트24) → "편의점"
          - 카페/베이커리 → "카페/디저트"
          - 음식점/식당 → "식사"
          - 약국 → "약국", 병원/의원 → "병원"
          - 그 외 판단이 안 서면 → "미분류"$categoryRule

      ── 영수증 예시 (반드시 이 패턴을 그대로 따라해) ──
      입력 예시:
        TOMNTOMS
        사업자번호:1541600462 대표:강경광
        상품명 단가 수량 금액
        카페 아메리카노 4,100 1 4,100
        >> Tall - 1 -
        >> 일회용컵으로 - 1 -
        아이스 카페 아메리카노 4,600 1 4,600
        >> Tall - 1 -
        >> 일회용컵으로 - 1 -
        주문합계 8,600
        공급가금액 7,818
        부가세 782
        Total 8,600
        거래종류: 현금거래
        거래일시: 2018-11-01 15:13:48
      출력 예시(반드시 아래처럼 항목 1개로만, amount는 Total 값 8600으로):
        [{"date": "2018-11-01", "transactionType": "지출", "amount": 8600, "merchant": "TOMNTOMS", "memo": "TOMNTOMS", "category": "카페/디저트", "type": "변동비"}]

      반드시 아래의 JSON 배열 형식으로만 출력해 (다른 말은 절대 금지):
      [{"date": "YYYY-MM-DD", "transactionType": "지출/수입/저축", "amount": 숫자, "merchant": "상호명 또는 장소명", "memo": "구매 내역(없으면 빈 문자열)", "category": "카테고리명", "type": "고정비/변동비"}]

      입력텍스트: $bulkText''';

    // 로컬 모델이라 실행마다 편차가 있어서, 응답이 중간에 끊긴 것처럼 보이면
    // 최대 1회 자동으로 다시 시도한다. 여러 번 시도한 것 중 가장 많이
    // 건진 결과를 최종적으로 사용한다.
    List<ParsedExpense> best = [];

    for (int attempt = 0; attempt < 2; attempt++) {
      final String raw = await _callOllama(prompt);
      final List<ParsedExpense> parsed = _extractParsedExpenses(raw);

      if (parsed.length > best.length) {
        best = parsed;
      }

      // 응답이 제대로 닫혀서 끝난 것 같으면(배열이나 코드블록이 정상 종료)
      // 굳이 다시 시도할 필요 없다.
      if (_looksComplete(raw)) break;

      debugPrint('[대량파싱] 응답이 중간에 끊긴 것 같아 재시도함 (시도 ${attempt + 1}회, 항목 ${parsed.length}개)');
    }

    return best;
  }

  /// 응답 끝부분이 배열(`]`)이나 코드블록(```)으로 정상적으로 닫혔는지 본다.
  /// 닫히지 않았으면 응답이 중간에 잘렸을 가능성이 높다는 신호로 쓴다.
  bool _looksComplete(String raw) {
    final String trimmed = raw.trim();
    return trimmed.endsWith(']') || trimmed.endsWith('```');
  }

  /// 모델이 배열 하나를 깔끔하게 뱉지 않고(중간에 끊기거나, 블록을 통째로
  /// 다시 시작하는 등) 응답이 지저분할 때가 있어서, 배열 단위가 아니라
  /// 완전한 `{...}` 객체 하나하나를 낱개로 찾아 개별적으로 파싱한다.
  ///
  /// ```json 코드블록이 여러 개로 쪼개져 나올 때, 한 블록 안에서 따옴표가
  /// 깨지면(예: 문자열이 안 닫힌 채로 블록이 끝남) 그 "문자열 안에 있다"는
  /// 상태가 다음 블록까지 새어나가 이후 블록의 항목을 전부 놓치게 된다.
  /// 이를 막기 위해 ``` 로 감싸인 블록 단위로 나눠서, 블록마다 따옴표/중괄호
  /// 상태를 완전히 새로 시작해서 독립적으로 스캔한다.
  List<ParsedExpense> _extractParsedExpenses(String raw) {
    final List<ParsedExpense> result = [];

    final List<String> chunks = raw.split(RegExp(r'```(json)?'));
    for (final String chunk in chunks) {
      result.addAll(_extractObjectsFrom(chunk));
    }

    if (result.isEmpty) {
      debugPrint('[대량파싱] 완전한 항목을 하나도 못 찾음. 원본:\n$raw');
    }
    return result;
  }

  /// 완전한 `{...}` 객체 하나하나를 낱개로 찾아 개별적으로 파싱한다.
  /// (따옴표/중괄호 상태는 이 청크 안에서만 유지되고 다음 청크로 넘어가지 않음)
  List<ParsedExpense> _extractObjectsFrom(String chunk) {
    final List<ParsedExpense> result = [];
    int depth = 0;
    bool inString = false;
    bool escape = false;
    int? objStart;

    for (int i = 0; i < chunk.length; i++) {
      final String ch = chunk[i];

      if (escape) {
        escape = false;
        continue;
      }
      if (ch == '\\') {
        escape = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{') {
        if (depth == 0) objStart = i;
        depth++;
      } else if (ch == '}') {
        if (depth > 0) {
          depth--;
          if (depth == 0 && objStart != null) {
            _tryAddExpense(chunk.substring(objStart, i + 1), result);
            objStart = null;
          }
        }
      }
    }

    return result;
  }

  void _tryAddExpense(String candidate, List<ParsedExpense> result) {
    try {
      final Map<String, dynamic> j = jsonDecode(candidate) as Map<String, dynamic>;
      final num? amountNum = j['amount'] as num?;
      final String? merchant = j['merchant'] as String?;
      if (amountNum == null || merchant == null) return;

      final String memo = (j['memo'] as String? ?? '').trim();

      // 방어 코드: 프롬프트를 지켰어도 로컬 모델 특성상 가끔
      // "부가세", "거래종류: 현금거래" 같은 영수증 세부 라벨을 통째로
      // merchant/memo로 뱉는 경우가 있어서, 그런 항목은 아예 버린다.
      if (_looksLikeReceiptNoise(merchant) || _looksLikeReceiptNoise(memo)) {
        debugPrint('[대량파싱] 영수증 노이즈로 판단해 항목 제외: merchant="$merchant" memo="$memo"');
        return;
      }

      result.add(ParsedExpense(
        amount: amountNum.toInt(),
        merchant: merchant,
        memo: memo,
        category: j['category'] as String? ?? '미분류',
        type: j['type'] as String? ?? '변동비',
        date: j['date'] as String?,
        transactionType: j['transactionType'] as String? ?? '지출',
      ));
    } catch (_) {
      // 이 객체 하나만 깨진 것뿐이니 나머지 항목은 계속 시도한다
    }
  }

  /// 영수증에서 상품/총액이 아니라 세부 계산 항목·거래 메타정보가
  /// merchant나 memo로 잘못 들어온 경우를 감지한다.
  static final RegExp _receiptNoisePattern = RegExp(
    r'부가세|공급가액|공급가금액|주문합계|거래종류|거래일시|승인번호|카드번호|카드사|'
    r'사업자번호|대표자?\s*[:：]|사용가능포인트|적립포인트|바코드|잔여\s*포인트',
  );

  bool _looksLikeReceiptNoise(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;

    // 1. 기존 영수증 노이즈 검사
    if (_receiptNoisePattern.hasMatch(t)) {
      return true;
    }

    // 2. 고객명(***님) 패턴 검사
    if (RegExp(r'^[가-힣a-zA-Z\*]+님$').hasMatch(t)) {
      return true;
    }

    return false;
  }
}

class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => message;
}

class AiServerException implements Exception {
  final String message;
  AiServerException(this.message);
  @override
  String toString() => message;
}