import 'package:flutter/material.dart';

import '../../models/travel_expense_model.dart';
import '../../models/travel_model.dart';
import '../../services/travel_expense_service.dart';
import '../../services/travel_service.dart';

class TravelReportScreen extends StatefulWidget {
  const TravelReportScreen({
    super.key,
    required this.travelId,
  });

  /// 조회할 여행의 Firestore 문서 ID
  final String travelId;

  @override
  State<TravelReportScreen> createState() =>
      _TravelReportScreenState();
}

class _TravelReportScreenState extends State<TravelReportScreen> {
  final TravelService _travelService = TravelService();

  final TravelExpenseService _expenseService =
  TravelExpenseService();

  TravelModel? _travel;

  List<TravelExpenseModel> _expenses = [];

  bool _isLoading = true;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  /// 여행 정보와 지출 목록 조회
  Future<void> _loadReport() async {
    final String travelId = widget.travelId.trim();

    if (travelId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '여행 ID가 없습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<dynamic> results = await Future.wait([
        _travelService.getTravelById(travelId),
        _expenseService.getExpensesByTravelId(travelId),
      ]);

      final TravelModel? travel =
      results[0] as TravelModel?;

      final List<TravelExpenseModel> expenses =
      List<TravelExpenseModel>.from(
        results[1] as List<TravelExpenseModel>,
      );

