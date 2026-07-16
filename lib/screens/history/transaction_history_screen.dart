import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../utils/currency_formatter.dart';
import '../../models/transaction_item.dart';
import '../../services/transaction_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  String _selectedFilter = '전체';

  // 데이터 관리를 위한 변수
  final TransactionService _transactionService = TransactionService();
  List<TransactionItem> _allTransactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMonthlyData(); // 화면 켜질 때 데이터 불러오기
  }

// 파이어베이스에서 해당 월의 데이터 불러오기
  Future<void> _loadMonthlyData() async {
    setState(() => _isLoading = true);

    try {
      // 💡 1. FirebaseAuth를 통해 현재 로그인된 유저 객체 가져오기
      final currentUser = FirebaseAuth.instance.currentUser;

      // 💡 2. 혹시 로그인이 풀려있다면 함수를 종료시켜서 에러 방지
      if (currentUser == null) {
        print('⚠️ 로그인된 사용자가 없습니다.');
        setState(() => _isLoading = false);
        return;
      }

      final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);

      // 💡 3. 하드코딩했던 아이디 대신 진짜 유저 아이디(currentUser.uid) 주입!
      final data = await _transactionService.getMonthlyTransactions(
        userId: currentUser.uid,
        start: start,
        end: end,
      );

      setState(() {
        _allTransactions = data;
      });
    } catch (e) {
      print('⚠️ 데이터 불러오기 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 필터 조건(전체, 지출, 수입, 저축)에 맞게 데이터 걸러내기
  List<TransactionItem> get _filteredTransactions {
    if (_selectedFilter == '지출') return _allTransactions.where((e) => e.type == 'expense').toList();
    if (_selectedFilter == '수입') return _allTransactions.where((e) => e.type == 'income').toList();
    if (_selectedFilter == '저축') return _allTransactions.where((e) => e.type == 'saving').toList();
    return _allTransactions;
  }

  // 달력 날짜 밑에 찍어줄 일별 수입/지출 합계 계산
  Map<DateTime, Map<String, int>> get _dailySums {
    var sums = <DateTime, Map<String, int>>{};
    for (var item in _filteredTransactions) {
      final date = DateTime(item.date.year, item.date.month, item.date.day);
      if (sums[date] == null) sums[date] = {'income': 0, 'expense': 0};

      if (item.type == 'income') {
        sums[date]!['income'] = sums[date]!['income']! + item.amount;
      }
      if (item.type == 'expense') {
        sums[date]!['expense'] = sums[date]!['expense']! + item.amount;
      }
    }
    return sums;
  }

  // 하단 리스트뷰를 위해 데이터를 날짜별로 묶기
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
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left, color: Colors.black),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                  _loadMonthlyData(); // 월 이동 시 데이터 갱신
                });
              },
            ),
            Text(
              '${_focusedDay.month}월',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right, color: Colors.black),
              onPressed: () {
                setState(() {
                  _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                  _loadMonthlyData(); // 월 이동 시 데이터 갱신
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
                _loadMonthlyData(); // 오늘로 이동 시 데이터 갱신
              });
            },
            child: const Text(
              '오늘',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(
              _calendarFormat == CalendarFormat.week
                  ? Icons.calendar_month
                  : Icons.calendar_view_week,
              color: Colors.black,
            ),
            onPressed: () {
              setState(() {
                _calendarFormat = _calendarFormat == CalendarFormat.week
                    ? CalendarFormat.month
                    : CalendarFormat.week;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
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
            firstDay: DateTime(2020, 1, 1),
            lastDay: DateTime(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            headerVisible: false,
            rowHeight: 70, // 날짜 밑 금액을 위한 공간
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _loadMonthlyData();
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle),
              todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              cellMargin: const EdgeInsets.only(bottom: 20),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final pureDate = DateTime(day.year, day.month, day.day);
                final sums = _dailySums[pureDate];

                if (sums == null) return const SizedBox();

                return Positioned(
                  bottom: 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (sums['income']! > 0)
                      // 💡 CurrencyFormatter 적용
                        Text('+${CurrencyFormatter.format(sums['income']!)}',
                            style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                      if (sums['expense']! > 0)
                      // 💡 CurrencyFormatter 적용
                        Text('-${CurrencyFormatter.format(sums['expense']!)}',
                            style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(thickness: 1, height: 24, color: Color(0xFFEEEEEE)),

          // 지출/수입 내역 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : groupedData.isEmpty
                ? const Center(child: Text('내역이 없습니다.', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: groupedData.length,
              itemBuilder: (context, index) {
                final date = groupedData[index].key;
                final items = groupedData[index].value;

                // 💡 [수정 필요] formatDayAndWeekday 부분에 예림님의 요일 변환 유틸 함수를 넣어주세요!
                // 예: String dateString = AppDateUtils.formatToKorean(date);
                String dateString = '${date.day}일'; // 임시 텍스트 (유틸 적용 후 지워주세요)

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(dateString, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    ...items.map((item) => _buildTransactionItem(item)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 필터 칩 위젯
  Widget _buildFilterChip(String label) {
    final bool isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.grey[800],
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey[700],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }

  // 리스트 아이템 UI
  Widget _buildTransactionItem(TransactionItem item) {
    final isExpense = item.type == 'expense';

    // 💡 [수정 필요] formatCurrency 부분에 예림님의 금액 포맷 유틸 함수를 넣어주세요!
    final amountText = '${isExpense ? '-' : '+'}${CurrencyFormatter.format(item.amount)}원';

    return InkWell( // 💡 터치 이벤트를 위해 InkWell 추가
      onTap: () {
        // TODO: 16_내역상세 페이지로 이동하는 Navigator 로직 추가
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isExpense ? Colors.yellow[700] : Colors.blue[300],
                shape: BoxShape.circle,
              ),
              child: Icon(isExpense ? Icons.storefront : Icons.account_balance_wallet, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isExpense ? Colors.black87 : Colors.blueAccent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.title} ${item.subtitle != null ? '· ${item.subtitle}' : ''}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}