import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import '../../models/budget_vs_expense_model.dart';
import '../../services/budget_vs_expense_service.dart';


class BudgetVsExpenseScreen extends StatefulWidget {
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
  final BudgetVsExpenseService _service =
  BudgetVsExpenseService();

  DateTime _selectedMonth = DateTime.now();

  /// Firestore 문서 조회에 사용할 월 키
  ///
  /// 예: 2026-07
  String get _monthKey {
    final month =
    _selectedMonth.month.toString().padLeft(2, '0');

    return '${_selectedMonth.year}-$month';
  }

  /// 화면에 표시할 연도와 월
  ///
  /// 예: 2026년 7월
  String get _monthTitle {
    return DateFormat('yyyy년 M월').format(_selectedMonth);
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

  /// 금액에 천 단위 쉼표 추가
  String _formatAmount(int amount) {
    return NumberFormat('#,###').format(amount);
  }

  /// 예산 사용률에 따른 색상
  Color _getProgressColor(
      BudgetVsExpenseModel data,
      ) {
    if (data.isOverBudget) {
      return Colors.red;
    }

    if (data.usageRate >= 0.8) {
      return Colors.orange;
    }

    if (data.usageRate >= 0.5) {
      return Colors.amber;
    }

    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          '예산 대비 지출',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<BudgetVsExpenseModel>(
        stream: _service.watchBudgetVsExpense(
          userId: widget.userId,
          monthKey: _monthKey,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '예산 정보를 불러오지 못했습니다.\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data ??
              const BudgetVsExpenseModel(
                totalBudget: 0,
                totalSpent: 0,
              );

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _buildMonthSelector(),
              const SizedBox(height: 20),

              _buildSummaryCard(data),
              const SizedBox(height: 16),

              _buildAmountCard(
                title: '이번 달 예산',
                amount: data.totalBudget,
                icon:
                Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 12),

              _buildAmountCard(
                title: '현재 지출',
                amount: data.totalSpent,
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 12),

              _buildRemainingCard(data),
            ],
          );
        },
      ),
    );
  }

  /// 월 이동 영역
  Widget _buildMonthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _movePreviousMonth,
          icon: const Icon(
            Icons.chevron_left,
            size: 30,
          ),
        ),
        SizedBox(
          width: 150,
          child: Text(
            _monthTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: _moveNextMonth,
          icon: const Icon(
            Icons.chevron_right,
            size: 30,
          ),
        ),
      ],
    );
  }

  /// 예산 사용률 카드
  Widget _buildSummaryCard(
      BudgetVsExpenseModel data,
      ) {
    final progressColor = _getProgressColor(data);
    final usagePercentage = data.usageRate * 100;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '예산 사용률',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${usagePercentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: progressColor,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: data.progressValue,
              minHeight: 16,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _createStatusMessage(data),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: progressColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 예산 또는 지출 금액 카드
  Widget _buildAmountCard({
    required String title,
    required int amount,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF4385F5),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ),
          Text(
            '${_formatAmount(amount)}원',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 남은 예산 또는 초과 금액 카드
  Widget _buildRemainingCard(
      BudgetVsExpenseModel data,
      ) {
    final isOverBudget = data.isOverBudget;

    final amount = isOverBudget
        ? data.overAmount
        : data.remainingAmount;

    final cardColor = isOverBudget
        ? const Color(0xFFFFEEEE)
        : const Color(0xFFEDF8F0);

    final contentColor =
    isOverBudget ? Colors.red : Colors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            isOverBudget
                ? Icons.warning_amber_rounded
                : Icons.savings_outlined,
            color: contentColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOverBudget
                  ? '예산을 초과했어요'
                  : '남은 예산',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: contentColor,
              ),
            ),
          ),
          Text(
            '${_formatAmount(amount)}원',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: contentColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 예산 사용 상태 안내 문구
  String _createStatusMessage(
      BudgetVsExpenseModel data,
      ) {
    if (data.totalBudget <= 0) {
      return '설정된 예산이 없습니다.';
    }

    if (data.isOverBudget) {
      return '예산을 ${_formatAmount(data.overAmount)}원 초과했습니다.';
    }

    if (data.usageRate >= 0.8) {
      return '예산의 80% 이상을 사용했습니다.';
    }

    if (data.usageRate >= 0.5) {
      return '예산의 절반 이상을 사용했습니다.';
    }

    return '예산을 안정적으로 사용하고 있습니다.';
  }
}