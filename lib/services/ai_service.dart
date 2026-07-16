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
  final String category;
  final String type; // 고정비 | 변동비
  ParsedExpense({
    required this.amount,
    required this.merchant,
    required this.category,
    required this.type,
  });
  @override
  String toString() => '$merchant / $amount원 / $category / $type';
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
  static String _consultDate = '';

  int get consultRemaining {
    _resetIfNewDay();
    return consultDailyLimit - _consultCount;
  }

  void _resetIfNewDay() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_consultDate != today) {
      _consultDate = today;
      _consultCount = 0;
    }
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
    if (_consultCount >= consultDailyLimit) {
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