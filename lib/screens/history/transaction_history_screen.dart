import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/formatters.dart';
import '../../models/transaction_item.dart';
import '../../services/transaction_service.dart';
import '../../utils/app_colors.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks;
  String _selectedFilter = '전체';

  final TransactionService _transactionService = TransactionService();
  List<TransactionItem> _allTransactions = [];
  bool _isLoading = false;

  final Map<DateTime, GlobalKey> _dateKeys = {};
  final ScrollController _listScrollController = ScrollController();

  // 필터별 대표색 — 리스트 아이템/캘린더에서 쓰는 타입 색상과 통일
  static const Map<String, Color> _filterColors = {
    '전체': AppColors.ink,
    '지출': AppColors.expenseDeep,
    '수입': AppColors.income,
    '저축': AppColors.saving,
  };

  static const Map<String, Color> _filterSoftColors = {
    '전체': Color(0xFFF1F1F3),
    '지출': Color(0xFFFFF1E0),
    '수입': AppColors.incomeSoft,
    '저축': AppColors.savingSoft,
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    setState(() => _isLoading = true);

    try {
      final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final data = await _transactionService.getMonthlyTransactions(
        userId: currentUserId,
        start: start,
        end: end,
      );

      setState(() {
        _dateKeys.clear();
        _allTransactions = data;
      });
    } catch (e) {
      print('⚠️ 데이터 불러오기 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  List<TransactionItem> get _filteredTransactions {
    if (_selectedFilter == '지출') return _allTransactions.where((e) => e.type == 'expense').toList();
    if (_selectedFilter == '수입') return _allTransactions.where((e) => e.type == 'income').toList();
    if (_selectedFilter == '저축') return _allTransactions.where((e) => e.type == 'saving').toList();
    return _allTransactions;
  }

  Map<DateTime, Map<String, int>> get _dailySums {
    var sums = <DateTime, Map<String, int>>{};
    for (var item in _filteredTransactions) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      if (sums[date] == null) sums[date] = {'income': 0, 'expense': 0, 'saving': 0};

      if (item.type == 'income') {
        sums[date]!['income'] = sums[date]!['income']! + item.amount;
      } else if (item.type == 'expense') {
        sums[date]!['expense'] = sums[date]!['expense']! + item.amount;
      } else if (item.type == 'saving') {
        sums[date]!['saving'] = sums[date]!['saving']! + item.amount;
      }
    }
    return sums;
  }

  Map<DateTime, List<TransactionItem>> get _groupedTransactions {
    var grouped = <DateTime, List<TransactionItem>>{};
    for (var item in _filteredTransactions) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      if (grouped[date] == null) grouped[date] = [];
      grouped[date]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedData = _groupedTransactions.entries.toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left, color: AppColors.ink),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                  _loadMonthlyData();
                });
              },
            ),
            Text(
              '${_focusedDay.month}월',
              style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right, color: AppColors.ink),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                  _loadMonthlyData();
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now();
                _selectedDay = DateTime.now();
                _loadMonthlyData();
              });
            },
            child: const Text(
              '오늘',
              style: TextStyle(color: AppColors.utility, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(
              _calendarFormat == CalendarFormat.week
                  ? Icons.calendar_month
                  : Icons.calendar_view_week,
              color: AppColors.ink,
            ),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.twoWeeks
                    ? CalendarFormat.month
                    : CalendarFormat.twoWeeks;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.ink),
            onPressed: () {}, // TODO: 검색 화면 이동 연결
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 카테고리 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip('전체'),
                _buildFilterChip('지출'),
                _buildFilterChip('수입'),
                _buildFilterChip('저축'),
              ],
            ),
          ),

          // 스와이프 달력
          TableCalendar(
            locale: 'ko_KR',
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            headerVisible: false,
            rowHeight: 70,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _scrollToDate(selectedDay);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMonthlyData();
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: AppColors.utility, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle),
              todayTextStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
              cellMargin: const EdgeInsets.only(bottom: 20),
            ),
            calendarBuilders: CalendarBuilders(
              selectedBuilder: (context, date, _) {
                return Container(
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.utility, shape: BoxShape.circle),
                    child: Text('${date.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                );
              },
              todayBuilder: (context, date, _) {
                return Container(
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle),
                    child: Text('${date.day}', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                final pureDate = DateTime(day.year, day.month, day.day);
                final sums = _dailySums[pureDate];

                if (sums == null) return const SizedBox();

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 수입은 항상 위쪽 슬롯에 고정 — 지출 유무와 상관없이 위치가 흔들리지 않도록
                    if (sums['income']! > 0)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text('+${CurrencyFormatter.format(sums['income']!)}',
                              style: const TextStyle(color: AppColors.income, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    // 지출은 항상 아래쪽 슬롯에 고정
                    if (sums['expense']! > 0)
                      Positioned(
                        bottom: 2,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text('-${CurrencyFormatter.format(sums['expense']!)}',
                              style: const TextStyle(color: AppColors.expenseNegative, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    if (sums['saving']! > 0)
                      Positioned(
                        top: 2,
                        right: 6,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.saving,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),

          const Divider(thickness: 1, height: 24, color: AppColors.divider),

          // 지출/수입 내역 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.utility))
                : groupedData.isEmpty
                ? const Center(child: Text('내역이 없습니다.', style: TextStyle(color: AppColors.inkSub)))
                : ListView(
              controller: _listScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: groupedData.map((entry) {
                final date = entry.key;
                final items = entry.value;

                if (!_dateKeys.containsKey(date)) {
                  _dateKeys[date] = GlobalKey();
                }

                String dateString = DateFormatter.formatDayAndWeekday(date);

                return Container(
                  key: _dateKeys[date],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(dateString, style: const TextStyle(color: AppColors.inkSub, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      ...items.map((item) => _buildTransactionItem(item)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── 필터 칩: 타입별 대표색 + 선택 시 소프트 배경, 미선택 시 은은한 회색 ──
  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;
    final Color mainColor = _filterColors[label] ?? AppColors.ink;
    final Color softColor = _filterSoftColors[label] ?? const Color(0xFFF1F1F3);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _dateKeys.clear();
            _selectedFilter = label;
          });
          if (_listScrollController.hasClients) {
            _listScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        },
        backgroundColor: const Color(0xFFF7F7F9),
        selectedColor: softColor,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: isSelected ? mainColor : AppColors.inkSub,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        showCheckmark: false,
        elevation: 0,
        pressElevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }

  // 리스트 아이템 UI
  Widget _buildTransactionItem(TransactionItem item) {
    final isExpense = item.type == 'expense';
    final isSaving = item.type == 'saving';

    final bool isCompletedSaving = isSaving &&
        item.savingStatus != null &&
        item.savingStatus != 'active';

    final String sign = isExpense ? '-' : (isSaving ? '' : '+');
    final amountText = '$sign${CurrencyFormatter.format(item.amount)}원';

    final Color iconColor = isCompletedSaving
        ? Colors.grey[400]!
        : (isExpense ? AppColors.expense : (isSaving ? AppColors.saving : AppColors.income));

    final Color amountColor = isCompletedSaving
        ? AppColors.inkSub
        : (isExpense ? AppColors.ink : (isSaving ? AppColors.saving : AppColors.utility));

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(item: item),
          ),
        );
        _loadMonthlyData();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                isExpense ? Icons.storefront : (isSaving ? Icons.savings : Icons.account_balance_wallet),
                color: iconColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isCompletedSaving ? Colors.grey[400] : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle ?? '',
                    style: TextStyle(
                      color: isCompletedSaving ? Colors.grey[400] : AppColors.inkSub,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amountText,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: amountColor,
                decoration: isCompletedSaving ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToDate(DateTime selectedDay) {
    final pureDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final key = _dateKeys[pureDate];

    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }
}