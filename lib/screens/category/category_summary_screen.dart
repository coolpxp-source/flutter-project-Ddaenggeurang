import 'package:flutter/material.dart';

import '../../models/category_summary_model.dart';
import '../../services/category_summary_service.dart';

/// 일간/주간/월간 카테고리별 지출을 확인하는 화면
///
/// CategorySummaryService에서 현재 기간과 이전 기간의 집계 결과를 받아
/// 총지출, 증감률, 카테고리 비율을 한 화면에 보여준다.
class CategorySummaryScreen extends StatefulWidget {
  final String userId;

  const CategorySummaryScreen({
    super.key,
    required this.userId,
  });

  @override
  State<CategorySummaryScreen> createState() => _CategorySummaryScreenState();
}

class _CategorySummaryScreenState extends State<CategorySummaryScreen> {
  final CategorySummaryService _categorySummaryService =
  CategorySummaryService();

  /// 화면에 처음 들어오면 이번 달 통계를 보여준다.
  CategorySummaryPeriod _selectedPeriod = CategorySummaryPeriod.month;
  DateTime _selectedDate = DateTime.now();

  CategorySummaryPeriodResult? _result;

  bool _isLoading = true;
  String? _errorMessage;

  /// 빠르게 탭을 바꿨을 때 이전 요청 결과가 나중에 덮어쓰는 것을 방지한다.
  int _requestId = 0;

  static const Color _primaryColor = Color(0xFF101828);
  static const Color _backgroundColor = Color(0xFFF8F9FB);
  static const Color _borderColor = Color(0xFFEAECF0);
  static const Color _subTextColor = Color(0xFF667085);

  /// 카테고리 구성 막대와 목록에 사용할 색상
  static const List<Color> _categoryColors = <Color>[
    Color(0xFF12B76A),
    Color(0xFFF97066),
    Color(0xFF9B8AFB),
    Color(0xFFFDB022),
    Color(0xFF2E90FA),
    Color(0xFFF670C7),
    Color(0xFF36BFFA),
    Color(0xFF7F56D9),
  ];

  @override
  void initState() {
    super.initState();
    _loadCategorySummary();
  }

  /// 선택한 날짜와 기간에 맞는 카테고리 집계를 불러온다.
  Future<void> _loadCategorySummary() async {
    final int currentRequestId = ++_requestId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final CategorySummaryPeriodResult result =
      await _categorySummaryService.getCategorySummaryByPeriod(
        userId: widget.userId,
        selectedDate: _selectedDate,
        period: _selectedPeriod,
      );

      if (!mounted || currentRequestId != _requestId) {
        return;
      }

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || currentRequestId != _requestId) {
        return;
      }

