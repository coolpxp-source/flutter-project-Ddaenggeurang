import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/emotion_summary_model.dart';
import '../../services/emotion_summary_service.dart';

class EmotionSummaryScreen extends StatefulWidget {
  const EmotionSummaryScreen({super.key});

  @override
  State<EmotionSummaryScreen> createState() =>
      _EmotionSummaryScreenState();
}

class _EmotionSummaryScreenState
    extends State<EmotionSummaryScreen> {
  final EmotionSummaryService _emotionSummaryService =
  EmotionSummaryService();

  late int _selectedYear;
  late int _selectedMonth;

  bool _isLoading = true;
  String? _errorMessage;

  List<EmotionSummaryModel> _summaryList = [];
  int _totalExpense = 0;

  @override
  void initState() {
    super.initState();

    final DateTime now = DateTime.now();

    _selectedYear = now.year;
    _selectedMonth = now.month;

    _loadEmotionSummary();
  }

  Future<void> _loadEmotionSummary() async {
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인이 필요합니다.';
      });

      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<EmotionSummaryModel> result =
      await _emotionSummaryService.getEmotionSummary(
        userId: currentUser.uid,
        year: _selectedYear,
        month: _selectedMonth,
      );

      final int total = result.fold<int>(
        0,
            (
            int sum,
            EmotionSummaryModel item,
            ) {
          return sum + item.totalAmount;
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _summaryList = result;
        _totalExpense = total;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '감정태그 통계를 불러오지 못했습니다.\n$e';
      });
    }
  }

  void _movePreviousMonth() {
    if (_selectedMonth == 1) {
      _selectedYear--;
      _selectedMonth = 12;
    } else {
      _selectedMonth--;
    }

    _loadEmotionSummary();
  }

  void _moveNextMonth() {
    final DateTime now = DateTime.now();

    final bool isCurrentMonth =
        _selectedYear == now.year &&
            _selectedMonth == now.month;

    if (isCurrentMonth) {
      return;
    }

    if (_selectedMonth == 12) {
      _selectedYear++;
      _selectedMonth = 1;
    } else {
      _selectedMonth++;
    }

    _loadEmotionSummary();
  }

  bool get _isCurrentMonth {
    final DateTime now = DateTime.now();

    return _selectedYear == now.year &&
        _selectedMonth == now.month;
  }

  String _formatAmount(int amount) {
    final String value = amount.toString();
    final StringBuffer result = StringBuffer();

    for (int i = 0; i < value.length; i++) {
      final int remaining = value.length - i;

      result.write(value[i]);

      if (remaining > 1 && remaining % 3 == 1) {
        result.write(',');
      }
    }

    return result.toString();
  }

  IconData _getEmotionIcon(String emotionKey) {
    switch (emotionKey) {
      case 'planned':
        return Icons.event_available;
      case 'impulsive':
        return Icons.flash_on;
      case 'stress':
        return Icons.sentiment_dissatisfied;
      case 'social':
        return Icons.groups;
      case 'reward':
        return Icons.card_giftcard;
      default:
        return Icons.more_horiz;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          '감정태그별 통계',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadEmotionSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            _buildMonthSelector(),
            const SizedBox(height: 20),
            _buildTotalExpenseCard(),
            const SizedBox(height: 20),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isLoading
                ? null
                : _movePreviousMonth,
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),
          Expanded(
            child: Text(
              '$_selectedYear년 $_selectedMonth월',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed:
            _isLoading || _isCurrentMonth
                ? null
                : _moveNextMonth,
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalExpenseCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF4F7DF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 감정태그 지출',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_formatAmount(_totalExpense)}원',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEmotionSummary,
              child: const Text('다시 불러오기'),
            ),
          ],
        ),
      );
    }

    if (_summaryList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 70),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '이번 달 감정태그 지출 내역이 없습니다.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          '감정별 소비 비율',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        ..._summaryList.map(
              (EmotionSummaryModel item) {
            return _buildEmotionItem(item);
          },
        ),
      ],
    );
  }

  Widget _buildEmotionItem(
      EmotionSummaryModel item,
      ) {
    final double progress =
    (item.percentage / 100)
        .clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FF),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  _getEmotionIcon(
                    item.emotionKey,
                  ),
                  color: const Color(0xFF4F7DF3),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.emotionName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment:
                CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatAmount(item.totalAmount)}원',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
              const Color(0xFFE9ECF2),
              valueColor:
              const AlwaysStoppedAnimation<Color>(
                Color(0xFF4F7DF3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}