import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/formatters.dart';
import '../../models/transaction_item.dart';
import '../../services/transaction_service.dart';
import '../../utils/app_colors.dart';
import 'transaction_detail_screen.dart';
import '../briefing/mothly_briefing_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String _selectedFilter = '전체';

  final TransactionService _transactionService = TransactionService();
  List<TransactionItem> _allTransactions = [];
  bool _isLoading = false;

  final Map<DateTime, GlobalKey> _dateKeys = {};
  final ScrollController _listScrollController = ScrollController();

  // 검색 — 카테고리(title)·메모(subtitle)·계좌명(accountName) 대상
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  List<TransactionItem>? _searchPool; // 통합검색용 — 기간 제한 없는 전체 내역 캐시
  bool _isSearchLoading = false;

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
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() {
      _isSearching = true;
      _dateKeys.clear();
    });
    if (_searchPool == null) {
      _loadSearchPool();
    }
  }

  void _exitSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
      _dateKeys.clear();
    });
  }

  /// 통합검색용 전체 내역 캐시 로드 (기간 제한 없음)
  Future<void> _loadSearchPool() async {
    setState(() => _isSearchLoading = true);
    try {
      final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final data = await _transactionService.getAllTransactions(userId: currentUserId);
      if (!mounted) return;
      setState(() => _searchPool = data);
    } catch (e) {
      print('⚠️ 통합검색 데이터 불러오기 실패: $e');
    } finally {
      if (mounted) setState(() => _isSearchLoading = false);
    }
  }

  List<TransactionItem> get _filteredTransactions {
    // 검색 중엔 이번 달 데이터가 아니라 전체 기간 캐시(_searchPool)에서 찾음
    Iterable<TransactionItem> result = _isSearching ? (_searchPool ?? const []) : _allTransactions;

    if (_selectedFilter == '지출') {
      result = result.where((e) => e.type == 'expense');
    } else if (_selectedFilter == '수입') {
      result = result.where((e) => e.type == 'income');
    } else if (_selectedFilter == '저축') {
      result = result.where((e) => e.type == 'saving');
    }

    final query = _searchQuery.trim().toLowerCase();
    if (_isSearching) {
      if (query.isEmpty) return const []; // 검색어 없으면 전체 히스토리를 다 뿌리지 않음
      result = result.where((item) {
        final category = item.title.toLowerCase(); // title = 카테고리/출처/소분류명
        final memo = (item.subtitle ?? '').toLowerCase();
        final account = (item.accountName ?? '').toLowerCase();
        return category.contains(query) || memo.contains(query) || account.contains(query);
      });
    }

    return result.toList();
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
          onPressed: () {
            if (_isSearching) {
              _exitSearch();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          cursorColor: AppColors.utility,
          style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isCollapsed: true,
            hintText: '카테고리·메모·계좌명 검색',
            hintStyle: TextStyle(color: AppColors.inkSub, fontWeight: FontWeight.w500, fontSize: 15),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        )
            : InkWell(
          onTap: _openCalendarPicker,
          onLongPress: _showMonthYearPicker,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_focusedDay.year}년 ${_focusedDay.month.toString().padLeft(2, '0')}월',
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.expand_more_rounded, color: AppColors.ink, size: 20),
              ],
            ),
          ),
        ),
        actions: _isSearching
            ? [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.ink),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
        ]
            : [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.ink, size: 22),
            onPressed: _enterSearch,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 월간브리핑 바로가기 카드 — 흰 배경 + cardShadow로 다른 리스트 카드들과 톤을 맞춘 한 줄 카드.
          // 검색 중엔 UI 복잡해지지 않도록 숨김.
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MonthlyBriefingScreen()),
                    );
                  },
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.utilitySoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_graph_rounded, color: AppColors.utility, size: 17),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${_focusedDay.month}월 브리핑 보러가기',
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.inkSub, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 카테고리 필터 칩바 — 드롭다운 대신 가로 스크롤 칩으로 한 번에 보이고 한 탭에 전환
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _buildFilterChips(),
            ),

          // 검색 중에는 캘린더 대신 검색 결과 요약 라인을 보여줌
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 14, color: AppColors.inkSub),
                  const SizedBox(width: 6),
                  Text(
                    _isSearchLoading
                        ? '전체 내역을 불러오는 중...'
                        : _searchQuery.trim().isEmpty
                        ? '카테고리, 메모, 계좌명으로 검색해보세요 (전체 기간)'
                        : "'${_searchQuery.trim()}' 검색결과 ${_filteredTransactions.length}건",
                    style: const TextStyle(color: AppColors.inkSub, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          if (!_isSearching)
            const Divider(thickness: 1, height: 24, color: AppColors.divider),

          // 지출/수입 내역 리스트
          Expanded(
            child: (_isLoading || (_isSearching && _isSearchLoading))
                ? const Center(child: CircularProgressIndicator(color: AppColors.utility))
                : groupedData.isEmpty
                ? Center(
              child: (_isSearching && _searchQuery.trim().isEmpty)
                  ? const SizedBox.shrink()
                  : Text(
                _isSearching ? '검색 결과가 없습니다.' : '내역이 없습니다.',
                style: const TextStyle(color: AppColors.inkSub),
              ),
            )
                : ListView(
              controller: _listScrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // 캘린더에서 날짜를 탭했을 때 Scrollable.ensureVisible()이 첫 시도에도
              // 정확히 이동하도록, 화면 밖 항목까지 미리 레이아웃해두기 위한 넉넉한 cacheExtent.
              // (기본 cacheExtent는 ~250px라 화면 아래쪽 날짜는 레이아웃 전이라 못 찾았음)
              cacheExtent: 6000,
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
                        child: Text(dateString, style: const TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.w800)),
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

  // ── 카테고리 필터 칩바: 드롭다운(탭 2번) 대신 가로 스크롤 칩(탭 1번)으로 전체/지출/수입/저축 전환 ──
  Widget _buildFilterChips() {
    const labels = ['전체', '지출', '수입', '저축'];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = labels[index];
          final bool isSelected = _selectedFilter == label;
          final Color mainColor = _filterColors[label] ?? AppColors.ink;
          final Color softColor = _filterSoftColors[label] ?? const Color(0xFFF1F1F3);

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              if (_selectedFilter == label) return;
              setState(() {
                _selectedFilter = label;
                _dateKeys.clear();
              });
              if (_listScrollController.hasClients) {
                _listScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            },
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? mainColor : softColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : mainColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 달력 모달: 상단 '2026년 07월' 탭하면 뜨는 전체 화면 날짜 선택기 ──
  // 날짜 숫자를 크게 보여주고, 날짜를 탭하면 모달을 닫으면서
  // 해당 날짜의 기록으로 리스트를 스크롤시킨다.
  Future<void> _openCalendarPicker() async {
    DateTime tempFocused = _focusedDay;
    DateTime? tempSelected = _selectedDay;
    // 현재 화면에 이미 로드된 달이면 기존 _dailySums를 그대로 재사용하고,
    // 모달 안에서 다른 달로 넘기면 그 달만 별도로 조회해서 미리보기 합계를 채운다.
    Map<DateTime, Map<String, int>> tempDailySums = _dailySums;
    bool tempLoading = false;

    Future<Map<DateTime, Map<String, int>>> loadSumsFor(DateTime month) async {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final data = await _transactionService.getMonthlyTransactions(userId: uid, start: start, end: end);

      final sums = <DateTime, Map<String, int>>{};
      for (var item in data) {
        final date = DateTime(item.date.year, item.date.month, item.date.day);
        sums[date] ??= {'income': 0, 'expense': 0, 'saving': 0};
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

    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> goToMonth(DateTime target) async {
              final newMonth = DateTime(target.year, target.month, 1);
              setSheetState(() {
                tempFocused = newMonth;
                tempLoading = true;
              });
              final sums = await loadSumsFor(newMonth);
              setSheetState(() {
                tempDailySums = sums;
                tempLoading = false;
              });
            }

            Future<void> changeMonth(int delta) {
              return goToMonth(DateTime(tempFocused.year, tempFocused.month + delta, 1));
            }

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDADADA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink, size: 26),
                          onPressed: () => changeMonth(-1),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            final picked = await _showYearMonthGridPicker(tempFocused);
                            if (picked != null) goToMonth(picked);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${tempFocused.year}년 ${tempFocused.month}월',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.expand_more_rounded, color: AppColors.ink, size: 20),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ink, size: 26),
                          onPressed: () => changeMonth(1),
                        ),
                        if (tempLoading) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.utility),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    TableCalendar(
                      locale: 'ko_KR',
                      firstDay: DateTime(2020, 1, 1),
                      lastDay: DateTime(2030, 12, 31),
                      focusedDay: tempFocused,
                      calendarFormat: CalendarFormat.month,
                      headerVisible: false,
                      daysOfWeekHeight: 26,
                      rowHeight: 84,
                      sixWeekMonthsEnforced: false,
                      selectedDayPredicate: (day) => isSameDay(tempSelected, day),
                      onDaySelected: (selectedDay, _) {
                        // 날짜를 탭하는 즉시 모달을 닫고, 그 날짜를 리스트 스크롤 위치로 넘긴다.
                        Navigator.pop(sheetContext, selectedDay);
                      },
                      daysOfWeekStyle: DaysOfWeekStyle(
                        weekdayStyle: const TextStyle(
                          color: AppColors.inkSub,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                        weekendStyle: TextStyle(
                          color: AppColors.expenseDeep.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      calendarStyle: const CalendarStyle(
                        outsideDaysVisible: false,
                        cellMargin: EdgeInsets.symmetric(vertical: 3),
                      ),
                      calendarBuilders: CalendarBuilders(
                        // 날짜 숫자와 그날의 저축/수입/지출 금액을 하나의 Column으로 묶어서 렌더링한다.
                        // (예전엔 숫자와 금액을 각각 Align/Positioned로 따로 배치했는데, 평범한 날짜는
                        // table_calendar 기본 렌더러가 숫자를 셀 정중앙에 두는 바람에 아래 금액 텍스트와
                        // 겹쳐버렸다. 하나의 Column으로 합치면 항상 숫자 → 금액 순서로 자연스럽게 쌓인다.)
                        defaultBuilder: (context, date, _) =>
                            _buildCalendarDayCell(date, tempDailySums, isSelected: false, isToday: false),
                        todayBuilder: (context, date, _) => _buildCalendarDayCell(
                          date,
                          tempDailySums,
                          isSelected: isSameDay(tempSelected, date),
                          isToday: true,
                        ),
                        selectedBuilder: (context, date, _) =>
                            _buildCalendarDayCell(date, tempDailySums, isSelected: true, isToday: false),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked == null) return;

    final bool sameMonth = picked.year == _focusedDay.year && picked.month == _focusedDay.month;
    setState(() {
      _selectedDay = picked;
      _focusedDay = picked;
    });

    // 다른 달을 선택했다면 그 달의 실제 리스트 데이터를 먼저 불러온 뒤 스크롤한다.
    if (!sameMonth) {
      await _loadMonthlyData();
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToDate(picked));
  }

  // ── 년/월 선택 그리드 — 캘린더 모달 헤더 탭 / 타이틀 롱프레스 양쪽에서 재사용 ──
  // initial을 기준으로 그리드를 열고, 고른 달의 1일을 담은 DateTime을 반환한다 (취소 시 null).
  Future<DateTime?> _showYearMonthGridPicker(DateTime initial) {
    int tempYear = initial.year;
    final DateTime now = DateTime.now();

    return showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bool canGoNextYear = tempYear < now.year;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDADADA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.ink),
                          onPressed: () => setModalState(() => tempYear -= 1),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            '$tempYear년',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
                          onPressed: canGoNextYear ? () => setModalState(() => tempYear += 1) : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: List.generate(12, (index) {
                        final int month = index + 1;
                        final bool isSelected = tempYear == initial.year && month == initial.month;
                        final bool isFuture = tempYear == now.year && month > now.month;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: isFuture
                              ? null
                              : () => Navigator.pop(sheetContext, DateTime(tempYear, month, 1)),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.utility : const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$month월',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : (isFuture ? const Color(0xFFC7C7C7) : AppColors.ink),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── 타이틀을 롱프레스하면 뜸 (빠르게 여러 달 건너뛸 때) ──
  void _showMonthYearPicker() async {
    final DateTime? picked = await _showYearMonthGridPicker(_focusedDay);
    if (picked == null) return;
    setState(() {
      _focusedDay = picked;
      _loadMonthlyData();
    });
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isCompletedSaving ? Colors.grey[400] : AppColors.ink,
                          ),
                        ),
                      ),
                      if (item.isRecurring) ...[
                        const SizedBox(width: 4),
                        Text(
                          isExpense
                              ? '(정기결제)'
                              : (isSaving ? '(반복저축)' : '(정기수입)'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isCompletedSaving ? Colors.grey[400] : AppColors.inkSub,
                          ),
                        ),
                      ],
                    ],
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

  // ── 캘린더 셀 하나(날짜 숫자 + 그날의 저축/수입/지출 금액)를 한 Column으로 묶어서 렌더링 ──
  // 숫자와 금액을 별도 레이어로 절대좌표 배치하지 않고 한 Column에 순서대로 쌓기 때문에
  // 겹칠 걱정 없이 항상 숫자 → 저축 → 수입 → 지출 순으로 위에서부터 정렬된다.
  Widget _buildCalendarDayCell(
      DateTime date,
      Map<DateTime, Map<String, int>> dailySums, {
        required bool isSelected,
        required bool isToday,
      }) {
    final pureDate = DateTime(date.year, date.month, date.day);
    final sums = dailySums[pureDate];

    final List<Widget> amountRows = [];
    if (sums != null) {
      // 순서: 저축(부호 없이) → 수입(+) → 지출(-). 있는 항목만 위에서부터 차곡차곡 쌓는다.
      if (sums['saving']! > 0) {
        amountRows.add(Text(
          CurrencyFormatter.format(sums['saving']!),
          style: const TextStyle(color: AppColors.ink, fontSize: 9, fontWeight: FontWeight.w700, height: 1.0),
        ));
      }
      if (sums['income']! > 0) {
        amountRows.add(Text(
          '+${CurrencyFormatter.format(sums['income']!)}',
          style: const TextStyle(color: AppColors.income, fontSize: 9, fontWeight: FontWeight.w700, height: 1.0),
        ));
      }
      if (sums['expense']! > 0) {
        amountRows.add(Text(
          '-${CurrencyFormatter.format(sums['expense']!)}',
          style: const TextStyle(color: AppColors.expenseNegative, fontSize: 9, fontWeight: FontWeight.w700, height: 1.0),
        ));
      }
    }

    final Widget numberWidget = (isSelected || isToday)
        ? Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.utility : AppColors.utility.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: (isToday && !isSelected)
            ? Border.all(color: AppColors.utility.withValues(alpha: 0.5), width: 1.2)
            : null,
        boxShadow: isSelected
            ? [
          BoxShadow(
            color: AppColors.utility.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ]
            : null,
      ),
      child: Text(
        '${date.day}',
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.utility,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    )
        : Text(
      '${date.day}',
      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13),
    );

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            numberWidget,
            if (amountRows.isNotEmpty) ...[
              const SizedBox(height: 3),
              for (int i = 0; i < amountRows.length; i++) ...[
                if (i != 0) const SizedBox(height: 1),
                amountRows[i],
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _scrollToDate(DateTime selectedDay, {bool isRetry = false}) {
    final pureDate = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    GlobalKey? key = _dateKeys[pureDate];

    // 선택한 날짜에 기록이 없으면 _dateKeys에 아예 키가 없어서 아무 반응이 없었던 문제.
    // 이 경우 해당 날짜와 가장 가까운(이전/이후 상관없이) 기록이 있는 날짜로 대신 스크롤한다.
    if (key == null && _dateKeys.isNotEmpty) {
      DateTime? closest;
      for (final d in _dateKeys.keys) {
        if (closest == null ||
            (d.difference(pureDate).abs() < closest.difference(pureDate).abs())) {
          closest = d;
        }
      }
      if (closest != null) key = _dateKeys[closest];
    }

    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    } else if (!isRetry) {
      // cacheExtent를 넉넉히 줬어도 아주 긴 목록(예: 전체기간 검색 결과)에서는
      // 첫 프레임에 대상이 아직 레이아웃되지 않았을 수 있어 한 번만 재시도한다.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _scrollToDate(selectedDay, isRetry: true);
      });
    }
  }
}