import 'package:flutter/material.dart';

import '../../models/category_summary_model.dart';
import '../../services/category_summary_service.dart';

class CategorySummaryScreen extends StatefulWidget {
  final String userId;

  const CategorySummaryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CategorySummaryScreen> createState() =>
      _CategorySummaryScreenState();
}

class _CategorySummaryScreenState
    extends State<CategorySummaryScreen> {
  final CategorySummaryService _categorySummaryService =
  CategorySummaryService();

  late DateTime _selectedMonth;

  List<CategorySummaryModel> _summaries = [];

  bool _isLoading = true;
  String? _errorMessage;

  int get _totalExpense {
    return _summaries.fold<int>(
      0,
          (int sum, CategorySummaryModel item) =>
      sum + item.totalAmount,
    );
  }

  String get _selectedMonthText {
    return '${_selectedMonth.year}년 ${_selectedMonth.month}월';
  }

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    _selectedMonth = DateTime(
      now.year,
      now.month,
    );

    _loadCategorySummary();
  }

  /// 카테고리별 지출 집계 불러오기
  Future<void> _loadCategorySummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<CategorySummaryModel> summaries =
      await _categorySummaryService.getCategorySummary(
        userId: widget.userId,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summaries = summaries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _summaries = [];
        _isLoading = false;
        _errorMessage = '카테고리별 지출을 불러오지 못했습니다.\n$e';
      });
    }
  }

  /// 이전 달로 이동
  void _moveToPreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });

    _loadCategorySummary();
  }

  /// 다음 달로 이동
  void _moveToNextMonth() {
    final DateTime now = DateTime.now();

    final DateTime nextMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
    );

    final DateTime currentMonth = DateTime(
      now.year,
      now.month,
    );

    // 현재 달보다 미래로 이동하지 못하게 처리
    if (nextMonth.isAfter(currentMonth)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다음 달 통계는 아직 확인할 수 없습니다.'),
        ),
      );
      return;
    }

    setState(() {
      _selectedMonth = nextMonth;
    });

    _loadCategorySummary();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          '카테고리별 집계',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCategorySummary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            children: [
              _buildMonthSelector(),
              const SizedBox(height: 16),
              _buildTotalExpenseCard(),
              const SizedBox(height: 16),
              _buildBody(),
            ],
          ),
        ),
      ),
    );
  }

  /// 월 선택 영역
  Widget _buildMonthSelector() {
    final DateTime now = DateTime.now();

    final bool isCurrentMonth =
        _selectedMonth.year == now.year &&
            _selectedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _moveToPreviousMonth,
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),
          Expanded(
            child: Text(
              _selectedMonthText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF101828),
              ),
            ),
          ),
          IconButton(
            onPressed:
            isCurrentMonth ? null : _moveToNextMonth,
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  /// 이번 달 총지출 카드
  Widget _buildTotalExpenseCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF101828),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 총지출',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFD0D5DD),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatAmount(_totalExpense)}원',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_summaries.length}개 카테고리에서 지출했어요.',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF98A2B3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 80,
        ),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE4E7EC),
          ),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 44,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadCategorySummary,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_summaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(
          vertical: 60,
          horizontal: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE4E7EC),
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: Color(0xFF98A2B3),
            ),
            SizedBox(height: 14),
            Text(
              '등록된 지출이 없습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF344054),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '지출을 등록하면 카테고리별 통계를 확인할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF98A2B3),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _summaries.map((CategorySummaryModel summary) {
        return _buildCategoryCard(summary);
      }).toList(),
    );
  }

  /// 카테고리 통계 카드
  Widget _buildCategoryCard(
      CategorySummaryModel summary,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                const Color(0xFFF0FDF4),
                child: Icon(
                  _getCategoryIcon(summary.categoryKey),
                  color: const Color(0xFF12B76A),
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.categoryName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF101828),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatAmount(summary.totalAmount)}원',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF101828),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (summary.percentage / 100)
                  .clamp(0.0, 1.0),
              minHeight: 9,
              backgroundColor:
              const Color(0xFFF2F4F7),
              valueColor:
              const AlwaysStoppedAnimation<Color>(
                Color(0xFF12B76A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryKey) {
    switch (categoryKey) {
      case 'food':
        return Icons.restaurant_outlined;

      case 'transport':
        return Icons.directions_bus_outlined;

      case 'shopping':
        return Icons.shopping_bag_outlined;

      case 'culture':
        return Icons.movie_outlined;

      case 'housing':
        return Icons.home_outlined;

      default:
        return Icons.more_horiz;
    }
  }

  static String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match match) => '${match[1]},',
    );
  }
}