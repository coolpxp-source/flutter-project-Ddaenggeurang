import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.week; // 레퍼런스처럼 기본은 주간(Week) 뷰

  // 현재 선택된 필터 (기본값은 '전체')
  String _selectedFilter = '전체';

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true, // 💡 1. 타이틀(월 이동) 중앙 정렬
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
                setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1));
              },
            ),
            Text(
              '${_focusedDay.month}월',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right, color: Colors.black),
              onPressed: () {
                setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1));
              },
            ),
          ],
        ),
        actions: [
          // 💡 새롭게 추가된 '오늘' 버튼
          TextButton(
            onPressed: () {
              setState(() {
                _focusedDay = DateTime.now(); // 달력 화면을 오늘이 포함된 달로 이동
                _selectedDay = DateTime.now(); // 선택된 날짜도 오늘로 변경
              });
            },
            child: const Text(
              '오늘',
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),

          // 기존에 있던 달력 주간/월간 토글 아이콘
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

          // 기존에 있던 검색 아이콘
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 카테고리 필터 칩 (가로 스크롤)
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
            focusedDay: _focusedDay, // 💡 3. 기본값이 DateTime.now()이므로 오늘이 포함된 주차를 바로 띄움
            calendarFormat: _calendarFormat,
            headerVisible: false,
            rowHeight: 70, // 💡 4. 날짜 밑에 금액이 들어갈 수 있도록 달력 한 칸의 높이를 넉넉하게 확보
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            calendarStyle: CalendarStyle(
              selectedDecoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.grey[300], shape: BoxShape.circle),
              todayTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              // 달력 날짜 텍스트를 위쪽으로 살짝 올려서 금액 공간 마련
              cellMargin: const EdgeInsets.only(bottom: 20),
            ),
            // 💡 4. 날짜 밑에 금액 그리기 (markerBuilder 활용)
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                // (임시) 화면 확인용 더미 로직: 짝수 날짜는 수입, 홀수 날짜는 지출 표시
                bool hasIncome = day.day % 2 == 0;
                bool hasExpense = day.day % 3 == 0;

                return Positioned(
                  bottom: 2, // 칸의 가장 아래쪽에 배치
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasIncome)
                        const Text('+10,000', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                      if (hasExpense)
                        const Text('-24,000', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(thickness: 1, height: 24, color: Color(0xFFEEEEEE)),

          // 지출/수입 내역 리스트 (임시 더미 데이터)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              itemBuilder: (context, index) {
                return _buildDummyTransactionItem(); // (이전 함수 그대로 유지)
              },
            ),
          ),
        ],
      ),
    );
  }

  // 필터 칩 위젯 생성 함수
  Widget _buildFilterChip(String label) {
    // 현재 칩의 라벨이 선택된 필터와 같은지 확인
    final bool isSelected = _selectedFilter == label;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          // 칩을 누르면 상태를 업데이트하여 화면을 다시 그림
          setState(() {
            _selectedFilter = label;
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.grey[800], // 선택 시 진한 배경
        labelStyle: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.grey[700], // 선택 시 흰색 글씨
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
      ),
    );
  }

  // 내역 리스트 아이템 UI (타이포그래피 강조)
  Widget _buildDummyTransactionItem() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 헤더
          const Text(
            '16일 목요일',
            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // 내역 본문
          Row(
            children: [
              // 카테고리 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.yellow[700],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, color: Colors.white),
              ),
              const SizedBox(width: 16),

              // 텍스트 정보 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 금액 (가장 굵고 크게 배치)
                    const Text(
                      '-14,200원',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    // 상세 정보
                    Text(
                      '편의점/마트 · 프렌즈 체크카드',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}