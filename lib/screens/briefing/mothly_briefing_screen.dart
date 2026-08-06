import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/mothly_briefing_model.dart';
import '../../services/monthly_briefing_service.dart';

class MonthlyBriefingScreen extends StatefulWidget {
  const MonthlyBriefingScreen({
    super.key,
  });

  @override
  State<MonthlyBriefingScreen> createState() {
    return _MonthlyBriefingScreenState();
  }
}

class _MonthlyBriefingScreenState extends State<MonthlyBriefingScreen> {
  final MonthlyBriefingService _briefingService =
  MonthlyBriefingService();

  DateTime _selectedMonth = DateTime.now();

  late Future<MonthlyBriefingModel> _briefingFuture;

  @override
  void initState() {
    super.initState();
    _loadMonthlyBriefing();
  }

  String get _selectedMonthTitle {
    return '${_selectedMonth.month}월 브리핑';
  }

  bool get _canMoveNextMonth {
    final DateTime now = DateTime.now();

    final DateTime selected = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final DateTime current = DateTime(
      now.year,
      now.month,
    );

    return selected.isBefore(current);
  }

  void _loadMonthlyBriefing() {
    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      _briefingFuture = Future<MonthlyBriefingModel>.error(
        '로그인된 사용자가 없습니다.',
      );

      return;
    }