      setState(() {
        _result = null;
        _isLoading = false;
        _errorMessage = '카테고리별 지출을 불러오지 못했습니다.\n$error';
      });
    }
  }

  /// 일간/주간/월간 탭을 변경한다.
  void _changePeriod(CategorySummaryPeriod period) {
    if (_selectedPeriod == period) {
      return;
    }

    setState(() {
      _selectedPeriod = period;
    });

    _loadCategorySummary();
  }

  /// 이전 또는 다음 기간으로 이동한다.
  void _movePeriod(int direction) {
    if (direction > 0 && !_canMoveNext) {
      return;
    }

    setState(() {
      switch (_selectedPeriod) {
        case CategorySummaryPeriod.day:
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;

        case CategorySummaryPeriod.week:
          _selectedDate = _selectedDate.add(Duration(days: 7 * direction));
          break;

        case CategorySummaryPeriod.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + direction,
            1,
          );
          break;
      }
    });

    _loadCategorySummary();
  }

  /// 현재 기간을 보고 있을 때는 미래 기간으로 이동하지 못하게 한다.
  bool get _canMoveNext {
    final DateTime now = DateTime.now();

    switch (_selectedPeriod) {
      case CategorySummaryPeriod.day:
        return !_isSameDay(_selectedDate, now);

      case CategorySummaryPeriod.week:
        return !_isSameWeek(_selectedDate, now);

      case CategorySummaryPeriod.month:
        return _selectedDate.year != now.year ||
            _selectedDate.month != now.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '카테고리 지출',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _primaryColor,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCategorySummary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: <Widget>[
              _buildPeriodTabs(),
              const SizedBox(height: 18),
              _buildDateSelector(),
              const SizedBox(height: 18),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  /// 일간/주간/월간 선택 탭
  Widget _buildPeriodTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: CategorySummaryPeriod.values.map(
              (CategorySummaryPeriod period) {
            final bool isSelected = _selectedPeriod == period;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _changePeriod(period),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: isSelected
                        ? const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Text(
                    _periodTabText(period),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                      isSelected ? _primaryColor : const Color(0xFF98A2B3),
                    ),
                  ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  /// 조회 중인 날짜 또는 기간과 이동 버튼
  Widget _buildDateSelector() {
    return Row(
      children: <Widget>[
        _buildArrowButton(
          icon: Icons.chevron_left_rounded,
          onPressed: () => _movePeriod(-1),
        ),
        Expanded(
          child: Text(
            _selectedDateText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ),
        _buildArrowButton(
          icon: Icons.chevron_right_rounded,
          onPressed: _canMoveNext ? () => _movePeriod(1) : null,
        ),
      ],
    );
  }

  Widget _buildArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon),
        color: _primaryColor,
        disabledColor: const Color(0xFFD0D5DD),
      ),
    );
  }

  /// 로딩, 오류, 정상 결과를 상태에 맞게 표시한다.
  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 100),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF12B76A),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorCard();
    }

    final CategorySummaryPeriodResult? result = _result;

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildTotalSection(result),
        const SizedBox(height: 24),
        if (result.summaries.isEmpty)
          _buildEmptyCard()
        else ...<Widget>[
          _buildCategoryShareBar(result.summaries),
          const SizedBox(height: 26),
          const Text(
            '카테고리별 지출',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildCategoryList(result.summaries),
          const SizedBox(height: 16),
          _buildGuideBox(result.summaries.first),
        ],
      ],
    );
  }

  /// 선택한 기간의 총지출과 이전 기간 비교 문구
  Widget _buildTotalSection(CategorySummaryPeriodResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_selectedPeriodLabel} 총지출',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _subTextColor,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${_formatAmount(result.totalAmount)}원',
            style: const TextStyle(
              fontSize: 30,
              height: 1.2,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildComparisonBadge(result),
        ],
      ),
    );
  }

  /// 이전 기간보다 증가했는지 감소했는지 보여주는 배지
  Widget _buildComparisonBadge(CategorySummaryPeriodResult result) {
    final double? changeRate = result.changeRate;

    if (changeRate == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          result.totalAmount == 0
              ? '$_previousPeriodLabel에도 지출이 없어요'
              : '$_previousPeriodLabel 비교 데이터가 없어요',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _subTextColor,
          ),
        ),
      );
    }

    final bool isIncrease = changeRate > 0;
    final bool isDecrease = changeRate < 0;

    final Color badgeColor = isIncrease
        ? const Color(0xFFF04438)
        : isDecrease
        ? const Color(0xFF12B76A)
        : _subTextColor;

    final Color badgeBackgroundColor = isIncrease
        ? const Color(0xFFFEF3F2)
        : isDecrease
        ? const Color(0xFFECFDF3)
        : const Color(0xFFF2F4F7);

    final IconData badgeIcon = isIncrease
        ? Icons.arrow_upward_rounded
        : isDecrease
        ? Icons.arrow_downward_rounded
        : Icons.remove_rounded;

    final String comparisonText = changeRate == 0
        ? '$_previousPeriodLabel과 지출이 같아요'
        : '$_previousPeriodLabel보다 ${changeRate.abs().toStringAsFixed(1)}% '
        '${isIncrease ? '늘었어요' : '줄었어요'}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: badgeBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            badgeIcon,
            size: 14,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            comparisonText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 카테고리 비율을 한눈에 볼 수 있는 다색 막대
  Widget _buildCategoryShareBar(List<CategorySummaryModel> summaries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '지출 구성',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _subTextColor,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(
              children: List<Widget>.generate(
                summaries.length,
                    (int index) {
                  final CategorySummaryModel summary = summaries[index];

                  return Expanded(
                    flex: summary.percentage.round().clamp(1, 100).toInt(),
                    child: Container(
                      color: _categoryColor(summary.categoryKey, index),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 카테고리 집계 목록
  Widget _buildCategoryList(List<CategorySummaryModel> summaries) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: List<Widget>.generate(
          summaries.length,
              (int index) {
            final CategorySummaryModel summary = summaries[index];

            return Column(
              children: <Widget>[
                _buildCategoryRow(
                  summary: summary,
                  index: index,
                ),
                if (index != summaries.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    color: Color(0xFFF2F4F7),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryRow({
    required CategorySummaryModel summary,
    required int index,
  }) {
    final Color categoryColor = _categoryColor(
      summary.categoryKey,
      index,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: categoryColor.withAlpha(24),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _categoryIcon(summary.categoryKey),
              size: 19,
              color: categoryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              summary.categoryName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
          Text(
            '${summary.percentage.toStringAsFixed(1)}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _subTextColor,
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 92,
            child: Text(
              '${_formatAmount(summary.totalAmount)}원',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 지출 비중이 가장 높은 카테고리를 안내한다.
  Widget _buildGuideBox(CategorySummaryModel highestSummary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 18,
            color: Color(0xFFE31B54),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${highestSummary.categoryName} 지출이 전체의 '
                  '${highestSummary.percentage.toStringAsFixed(1)}%로 가장 높아요.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC01048),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: const Column(
        children: <Widget>[
          Icon(
            Icons.receipt_long_outlined,
            size: 46,
            color: Color(0xFF98A2B3),
          ),
          SizedBox(height: 13),
          Text(
            '등록된 지출이 없습니다.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF344054),
            ),
          ),
          SizedBox(height: 6),
          Text(
            '지출을 등록하면 카테고리별 통계를 확인할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF98A2B3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 44,
            color: Color(0xFFF04438),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: _subTextColor,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loadCategorySummary,
            style: FilledButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  /// 기간 탭에 표시할 이름
  String _periodTabText(CategorySummaryPeriod period) {
    switch (period) {
      case CategorySummaryPeriod.day:
        return '일간';
      case CategorySummaryPeriod.week:
        return '주간';
      case CategorySummaryPeriod.month:
        return '월간';
    }
  }

  /// 총지출 위에 표시할 기간 이름
  String get _selectedPeriodLabel {
    final DateTime now = DateTime.now();

    switch (_selectedPeriod) {
      case CategorySummaryPeriod.day:
        return _isSameDay(_selectedDate, now) ? '오늘' : '선택한 날';

      case CategorySummaryPeriod.week:
        return _isSameWeek(_selectedDate, now) ? '이번 주' : '선택한 주';

      case CategorySummaryPeriod.month:
        final bool isCurrentMonth = _selectedDate.year == now.year &&
            _selectedDate.month == now.month;

        return isCurrentMonth ? '이번 달' : '선택한 달';
    }
  }

  /// 이전 기간 비교 문구
  String get _previousPeriodLabel {
    final DateTime now = DateTime.now();

    switch (_selectedPeriod) {
      case CategorySummaryPeriod.day:
        return _isSameDay(_selectedDate, now) ? '어제' : '전날';

      case CategorySummaryPeriod.week:
        return _isSameWeek(_selectedDate, now) ? '지난주' : '이전 주';

      case CategorySummaryPeriod.month:
        final bool isCurrentMonth = _selectedDate.year == now.year &&
            _selectedDate.month == now.month;

        return isCurrentMonth ? '지난달' : '이전 달';
    }
  }

  /// 날짜 이동 영역에 표시할 텍스트
  String get _selectedDateText {
    switch (_selectedPeriod) {
      case CategorySummaryPeriod.day:
        return '${_selectedDate.year}년 '
            '${_selectedDate.month}월 ${_selectedDate.day}일';

      case CategorySummaryPeriod.week:
        final DateTime weekStart = _selectedDate.subtract(
          Duration(days: _selectedDate.weekday - DateTime.monday),
        );
        final DateTime weekEnd = weekStart.add(const Duration(days: 6));

        if (weekStart.year == weekEnd.year) {
          return '${weekStart.year}년 '
              '${weekStart.month}월 ${weekStart.day}일'
              ' - ${weekEnd.month}월 ${weekEnd.day}일';
        }

        return '${weekStart.year}.${weekStart.month}.${weekStart.day}'
            ' - ${weekEnd.year}.${weekEnd.month}.${weekEnd.day}';

      case CategorySummaryPeriod.month:
        return '${_selectedDate.year}년 ${_selectedDate.month}월';
    }
  }

  /// categoryKey에 맞는 대표 아이콘
  IconData _categoryIcon(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'food':
      case 'meal':
        return Icons.restaurant_outlined;

      case 'transport':
      case 'traffic':
        return Icons.directions_bus_outlined;

      case 'shopping':
        return Icons.shopping_bag_outlined;

      case 'culture':
      case 'entertainment':
        return Icons.movie_outlined;

      case 'housing':
      case 'living':
        return Icons.home_outlined;

      case 'cafe':
        return Icons.local_cafe_outlined;

      case 'medical':
      case 'health':
        return Icons.medical_services_outlined;

      case 'education':
        return Icons.school_outlined;

      case 'travel':
        return Icons.flight_outlined;

      default:
        return Icons.more_horiz_rounded;
    }
  }

  /// 같은 카테고리가 항상 비슷한 색상을 사용하도록 색상을 선택한다.
  Color _categoryColor(String categoryKey, int index) {
    if (categoryKey.isEmpty) {
      return _categoryColors[index % _categoryColors.length];
    }

    final int colorIndex =
    categoryKey.codeUnits.fold<int>(0, (int sum, int code) => sum + code);

    return _categoryColors[colorIndex % _categoryColors.length];
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  bool _isSameWeek(DateTime first, DateTime second) {
    final DateTime firstWeekStart = DateTime(
      first.year,
      first.month,
      first.day,
    ).subtract(
      Duration(days: first.weekday - DateTime.monday),
    );

    final DateTime secondWeekStart = DateTime(
      second.year,
      second.month,
      second.day,
    ).subtract(
      Duration(days: second.weekday - DateTime.monday),
    );

    return _isSameDay(firstWeekStart, secondWeekStart);
  }

  /// 금액에 천 단위 쉼표를 넣는다.
  static String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match match) => '${match[1]},',
    );
  }
}
