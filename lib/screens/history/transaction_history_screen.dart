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
  // CalendarFormat _calendarFormat = CalendarFormat.week; 1주 보기
  CalendarFormat _calendarFormat = CalendarFormat.twoWeeks; // 2주 보기
  String _selectedFilter = '전체';

  // 데이터 관리를 위한 변수
  final TransactionService _transactionService = TransactionService();
  List<TransactionItem> _allTransactions = [];
  bool _isLoading = false;

  // 날짜별 스크롤 위치를 기억할 이름표 보관함
  final Map<DateTime, GlobalKey> _dateKeys = {};

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
      final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0, 23, 59, 59);

      // 현재 로그인한 유저의 정보 가져오기
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

      final data = await _transactionService.getMonthlyTransactions(
        userId: currentUserId, // 실제유저아이디
        start: start,
        end: end,
      );

      setState(() {
        _dateKeys.clear();
        _allTransactions = data;
      });
    } catch (e) {
      // 에러가 나면 앱이 멈추지 않고 콘솔에 원인을 출력합니다.
      print('⚠️ 데이터 불러오기 실패: $e');
    } finally {
      // 성공하든 에러가 나든 마지막에 무조건 로딩 스피너를 꺼줍니다.
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
        foregroundColor: AppColors.ink,
        elevation: 0,
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
                  _loadMonthlyData(); // 월 이동 시 데이터 갱신
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
              style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            locale: 'ko_KR', // 월,화,수 - 한글로
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
              _scrollToDate(selectedDay); // 날짜 선택시 해당 내역으로 이동
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
                    width: 28, // 파란 동그라미 너비
                    height: 28, // 파란 동그라미 높이
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

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sums['income']! > 0)
                          Text('+${CurrencyFormatter.format(sums['income']!)}',
                              style: const TextStyle(color: AppColors.income, fontSize: 9, fontWeight: FontWeight.w600)),
                        if (sums['expense']! > 0)
                          Text('-${CurrencyFormatter.format(sums['expense']!)}',
                              style: const TextStyle(color: AppColors.expenseNegative, fontSize: 9, fontWeight: FontWeight.w600)),
                        if (sums['saving']! > 0)
                          Text('${CurrencyFormatter.format(sums['saving']!)}',
                              style: const TextStyle(color: AppColors.saving, fontSize: 9, fontWeight: FontWeight.w600)),
                      ],
                    ),
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
                ? const Center(child: Text('내역이 없습니다.', style: TextStyle(color: AppColors.inkSub)))

            // ListView.builder 대신 ListView를 사용
                : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: groupedData.map((entry) {
                final date = entry.key;
                final items = entry.value;

                // 해당 날짜의 이름표(Key)가 없으면 새로 발급해서 보관함에 넣습니다.
                if (!_dateKeys.containsKey(date)) {
                  _dateKeys[date] = GlobalKey();
                }

                // formatters 안 공통 함수
                String dateString = DateFormatter.formatDayAndWeekday(date);
                // 하단은 짧은 요일(예: 15일 (금))
                // String dateString = DateFormatter.formatDayAndShortWeekday(date);

                // Column을 Container로 감싸고 발급한 이름표(Key)를 달아줍니다!
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
              }).toList(), // map의 결과를 리스트로 변환
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
            _dateKeys.clear();
            _selectedFilter = label;
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: AppColors.ink,
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.inkSub,
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
    final isSaving = item.type == 'saving';

    // 1. 완료/해지/매도된 저축인지 확인 (active가 아니면 true)
    final bool isCompletedSaving = isSaving &&
        item.savingStatus != null &&
        item.savingStatus != 'active';

    // 기호 처리
    final String sign = isExpense ? '-' : (isSaving ? '' : '+');
    final amountText = '$sign${CurrencyFormatter.format(item.amount)}원';

    // 2. 아이콘 배경색 (완료된 저축이면 회색, 아니면 기존 색상)
    final Color iconColor = isCompletedSaving
        ? Colors.grey[400]!
        : (isExpense ? AppColors.expense : (isSaving ? AppColors.saving : AppColors.income));

    // 3. 금액 글씨색 (완료된 저축이면 회색, 아니면 기존 색상)
    final Color amountColor = isCompletedSaving
        ? AppColors.inkSub
        : (isExpense ? AppColors.ink : (isSaving ? AppColors.saving : AppColors.utility));

    return InkWell(
      onTap: () async {
        // 1. 상세 페이지로 이동하면서 현재 클릭한 item 데이터를 넘겨줍니다.
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(item: item),
          ),
        );
        // 2. 상세 페이지에서 (수정/삭제 후) 뒤로가기를 눌러 돌아오면 데이터를 다시 불러옵니다!
        _loadMonthlyData();
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                  isExpense ? Icons.storefront : (isSaving ? Icons.savings : Icons.account_balance_wallet),
                  color: Colors.white
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amountText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: amountColor,
                      // 4. 완료된 저축이면 금액에 취소선 긋기
                      decoration: isCompletedSaving ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.title} ${item.subtitle != null ? '· ${item.subtitle}' : ''}',
                    style: TextStyle(
                      // 5. 완료된 저축이면 카테고리/메모 글씨도 더 연한 회색으로 변경
                      color: isCompletedSaving ? Colors.grey[400] : AppColors.inkSub,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  // 스크롤 이동 함수 추가
  void _scrollToDate(DateTime selectedDay) {
    // 달력에서 누른 날짜의 시/분/초를 잘라내어 Key 보관함과 똑같은 형식으로 맞춥니다.
    final pureDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

    // 해당 날짜의 이름표(Key)를 찾습니다.
    final key = _dateKeys[pureDate];

    // 이름표가 존재한다면(즉, 해당 날짜에 내역이 있다면) 그 위치로 스크롤!
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300), // 스크롤 애니메이션 속도
        curve: Curves.easeInOut, // 부드러운 애니메이션 효과
        alignment: 0.0, // 0.0으로 설정하면 해당 내역이 화면 맨 위로 올라옵니다.
      );
    }
  }
}