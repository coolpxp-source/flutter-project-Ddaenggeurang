import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/activity_calendar_service.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);

/// 접속 캘린더 — 앱을 연 날짜를 달력에 색칠해서 보여준다.
/// GitHub 잔디밭처럼 "얼마나 꾸준히 왔는지"를 한눈에 확인하는 용도.
class ActivityHeatmapScreen extends StatefulWidget {
  const ActivityHeatmapScreen({super.key});

  @override
  State<ActivityHeatmapScreen> createState() => _ActivityHeatmapScreenState();
}

class _ActivityHeatmapScreenState extends State<ActivityHeatmapScreen> {
  DateTime _focusedMonth = DateTime.now();

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('접속 캘린더', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<Set<String>>(
              stream: ActivityCalendarService().watchActiveDates(uid),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _accent, strokeWidth: 2.4));
                }
                final activeDates = snap.data!;
                final thisMonthCount = activeDates
                    .where((d) => d.startsWith(
                        '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}'))
                    .length;

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.event_available_rounded,
                            label: '이번 달 접속',
                            value: '$thisMonthCount일',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.calendar_month_rounded,
                            label: '누적 접속',
                            value: '${activeDates.length}일',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                              color: _ink.withValues(alpha: 0.045),
                              blurRadius: 14,
                              offset: const Offset(0, 5)),
                        ],
                      ),
                      child: TableCalendar(
                        firstDay: DateTime(2024, 1, 1),
                        lastDay: DateTime.now().add(const Duration(days: 1)),
                        focusedDay: _focusedMonth,
                        calendarFormat: CalendarFormat.month,
                        headerVisible: false,
                        daysOfWeekStyle: const DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700, color: _inkSub),
                          weekendStyle: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700, color: _inkSub),
                        ),
                        onPageChanged: (focused) => setState(() => _focusedMonth = focused),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, _) => _DayCell(
                            day: day,
                            active: activeDates.contains(_key(day)),
                          ),
                          todayBuilder: (context, day, _) => _DayCell(
                            day: day,
                            active: activeDates.contains(_key(day)),
                            isToday: true,
                          ),
                          outsideBuilder: (context, day, _) => _DayCell(
                            day: day,
                            active: false,
                            faded: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _MonthNav(
                      focusedMonth: _focusedMonth,
                      onPrev: () => setState(() => _focusedMonth =
                          DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1)),
                      onNext: () => setState(() => _focusedMonth =
                          DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1)),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _MonthNav extends StatelessWidget {
  final DateTime focusedMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthNav({required this.focusedMonth, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left_rounded, color: _ink)),
        Text('${focusedMonth.year}년 ${focusedMonth.month}월',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded, color: _ink)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSub)),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool active;
  final bool isToday;
  final bool faded;
  const _DayCell({
    required this.day,
    required this.active,
    this.isToday = false,
    this.faded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? _accent : (isToday ? _accentSoft : Colors.transparent),
          shape: BoxShape.circle,
          border: isToday && !active ? Border.all(color: _accent, width: 1.4) : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: faded
                ? _line
                : active
                    ? Colors.white
                    : _ink,
          ),
        ),
      ),
    );
  }
}
