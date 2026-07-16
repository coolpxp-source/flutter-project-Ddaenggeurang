import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/budget_vs_expense_model.dart';
import '../../services/budget_vs_expense_service.dart';

/// 예산 대비 지출 화면
///
/// 표시 내용:
/// - 월별 예산 사용률
/// - 실제 지출 / 설정 예산
/// - 오늘 날짜 기준 권장 소비 페이스
/// - 이번 달 예산
/// - 현재 지출
/// - 남은 예산
/// - 현재 소비 속도 기준 예상 총지출
class BudgetVsExpenseScreen extends StatefulWidget {
  /// 현재 로그인한 사용자의 Firebase UID
  final String userId;

  const BudgetVsExpenseScreen({
    super.key,
    required this.userId,
  });

  @override
  State<BudgetVsExpenseScreen> createState() {
    return _BudgetVsExpenseScreenState();
  }
}

class _BudgetVsExpenseScreenState
    extends State<BudgetVsExpenseScreen> {
  /// Firestore에서 예산과 지출 정보를 조회하는 서비스
  final BudgetVsExpenseService _service =
  BudgetVsExpenseService();

  /// 현재 화면에서 조회 중인 월
  DateTime _selectedMonth = DateTime.now();

  /// Firestore 문서 조회에 사용하는 월 키
  ///
  /// 예:
  /// 2026년 7월 → 2026-07
  String get _monthKey {
    final month = _selectedMonth.month
        .toString()
        .padLeft(2, '0');

    return '${_selectedMonth.year}-$month';
  }

  /// 해당 월의 마지막 날짜
  ///
  /// 예:
  /// 2026년 7월 → 31일
  int get _daysInSelectedMonth {
    return DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
  }

  /// 선택된 월을 기준으로 소비가 진행된 날짜 수
  int get _elapsedDays {
    final now = DateTime.now();

    final selectedMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );

    final currentMonth = DateTime(
      now.year,
      now.month,
    );

    // 과거 월은 마지막 날까지 모두 지난 것으로 계산
    if (selectedMonth.isBefore(currentMonth)) {
      return _daysInSelectedMonth;
    }

    // 미래 월은 아직 소비 기간이 시작되지 않은 것으로 계산
    if (selectedMonth.isAfter(currentMonth)) {
      return 0;
    }

    // 현재 월은 오늘 날짜까지 계산
    return now.day.clamp(
      1,
      _daysInSelectedMonth,
    );
  }

  /// 오늘 날짜 기준 권장 예산 사용률
  ///
  /// 예:
  /// 31일 중 16일이 지났다면 약 51.6%
  double get _recommendedPaceRate {
    if (_daysInSelectedMonth <= 0) {
      return 0.0;
    }

    return _elapsedDays / _daysInSelectedMonth;
  }

  /// 이전 달로 이동
  void _movePreviousMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 1,
      );
    });
  }

  /// 다음 달로 이동
  void _moveNextMonth() {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
      );
    });
  }

  /// 금액에 천 단위 쉼표를 추가한다.
  ///
  /// 예:
  /// 2000000 → 2,000,000
  String _formatAmount(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  /// 현재 소비 속도가 계속된다고 가정한 월말 예상 지출
  int _calculateExpectedTotalSpent(
      BudgetVsExpenseModel data,
      ) {
    if (data.totalSpent <= 0) {
      return 0;
    }

    if (_elapsedDays <= 0) {
      return 0;
    }

    // 일평균 지출
    final dailyAverage =
        data.totalSpent / _elapsedDays;

    // 일평균 지출 × 해당 월 전체 일수
    return (dailyAverage * _daysInSelectedMonth)
        .round();
  }

  /// 실제 사용률이 권장 소비 페이스보다 여유 있는지 판단
  bool _isPaceSafe(
      BudgetVsExpenseModel data,
      ) {
    return data.usageRate <=
        _recommendedPaceRate;
  }

  /// 소비 상태에 사용할 색상
  Color _getStatusColor(
      BudgetVsExpenseModel data,
      ) {
    if (data.isOverBudget) {
      return Colors.red;
    }

    if (_isPaceSafe(data)) {
      return const Color(0xFF159A28);
    }

    return Colors.orange;
  }

  /// 소비 상태 문구
  String _getStatusText(
      BudgetVsExpenseModel data,
      ) {
    if (data.totalBudget <= 0) {
      return '예산 미설정';
    }

    if (data.isOverBudget) {
      return '예산 초과';
    }

    if (_isPaceSafe(data)) {
      return '페이스보다 여유 있음';
    }

    return '페이스보다 빠름';
  }

  /// 예상 총지출 문구의 색상
  Color _getExpectedSpentColor(
      BudgetVsExpenseModel data,
      int expectedTotalSpent,
      ) {
    if (data.totalBudget <= 0) {
      return Colors.black87;
    }

    if (expectedTotalSpent > data.totalBudget) {
      return Colors.red;
    }

    return Colors.black87;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      appBar: AppBar(
        title: const Text(
          '예산 대비 지출',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),

      body: StreamBuilder<BudgetVsExpenseModel>(
        stream: _service.watchBudgetVsExpense(
          userId: widget.userId,
          monthKey: _monthKey,
        ),
        builder: (context, snapshot) {
          // Firestore 최초 조회 중
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Firestore 조회 실패
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '예산 정보를 불러오지 못했습니다.\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            );
          }

          // 문서가 없으면 0원으로 표시
          final data = snapshot.data ??
              const BudgetVsExpenseModel(
                totalBudget: 0,
                totalSpent: 0,
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              16,
              20,
              16,
              24,
            ),
            children: [
              // 월 변경 영역
              _buildMonthSelector(),

              const SizedBox(height: 14),

              // 예산 대비 지출 메인 카드
              _buildBudgetStatusCard(data),
            ],
          );
        },
      ),
    );
  }

  /// 이전 달과 다음 달을 선택하는 영역
  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _movePreviousMonth,
          icon: const Icon(
            Icons.chevron_left,
          ),
        ),
        SizedBox(
          width: 130,
          child: Text(
            '${_selectedMonth.year}년 '
                '${_selectedMonth.month}월',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _moveNextMonth,
          icon: const Icon(
            Icons.chevron_right,
          ),
        ),
      ],
    );
  }

  /// 예산 대비 지출 정보를 모두 보여주는 메인 카드
  Widget _buildBudgetStatusCard(
      BudgetVsExpenseModel data,
      ) {
    final statusColor =
    _getStatusColor(data);

    final usagePercentage =
        data.usageRate * 100;

    final recommendedPercentage =
        _recommendedPaceRate * 100;

    final expectedTotalSpent =
    _calculateExpectedTotalSpent(data);

    final paceMarkerValue =
    _recommendedPaceRate
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // 월별 지출 현황 제목과 상태 배지
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_selectedMonth.month}월 '
                      '지출 현황',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              _buildStatusBadge(
                text: _getStatusText(data),
                color: statusColor,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 사용률과 실제 지출/예산
          Wrap(
            crossAxisAlignment:
            WrapCrossAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${usagePercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: data.isOverBudget
                      ? Colors.red
                      : Colors.black,
                ),
              ),
              Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 4,
                ),
                child: Text(
                  '사용 · '
                      '${_formatAmount(data.totalSpent)}원'
                      ' / '
                      '${_formatAmount(data.totalBudget)}원',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 실제 사용률과 권장 페이스 표시
          _buildPaceProgressBar(
            usageProgress:
            data.progressValue,
            paceProgress:
            paceMarkerValue,
            color: statusColor,
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              _elapsedDays <= 0
                  ? '아직 선택한 월이 시작되지 않았습니다.'
                  : '오늘($_elapsedDays일) 기준 '
                  '권장 페이스 '
                  '${recommendedPercentage.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 이번 달 예산과 현재 지출
          Row(
            children: [
              Expanded(
                child: _buildAmountBox(
                  title: '이번 달 예산',
                  amount: data.totalBudget,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAmountBox(
                  title: '현재 지출',
                  amount: data.totalSpent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 남은 예산
          _buildRemainingBudgetBox(data),

          const SizedBox(height: 18),

          const Divider(
            height: 1,
            color: Color(0xFFE5E5E5),
          ),

          const SizedBox(height: 16),

          // 예상 총지출
          Row(
            children: [
              const Expanded(
                child: Text(
                  '이대로면 이번 달 예상 총지출',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '약 '
                    '${_formatAmount(expectedTotalSpent)}원',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _getExpectedSpentColor(
                    data,
                    expectedTotalSpent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 페이스 상태 배지
  Widget _buildStatusBadge({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.16,
        ),
        borderRadius:
        BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  /// 실제 사용률 진행 바와 권장 페이스 기준선
  Widget _buildPaceProgressBar({
    required double usageProgress,
    required double paceProgress,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.maxWidth;

        final markerPosition =
            availableWidth * paceProgress;

        return SizedBox(
          height: 22,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 전체 배경 막대
              Positioned(
                top: 4,
                left: 0,
                right: 0,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFFF1F3F5),
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
              ),

              // 실제 예산 사용률
              Positioned(
                top: 4,
                left: 0,
                child: AnimatedContainer(
                  duration:
                  const Duration(
                    milliseconds: 350,
                  ),
                  width: availableWidth *
                      usageProgress
                          .clamp(0.0, 1.0),
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius:
                    BorderRadius.circular(20),
                  ),
                ),
              ),

              // 오늘 날짜 기준 권장 페이스 기준선
              Positioned(
                left: (markerPosition - 1)
                    .clamp(
                  0.0,
                  availableWidth - 2,
                ),
                top: 0,
                child: Container(
                  width: 2,
                  height: 22,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 이번 달 예산 / 현재 지출 박스
  Widget _buildAmountBox({
    required String title,
    required int amount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFC),
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment:
            Alignment.centerLeft,
            child: Text(
              '${_formatAmount(amount)}원',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 남은 예산 또는 초과 금액 박스
  Widget _buildRemainingBudgetBox(
      BudgetVsExpenseModel data,
      ) {
    final isOverBudget =
        data.isOverBudget;

    final color = isOverBudget
        ? Colors.red
        : const Color(0xFF078A19);

    final backgroundColor = isOverBudget
        ? const Color(0xFFFFE5E5)
        : const Color(0xFFD9F1D8);

    final amount = isOverBudget
        ? data.overAmount
        : data.remainingAmount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isOverBudget
                  ? '초과 금액'
                  : '남은 예산',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          Text(
            '${_formatAmount(amount)}원',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}