    _briefingFuture = _briefingService.getMonthlyBriefing(
      userId: currentUser.uid,
      selectedMonth: _selectedMonth,
    );
  }

  void _movePreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
        1,
      );

      _loadMonthlyBriefing();
    });
  }

  void _moveNextMonth() {
    if (!_canMoveNextMonth) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      _loadMonthlyBriefing();
    });
  }

  void _moveCurrentMonth() {
    final DateTime now = DateTime.now();

    setState(() {
      _selectedMonth = DateTime(
        now.year,
        now.month,
        1,
      );

      _loadMonthlyBriefing();
    });
  }

  Future<void> _refreshMonthlyBriefing() async {
    setState(() {
      _loadMonthlyBriefing();
    });

    await _briefingFuture;
  }

  String _formatCurrency(num amount) {
    return NumberFormat.decimalPattern().format(
      amount.round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).maybePop();
          },
          icon: const Icon(
            Icons.chevron_left_rounded,
            size: 30,
            color: Color(0xFF222222),
          ),
        ),
        title: Text(
          _selectedMonthTitle,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF222222),
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showMonthBottomSheet,
            icon: const Icon(
              Icons.more_horiz,
              color: Color(0xFF555555),
            ),
          ),
        ],
      ),
      body: FutureBuilder<MonthlyBriefingModel>(
        future: _briefingFuture,
        builder: (
            BuildContext context,
            AsyncSnapshot<MonthlyBriefingModel> snapshot,
            ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorView(
              snapshot.error.toString(),
            );
          }

          final MonthlyBriefingModel? briefing = snapshot.data;

          if (briefing == null) {
            return const Center(
              child: Text(
                '월간 브리핑 데이터가 없습니다.',
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshMonthlyBriefing,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                32,
              ),
              children: [
                _buildCoachMessageCard(
                  briefing,
                ),
                const SizedBox(height: 12),
                _buildMonthlySummaryCard(
                  briefing,
                ),
                const SizedBox(height: 12),
                _buildTopCategoryCard(
                  briefing,
                ),
                const SizedBox(height: 12),
                _buildBudgetComparisonCard(
                  briefing,
                ),
                const SizedBox(height: 12),
                _buildConsumptionAnalysisCard(
                  briefing,
                ),
                const SizedBox(height: 18),
                _buildAiConsultButton(
                  briefing,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoachMessageCard(
      MonthlyBriefingModel briefing,
      ) {
    String message;

    if (briefing.totalSpent <= 0) {
      message = '이번 달에는 아직 등록된 지출이 없어요.';
    } else if (briefing.totalBudget <= 0) {
      message = '이번 달 예산을 설정하고 소비를 관리해 보세요!';
    } else if (briefing.isOverBudget) {
      message =
      '이번 달 계획보다 '
          '${_formatCurrency(briefing.overBudgetAmount)}원 더 소비했어요.';
    } else {
      message =
      '이번 달 예산의 '
          '${briefing.budgetUsageRate.toStringAsFixed(0)}%를 사용했어요.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Text(
              '🐷',
              style: TextStyle(
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE66C8E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard(
      MonthlyBriefingModel briefing,
      ) {
    return _buildWhiteCard(
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              title: '이번 달 총 지출',
              value: '${_formatCurrency(briefing.totalSpent)}원',
              valueColor: const Color(0xFF222222),
            ),
          ),
          Container(
            width: 1,
            height: 46,
            color: const Color(0xFFEEEEEE),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _buildSummaryItem(
              title: '예산 대비',
              value:
              '${briefing.budgetUsageRate.toStringAsFixed(0)}%',
              valueColor: briefing.isOverBudget
                  ? const Color(0xFFE75F79)
                  : const Color(0xFF45C2A0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF999999),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTopCategoryCard(
      MonthlyBriefingModel briefing,
      ) {
    final List<MapEntry<String, int>> categoryEntries =
    briefing.categoryAmounts.entries.toList();

    categoryEntries.sort(
          (
          MapEntry<String, int> first,
          MapEntry<String, int> second,
          ) {
        return second.value.compareTo(first.value);
      },
    );

    final List<MapEntry<String, int>> topEntries =
    categoryEntries.take(5).toList();

    return _buildWhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 TOP 지출',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 14),
          if (topEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 24,
              ),
              child: Center(
                child: Text(
                  '등록된 지출 데이터가 없습니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF999999),
                  ),
                ),
              ),
            )
          else
            ...List.generate(
              topEntries.length,
                  (int index) {
                final MapEntry<String, int> entry =
                topEntries[index];

                return _buildCategoryRow(
                  rank: index + 1,
                  categoryName: entry.key,
                  amount: entry.value,
                  showDivider: index != topEntries.length - 1,
                );
              },
            ),
          if (categoryEntries.length > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {
                  _showAllCategories(
                    briefing,
                  );
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '더보기',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF999999),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: Color(0xFF999999),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow({
    required int rank,
    required String categoryName,
    required int amount,
    bool showDivider = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 9,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 23,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: rank <= 3
                        ? const Color(0xFFE66C8E)
                        : const Color(0xFF999999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _getCategoryBackgroundColor(
                    categoryName,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _getCategoryEmoji(
                    categoryName,
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444444),
                  ),
                ),
              ),
              Text(
                '${_formatCurrency(amount)}원',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            color: Color(0xFFF1F1F1),
          ),
      ],
    );
  }

  Widget _buildBudgetComparisonCard(
      MonthlyBriefingModel briefing,
      ) {
    final num budget = briefing.totalBudget;
    final num spent = briefing.totalSpent;

    final double progress = budget <= 0
        ? 0.0
        : (spent / budget).clamp(0.0, 1.0).toDouble();

    return _buildWhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 예산 사용 현황',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                '사용 금액',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF888888),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatCurrency(spent)}원',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE66C8E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 11,
              backgroundColor: const Color(0xFFF1EEF1),
              valueColor: AlwaysStoppedAnimation<Color>(
                briefing.isOverBudget
                    ? const Color(0xFFE75F79)
                    : const Color(0xFFEC86A4),
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Text(
                budget <= 0
                    ? '예산이 설정되지 않았어요.'
                    : '예산 ${_formatCurrency(budget)}원',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF999999),
                ),
              ),
              const Spacer(),
              if (budget > 0)
                Text(
                  '${briefing.budgetUsageRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: briefing.isOverBudget
                        ? const Color(0xFFE75F79)
                        : const Color(0xFF777777),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: briefing.isOverBudget
                  ? const Color(0xFFFFEDF2)
                  : const Color(0xFFEAF8F4),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              _getBudgetMessage(
                briefing,
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: briefing.isOverBudget
                    ? const Color(0xFFE66C8E)
                    : const Color(0xFF47B99B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getBudgetMessage(
      MonthlyBriefingModel briefing,
      ) {
    if (briefing.totalSpent <= 0) {
      return '지출을 입력하면 예산 사용 현황을 확인할 수 있어요.';
    }

    if (briefing.totalBudget <= 0) {
      return '예산을 설정하면 소비 현황을 더 정확하게 분석해 드려요.';
    }

    if (briefing.isOverBudget) {
      return '예산보다 '
          '${_formatCurrency(briefing.overBudgetAmount)}원 더 사용했어요.';
    }

    return '예산이 '
        '${_formatCurrency(briefing.remainingBudget)}원 남았어요.';
  }

  Widget _buildConsumptionAnalysisCard(
      MonthlyBriefingModel briefing,
      ) {
    String title;
    String description;
    IconData icon;
    Color backgroundColor;
    Color iconColor;

    if (briefing.totalSpent <= 0) {
      title = '아직 소비 분석 데이터가 없어요';
      description = '지출 내역을 등록하면 소비 습관을 분석해 드릴게요.';
      icon = Icons.receipt_long_outlined;
      backgroundColor = const Color(0xFFF2F1F4);
      iconColor = const Color(0xFF999999);
    } else if (briefing.isOverBudget) {
      title = '소비 관리가 필요해요';
      description = briefing.topCategoryName == null
          ? '예산을 초과했어요. 남은 기간에는 지출을 줄여보세요.'
          : '${briefing.topCategoryName} 항목의 지출이 가장 많아요. '
          '해당 소비를 줄여보세요.';
      icon = Icons.warning_amber_rounded;
      backgroundColor = const Color(0xFFFFEDF2);
      iconColor = const Color(0xFFE66C8E);
    } else if (briefing.budgetUsageRate >= 80) {
      title = '예산이 얼마 남지 않았어요';
      description =
      '현재 예산의 '
          '${briefing.budgetUsageRate.toStringAsFixed(0)}%를 사용했어요.';
      icon = Icons.notifications_none_rounded;
      backgroundColor = const Color(0xFFFFF4DF);
      iconColor = const Color(0xFFE2A13C);
    } else {
      title = '안정적으로 소비하고 있어요';
      description = briefing.topCategoryName == null
          ? '현재까지 예산 범위 안에서 소비하고 있어요.'
          : '${briefing.topCategoryName} 항목의 지출이 가장 많았어요.';
      icon = Icons.auto_awesome_rounded;
      backgroundColor = const Color(0xFFEAF8F4);
      iconColor = const Color(0xFF47B99B);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 25,
            color: iconColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Color(0xFF777777),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiConsultButton(
      MonthlyBriefingModel briefing,
      ) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          _openAiConsultation(
            briefing,
          );
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF151515),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'AI에게 상담 받기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _openAiConsultation(
      MonthlyBriefingModel briefing,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${briefing.monthKey} 소비 데이터를 기준으로 상담을 시작합니다.',
          ),
        ),
      );
  }

  Widget _buildWhiteCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Color _getCategoryBackgroundColor(
      String categoryName,
      ) {
    if (categoryName.contains('식') ||
        categoryName.contains('외식')) {
      return const Color(0xFFFFF3D8);
    }

    if (categoryName.contains('쇼핑') ||
        categoryName.contains('의류')) {
      return const Color(0xFFFFE7EF);
    }

    if (categoryName.contains('교통') ||
        categoryName.contains('자동차')) {
      return const Color(0xFFE6F0FF);
    }

    if (categoryName.contains('카페') ||
        categoryName.contains('커피')) {
      return const Color(0xFFFFEEE3);
    }

    if (categoryName.contains('의료') ||
        categoryName.contains('병원')) {
      return const Color(0xFFEAF8F4);
    }

    return const Color(0xFFF0ECFF);
  }

  String _getCategoryEmoji(
      String categoryName,
      ) {
    if (categoryName.contains('식') ||
        categoryName.contains('외식')) {
      return '🍽️';
    }

    if (categoryName.contains('쇼핑') ||
        categoryName.contains('의류')) {
      return '🛍️';
    }

    if (categoryName.contains('교통') ||
        categoryName.contains('자동차')) {
      return '🚗';
    }

    if (categoryName.contains('카페') ||
        categoryName.contains('커피')) {
      return '☕';
    }

    if (categoryName.contains('의료') ||
        categoryName.contains('병원')) {
      return '💊';
    }

    if (categoryName.contains('주거') ||
        categoryName.contains('생활')) {
      return '🏠';
    }

    if (categoryName.contains('여가') ||
        categoryName.contains('문화')) {
      return '🎬';
    }

    if (categoryName.contains('교육')) {
      return '📚';
    }

    return '💳';
  }

  void _showAllCategories(
      MonthlyBriefingModel briefing,
      ) {
    final List<MapEntry<String, int>> categoryEntries =
    briefing.categoryAmounts.entries.toList();

    categoryEntries.sort(
          (
          MapEntry<String, int> first,
          MapEntry<String, int> second,
          ) {
        return second.value.compareTo(first.value);
      },
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (
          BuildContext bottomSheetContext,
          ) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20,
              ),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDADADA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '전체 카테고리 지출',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: categoryEntries.isEmpty
                        ? const Center(
                      child: Text(
                        '등록된 지출 데이터가 없습니다.',
                      ),
                    )
                        : ListView.builder(
                      itemCount: categoryEntries.length,
                      itemBuilder: (
                          BuildContext context,
                          int index,
                          ) {
                        final MapEntry<String, int> entry =
                        categoryEntries[index];

                        return _buildCategoryRow(
                          rank: index + 1,
                          categoryName: entry.key,
                          amount: entry.value,
                          showDivider:
                          index != categoryEntries.length - 1,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMonthBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (
          BuildContext bottomSheetContext,
          ) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDADADA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '조회할 월 선택',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(
                    Icons.chevron_left_rounded,
                  ),
                  title: const Text(
                    '이전 달 보기',
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _movePreviousMonth();
                  },
                ),
                ListTile(
                  enabled: _canMoveNextMonth,
                  leading: const Icon(
                    Icons.chevron_right_rounded,
                  ),
                  title: const Text(
                    '다음 달 보기',
                  ),
                  onTap: _canMoveNextMonth
                      ? () {
                    Navigator.of(bottomSheetContext).pop();
                    _moveNextMonth();
                  }
                      : null,
                ),
                ListTile(
                  leading: const Icon(
                    Icons.today_rounded,
                  ),
                  title: const Text(
                    '이번 달로 이동',
                  ),
                  onTap: () {
                    Navigator.of(bottomSheetContext).pop();
                    _moveCurrentMonth();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(
      String error,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 58,
              color: Color(0xFFE96D86),
            ),
            const SizedBox(height: 16),
            const Text(
              '월간 브리핑을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF888888),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _loadMonthlyBriefing();
                });
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                '다시 시도',
              ),
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFFEA7A99),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}