      // 최신 지출 순서로 정렬
      expenses.sort(
            (
            TravelExpenseModel a,
            TravelExpenseModel b,
            ) {
          return b.expenseDate.compareTo(a.expenseDate);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _travel = travel;
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('여행 리포트 조회 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
        '여행 리포트를 불러오지 못했습니다.\n$error';
      });
    }
  }

  /// 전체 지출
  int get _totalExpenseAmount {
    return _expenses.fold<int>(
      0,
          (
          int total,
          TravelExpenseModel expense,
          ) {
        return total + expense.amount;
      },
    );
  }

  /// 여행 예산
  int get _budgetAmount {
    return _travel?.budgetAmount ?? 0;
  }

  /// 남은 예산
  ///
  /// 예산을 초과하면 음수가 반환된다.
  int get _remainingBudget {
    return _budgetAmount - _totalExpenseAmount;
  }

  /// 예산 사용률
  double get _budgetUsageRate {
    if (_budgetAmount <= 0) {
      return 0;
    }

    return _totalExpenseAmount / _budgetAmount;
  }

  /// ProgressIndicator에 사용할 값
  double get _budgetProgressValue {
    return _budgetUsageRate.clamp(0.0, 1.0).toDouble();
  }

  /// 여행 일수
  int get _travelDays {
    final TravelModel? travel = _travel;

    if (travel == null) {
      return 0;
    }

    final DateTime startDate = DateTime(
      travel.startDate.year,
      travel.startDate.month,
      travel.startDate.day,
    );

    final DateTime endDate = DateTime(
      travel.endDate.year,
      travel.endDate.month,
      travel.endDate.day,
    );

    final int days =
        endDate.difference(startDate).inDays + 1;

    return days < 1 ? 1 : days;
  }

  /// 하루 평균 지출
  int get _dailyAverageExpense {
    if (_travelDays <= 0) {
      return 0;
    }

    return _totalExpenseAmount ~/ _travelDays;
  }

  /// 카테고리별 지출 합계
  Map<String, int> get _categoryTotals {
    final Map<String, int> totals = {};

    for (final TravelExpenseModel expense in _expenses) {
      final String category =
      expense.category.trim().isEmpty
          ? '기타'
          : expense.category.trim();

      totals.update(
        category,
            (int currentAmount) {
          return currentAmount + expense.amount;
        },
        ifAbsent: () {
          return expense.amount;
        },
      );
    }

    final List<MapEntry<String, int>> entries =
    totals.entries.toList()
      ..sort(
            (
            MapEntry<String, int> a,
            MapEntry<String, int> b,
            ) {
          return b.value.compareTo(a.value);
        },
      );

    return Map<String, int>.fromEntries(entries);
  }

  /// 가장 많이 지출한 카테고리
  String get _topCategory {
    if (_categoryTotals.isEmpty) {
      return '지출 없음';
    }

    return _categoryTotals.entries.first.key;
  }

  /// 가장 많이 지출한 카테고리 금액
  int get _topCategoryAmount {
    if (_categoryTotals.isEmpty) {
      return 0;
    }

    return _categoryTotals.entries.first.value;
  }

  /// 카테고리 비율
  double _getCategoryRate(int categoryAmount) {
    if (_totalExpenseAmount <= 0) {
      return 0;
    }

    return categoryAmount / _totalExpenseAmount;
  }

  /// 금액 천 단위 쉼표
  String _formatMoney(int amount) {
    final bool isNegative = amount < 0;
    final String value = amount.abs().toString();
    final StringBuffer result = StringBuffer();

    for (int index = 0; index < value.length; index++) {
      if (index > 0 &&
          (value.length - index) % 3 == 0) {
        result.write(',');
      }

      result.write(value[index]);
    }

    return isNegative
        ? '-${result.toString()}'
        : result.toString();
  }

  /// 날짜 표시
  String _formatDate(DateTime date) {
    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  /// 카테고리별 아이콘
  IconData _getCategoryIcon(String category) {
    switch (category.trim()) {
      case '식비':
        return Icons.restaurant_rounded;

      case '교통':
      case '교통비':
        return Icons.directions_bus_rounded;

      case '숙박':
      case '숙박비':
        return Icons.hotel_rounded;

      case '쇼핑':
        return Icons.shopping_bag_rounded;

      case '관광':
      case '관광비':
        return Icons.attractions_rounded;

      case '카페':
        return Icons.local_cafe_rounded;

      case '항공':
      case '항공권':
        return Icons.flight_rounded;

      case '주유':
      case '주유비':
        return Icons.local_gas_station_rounded;

      case '기타':
        return Icons.more_horiz_rounded;

      default:
        return Icons.receipt_long_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text(
          '여행 리포트',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadReport,
            tooltip: '새로고침',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE66C8E),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_travel == null) {
      return _buildEmptyTravelView();
    }

    return RefreshIndicator(
      color: const Color(0xFFE66C8E),
      onRefresh: _loadReport,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          40,
        ),
        children: [
          _buildTravelHeaderCard(),

          const SizedBox(height: 18),

          _buildBudgetSummaryCard(),

          const SizedBox(height: 26),

          _buildSectionTitle(
            title: '지출 요약',
            description: '여행 지출을 한눈에 확인해 보세요.',
          ),

          const SizedBox(height: 12),

          _buildStatisticGrid(),

          if (_expenses.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildTopCategoryCard(),
          ],

          const SizedBox(height: 26),

          _buildSectionTitle(
            title: '카테고리별 지출',
            description: '${_categoryTotals.length}개 카테고리',
          ),

          const SizedBox(height: 12),

          _buildCategorySection(),

          const SizedBox(height: 26),

          _buildSectionTitle(
            title: '지출 내역',
            description: '총 ${_expenses.length}건',
          ),

          const SizedBox(height: 12),

          _buildExpenseList(),
        ],
      ),
    );
  }

  /// 여행 정보 카드
  Widget _buildTravelHeaderCard() {
    final TravelModel travel = _travel!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Text(
              '✈️',
              style: TextStyle(
                fontSize: 29,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  travel.title.trim().isEmpty
                      ? '제목 없는 여행'
                      : travel.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${_formatDate(travel.startDate)}'
                      ' ~ '
                      '${_formatDate(travel.endDate)}',
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '총 $_travelDays일 여행',
                  style: const TextStyle(
                    color: Color(0xFFE66C8E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 예산 사용 현황
  Widget _buildBudgetSummaryCard() {
    final bool hasBudget = _budgetAmount > 0;
    final bool isOverBudget =
        hasBudget && _remainingBudget < 0;

    final Color progressColor = isOverBudget
        ? Colors.redAccent
        : const Color(0xFFE66C8E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '예산 사용 현황',
            style: TextStyle(
              color: Color(0xFF333333),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildMoneyColumn(
                  title: '전체 예산',
                  amount:
                  hasBudget ? _budgetAmount : null,
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildMoneyColumn(
                  title: '총지출',
                  amount: _totalExpenseAmount,
                  amountColor:
                  const Color(0xFFE66C8E),
                ),
              ),
              _buildVerticalDivider(),
              Expanded(
                child: _buildMoneyColumn(
                  title: isOverBudget
                      ? '초과 금액'
                      : '남은 예산',
                  amount: hasBudget
                      ? _remainingBudget.abs()
                      : null,
                  amountColor: isOverBudget
                      ? Colors.redAccent
                      : const Color(0xFF4E8B72),
                ),
              ),
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                minHeight: 10,
                value: _budgetProgressValue,
                backgroundColor:
                const Color(0xFFF2EEF1),
                valueColor:
                AlwaysStoppedAnimation<Color>(
                  progressColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '예산 사용률 '
                      '${(_budgetUsageRate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: isOverBudget
                        ? Colors.redAccent
                        : const Color(0xFF777777),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (isOverBudget)
                  const Text(
                    '예산을 초과했습니다.',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Text(
              '설정된 여행 예산이 없습니다.',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 38,
      color: const Color(0xFFF0EDF0),
    );
  }

  Widget _buildMoneyColumn({
    required String title,
    required int? amount,
    Color amountColor = const Color(0xFF333333),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 4,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              amount == null
                  ? '미설정'
                  : '${_formatMoney(amount)}원',
              maxLines: 1,
              style: TextStyle(
                color: amount == null
                    ? const Color(0xFFAAAAAA)
                    : amountColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 총지출, 하루 평균, 최다 지출
  Widget _buildStatisticGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatisticCard(
            icon: Icons.payments_rounded,
            title: '총지출',
            value:
            '${_formatMoney(_totalExpenseAmount)}원',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatisticCard(
            icon: Icons.calendar_today_rounded,
            title: '하루 평균',
            value:
            '${_formatMoney(_dailyAverageExpense)}원',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatisticCard(
            icon:
            Icons.local_fire_department_rounded,
            title: '최다 지출',
            value: _topCategory,
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 114,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 22,
            color: const Color(0xFFE66C8E),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// 최다 지출 카테고리 카드
  Widget _buildTopCategoryCard() {
    final double rate =
    _getCategoryRate(_topCategoryAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6F8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFDFE8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _getCategoryIcon(_topCategory),
              color: const Color(0xFFE66C8E),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  '가장 많이 사용한 항목',
                  style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _topCategory,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatMoney(_topCategoryAmount)}원',
                style: const TextStyle(
                  color: Color(0xFFE66C8E),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 카테고리별 지출
  Widget _buildCategorySection() {
    final List<MapEntry<String, int>> entries =
    _categoryTotals.entries.toList();

    if (entries.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.pie_chart_outline_rounded,
        message: '등록된 여행 지출이 없습니다.',
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: Column(
        children: List.generate(
          entries.length,
              (int index) {
            final MapEntry<String, int> entry =
            entries[index];

            final double rate =
            _getCategoryRate(entry.value);

            return Padding(
              padding: EdgeInsets.only(
                bottom:
                index == entries.length - 1 ? 0 : 18,
              ),
              child: _buildCategoryRow(
                category: entry.key,
                amount: entry.value,
                rate: rate,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryRow({
    required String category,
    required int amount,
    required double rate,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEDF2),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            _getCategoryIcon(category),
            size: 19,
            color: const Color(0xFFE66C8E),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        color: Color(0xFF444444),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatMoney(amount)}원',
                    style: const TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value:
                  rate.clamp(0.0, 1.0).toDouble(),
                  backgroundColor:
                  const Color(0xFFF2EEF1),
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(
                    Color(0xFFE66C8E),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 전체 지출 내역
  Widget _buildExpenseList() {
    if (_expenses.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.receipt_long_outlined,
        message: '아직 등록된 지출 내역이 없습니다.',
      );
    }

    return Column(
      children: List.generate(
        _expenses.length,
            (int index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom:
              index == _expenses.length - 1 ? 0 : 10,
            ),
            child: _buildExpenseItem(
              _expenses[index],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExpenseItem(
      TravelExpenseModel expense,
      ) {
    final String category =
    expense.category.trim().isEmpty
        ? '기타'
        : expense.category.trim();

    final String place = expense.place.trim();
    final String memo = expense.memo.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEDF2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getCategoryIcon(category),
              size: 21,
              color: const Color(0xFFE66C8E),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  place.isNotEmpty ? place : category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  [
                    category,
                    _formatDate(expense.expenseDate),
                    if (memo.isNotEmpty) memo,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '-${_formatMoney(expense.amount)}원',
            style: const TextStyle(
              color: Color(0xFFE66C8E),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: const Color(0xFFCCCCCC),
          ),
          const SizedBox(height: 11),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? '오류가 발생했습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF555555),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _loadReport,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFE66C8E),
                foregroundColor: Colors.white,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTravelView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.luggage_outlined,
              size: 50,
              color: Color(0xFFCCCCCC),
            ),
            const SizedBox(height: 14),
            const Text(
              '여행 정보를 찾을 수 없습니다.',
              style: TextStyle(
                color: Color(0xFF777777),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '여행 ID: ${widget.travelId}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFAAAAAA),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFE66C8E),
                foregroundColor: Colors.white,
              ),
              child: const Text('돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}