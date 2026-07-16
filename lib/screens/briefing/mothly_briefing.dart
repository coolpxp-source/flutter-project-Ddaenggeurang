import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/mothly_briefing_model.dart';
import '../../services/monthly_briefing_service.dart';



/// 월간 브리핑 화면
///
/// 현재 로그인한 사용자의 월별 지출과 예산 데이터를 조회하여
/// 총지출, 예산 사용률, 고정비·변동비,
/// 카테고리 및 감정 태그 분석 결과를 보여주는 화면이다.
class MonthlyBriefingScreen extends StatefulWidget {
  const MonthlyBriefingScreen({
    super.key,
  });

  @override
  State<MonthlyBriefingScreen> createState() {
    return _MonthlyBriefingScreenState();
  }
}

class _MonthlyBriefingScreenState
    extends State<MonthlyBriefingScreen> {
  /// 월간 브리핑 데이터 조회 서비스
  final MonthlyBriefingService _briefingService =
  MonthlyBriefingService();

  /// 현재 화면에서 선택한 월
  DateTime _selectedMonth = DateTime.now();

  /// FutureBuilder에서 사용할 월간 브리핑 조회 결과
  late Future<MonthlyBriefingModel> _briefingFuture;

  @override
  void initState() {
    super.initState();

    /// 화면 최초 실행 시 현재 월 데이터 조회
    _loadMonthlyBriefing();
  }

  /// 선택된 월을 화면에 표시할 문자열로 변환한다.
  ///
  /// 예:
  /// 2026년 7월
  String get _selectedMonthTitle {
    return DateFormat(
      'yyyy년 M월',
    ).format(_selectedMonth);
  }

  /// 현재 선택된 월이 현재 월보다 이전인지 확인한다.
  ///
  /// 현재 월보다 미래로 이동하지 못하도록
  /// 다음 달 버튼 활성화 여부에 사용한다.
  bool get _canMoveNextMonth {
    final DateTime now = DateTime.now();

    if (_selectedMonth.year < now.year) {
      return true;
    }

    if (_selectedMonth.year == now.year &&
        _selectedMonth.month < now.month) {
      return true;
    }

    return false;
  }

  /// 현재 선택한 월의 브리핑 데이터를 불러온다.
  void _loadMonthlyBriefing() {
    /// 현재 Firebase 로그인 사용자
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    /// 로그인된 사용자가 없는 경우
    if (currentUser == null) {
      _briefingFuture =
      Future<MonthlyBriefingModel>.error(
        '로그인된 사용자가 없습니다.',
      );

      return;
    }

    /// 로그인 UID와 현재 선택 월을 전달하여
    /// 월간 브리핑 데이터 조회
    _briefingFuture =
        _briefingService.getMonthlyBriefing(
          userId: currentUser.uid,
          selectedMonth: _selectedMonth,
        );
  }

  /// 이전 달로 이동한다.
  void _movePreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );

      /// 변경된 월의 브리핑 다시 조회
      _loadMonthlyBriefing();
    });
  }

  /// 다음 달로 이동한다.
  void _moveNextMonth() {
    /// 현재 월보다 미래로 이동하지 않도록 방지
    if (!_canMoveNextMonth) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      /// 변경된 월의 브리핑 다시 조회
      _loadMonthlyBriefing();
    });
  }

  /// 새로고침 처리
  ///
  /// 화면을 아래로 당기면 현재 월 데이터를 다시 불러온다.
  Future<void> _refreshMonthlyBriefing() async {
    setState(() {
      _loadMonthlyBriefing();
    });

    await _briefingFuture;
  }

  /// 숫자를 원화 형식 문자열로 변환한다.
  ///
  /// 예:
  /// 1250000 → ₩1,250,000
  String _formatCurrency(
      num amount,
      ) {
    return NumberFormat.currency(
      locale: 'ko_KR',
      symbol: '₩',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '월간 브리핑',
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          /// 상단 월 선택 영역
          _buildMonthSelector(),

          /// 월간 브리핑 본문
          Expanded(
            child: FutureBuilder<MonthlyBriefingModel>(
              future: _briefingFuture,
              builder: (
                  BuildContext context,
                  AsyncSnapshot<MonthlyBriefingModel> snapshot,
                  ) {
                /// 데이터 조회 중
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                /// 데이터 조회 오류
                if (snapshot.hasError) {
                  return _buildErrorView(
                    snapshot.error.toString(),
                  );
                }

                /// 조회 결과
                final MonthlyBriefingModel? briefing =
                    snapshot.data;

                /// 조회 결과가 없는 경우
                if (briefing == null) {
                  return const Center(
                    child: Text(
                      '월간 브리핑 데이터가 없습니다.',
                    ),
                  );
                }

                /// 정상적으로 데이터를 조회한 경우
                return RefreshIndicator(
                  onRefresh: _refreshMonthlyBriefing,
                  child: ListView(
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      /// 월간 요약 카드
                      _buildSummaryCard(
                        briefing,
                      ),

                      const SizedBox(height: 16),

                      /// 예산 사용 현황 카드
                      _buildBudgetCard(
                        briefing,
                      ),

                      const SizedBox(height: 16),

                      /// 지출 성격별 카드
                      _buildExpenseNatureCard(
                        briefing,
                      ),

                      const SizedBox(height: 16),

                      /// 핵심 분석 카드
                      _buildHighlightCard(
                        briefing,
                      ),

                      const SizedBox(height: 16),

                      /// 카테고리별 지출 카드
                      _buildCategoryCard(
                        briefing,
                      ),

                      const SizedBox(height: 16),

                      /// 감정 태그별 지출 카드
                      _buildEmotionCard(
                        briefing,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 이전 달, 선택 월, 다음 달 버튼을 표시한다.
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(
          alpha: 0.35,
        ),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          /// 이전 달 버튼
          IconButton(
            onPressed: _movePreviousMonth,
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),

          /// 선택된 월 표시
          Text(
            _selectedMonthTitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          /// 다음 달 버튼
          ///
          /// 현재 월이면 비활성화
          IconButton(
            onPressed: _canMoveNextMonth
                ? _moveNextMonth
                : null,
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  /// 월간 브리핑 전체 요약 카드
  Widget _buildSummaryCard(
      MonthlyBriefingModel briefing,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '${briefing.monthKey} 소비 브리핑',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            /// 예산 사용 상태에 따른 브리핑 문구
            Text(
              briefing.briefingMessage,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: briefing.isOverBudget
                    ? Colors.red
                    : Colors.black87,
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                /// 총지출
                Expanded(
                  child: _buildSummaryValue(
                    title: '총지출',
                    value: _formatCurrency(
                      briefing.totalSpent,
                    ),
                  ),
                ),

                /// 지출 건수
                Expanded(
                  child: _buildSummaryValue(
                    title: '지출 건수',
                    value:
                    '${briefing.expenseCount}건',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 예산 사용 현황 카드
  Widget _buildBudgetCard(
      MonthlyBriefingModel briefing,
      ) {
    /// LinearProgressIndicator는
    /// 0부터 1 사이 값을 사용한다.
    ///
    /// 예산 사용률이 100%를 초과하더라도
    /// 진행 바는 최대 100%까지만 표시한다.
    final double progress =
        briefing.budgetUsageRate
            .clamp(
          0,
          100,
        )
            .toDouble() /
            100;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              '예산 사용 현황',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            /// 예산 사용률 진행 바
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius:
              BorderRadius.circular(10),
              backgroundColor:
              Colors.grey.shade200,
              color: briefing.isOverBudget
                  ? Colors.red
                  : Colors.blueAccent,
            ),

            const SizedBox(height: 12),

            Text(
              '예산 사용률 '
                  '${briefing.budgetUsageRate.toStringAsFixed(1)}%',
              style: TextStyle(
                color: briefing.isOverBudget
                    ? Colors.red
                    : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            /// 설정한 전체 예산
            _buildAmountRow(
              title: '설정 예산',
              amount: briefing.totalBudget,
            ),

            /// 이번 달 총지출
            _buildAmountRow(
              title: '사용 금액',
              amount: briefing.totalSpent,
            ),

            /// 남은 예산 또는 초과 금액
            _buildAmountRow(
              title: briefing.isOverBudget
                  ? '초과 금액'
                  : '남은 예산',
              amount: briefing.isOverBudget
                  ? briefing.overBudgetAmount
                  : briefing.remainingBudget,
              isWarning: briefing.isOverBudget,
            ),
          ],
        ),
      ),
    );
  }

  /// 고정비, 변동비, 기타 지출 금액 카드
  Widget _buildExpenseNatureCard(
      MonthlyBriefingModel briefing,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              '지출 성격별 금액',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            /// 고정비 합계
            _buildAmountRow(
              title: '고정비',
              amount: briefing.fixedExpense,
            ),

            /// 변동비 합계
            _buildAmountRow(
              title: '변동비',
              amount: briefing.variableExpense,
            ),

            /// 기타 지출 합계
            _buildAmountRow(
              title: '기타',
              amount: briefing.otherExpense,
            ),
          ],
        ),
      ),
    );
  }

  /// 이번 달 핵심 분석 카드
  Widget _buildHighlightCard(
      MonthlyBriefingModel briefing,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              '이번 달 핵심 분석',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            /// 가장 많이 지출한 카테고리
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(
                  Icons.category,
                ),
              ),
              title: const Text(
                '가장 많이 지출한 카테고리',
              ),
              subtitle: Text(
                briefing.topCategoryName ??
                    '데이터 없음',
              ),
              trailing: Text(
                _formatCurrency(
                  briefing.topCategoryAmount,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// 가장 많이 발생한 감정 소비
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(
                  Icons.mood,
                ),
              ),
              title: const Text(
                '가장 많은 감정 소비',
              ),
              subtitle: Text(
                briefing.topEmotionName ??
                    '데이터 없음',
              ),
              trailing: Text(
                _formatCurrency(
                  briefing.topEmotionAmount,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            /// 하루 평균 지출
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                child: Icon(
                  Icons.calendar_today,
                ),
              ),
              title: const Text(
                '하루 평균 지출',
              ),
              trailing: Text(
                _formatCurrency(
                  briefing.dailyAverage,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 카테고리별 지출 카드
  Widget _buildCategoryCard(
      MonthlyBriefingModel briefing,
      ) {
    /// Map 데이터를 리스트로 변환
    final List<MapEntry<String, int>> entries =
    briefing.categoryAmounts.entries
        .toList();

    /// 지출 금액이 높은 순서대로 정렬
    entries.sort(
          (
          MapEntry<String, int> first,
          MapEntry<String, int> second,
          ) {
        return second.value.compareTo(
          first.value,
        );
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              '카테고리별 지출',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            /// 카테고리 지출 데이터가 없는 경우
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 20,
                ),
                child: Center(
                  child: Text(
                    '카테고리 지출 데이터가 없습니다.',
                  ),
                ),
              )
            else
            /// 카테고리별 지출 출력
              ...entries.map(
                    (
                    MapEntry<String, int> entry,
                    ) {
                  /// 전체 지출에서 현재 카테고리가
                  /// 차지하는 비율 계산
                  final double percentage =
                  briefing.totalSpent <= 0
                      ? 0
                      : entry.value /
                      briefing.totalSpent *
                      100;

                  return _buildRankingRow(
                    name: entry.key,
                    amount: entry.value,
                    percentage: percentage,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 감정 태그별 지출 카드
  Widget _buildEmotionCard(
      MonthlyBriefingModel briefing,
      ) {
    /// 감정 태그 Map을 리스트로 변환
    final List<MapEntry<String, int>> entries =
    briefing.emotionAmounts.entries
        .toList();

    /// 금액이 높은 순서대로 정렬
    entries.sort(
          (
          MapEntry<String, int> first,
          MapEntry<String, int> second,
          ) {
        return second.value.compareTo(
          first.value,
        );
      },
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Text(
              '감정 태그별 지출',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            /// 감정 태그 데이터가 없는 경우
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 20,
                ),
                child: Center(
                  child: Text(
                    '감정 태그 데이터가 없습니다.',
                  ),
                ),
              )
            else
            /// 감정 태그별 지출 출력
              ...entries.map(
                    (
                    MapEntry<String, int> entry,
                    ) {
                  /// 변동비 전체에서 현재 감정 태그가
                  /// 차지하는 비율 계산
                  final double percentage =
                  briefing.variableExpense <= 0
                      ? 0
                      : entry.value /
                      briefing.variableExpense *
                      100;

                  return _buildRankingRow(
                    name: entry.key,
                    amount: entry.value,
                    percentage: percentage,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 요약 카드에서 사용하는 공통 값 위젯
  Widget _buildSummaryValue({
    required String title,
    required String value,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// 금액을 한 줄로 출력하는 공통 위젯
  Widget _buildAmountRow({
    required String title,
    required int amount,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            _formatCurrency(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWarning
                  ? Colors.red
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리 및 감정 태그 목록에서 사용하는 공통 행
  Widget _buildRankingRow({
    required String name,
    required int amount,
    required double percentage,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        children: [
          /// 카테고리 또는 감정 태그 이름
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          /// 해당 항목의 비율
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),

          const SizedBox(width: 12),

          /// 해당 항목의 금액
          SizedBox(
            width: 115,
            child: Text(
              _formatCurrency(amount),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 월간 브리핑 조회 실패 화면
  Widget _buildErrorView(
      String error,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: Colors.red,
            ),

            const SizedBox(height: 16),

            const Text(
              '월간 브리핑을 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 10),

            /// 실제 오류 내용
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 20),

            /// 재조회 버튼
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadMonthlyBriefing();
                });
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                '다시 시도',
              ),
            ),
          ],
        ),
      ),
    );
  }
}