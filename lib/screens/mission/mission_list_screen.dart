import 'package:flutter/material.dart';

import '../../models/mission_definition_model.dart';
import '../../services/mission_service.dart';
import 'attendance_check_screen.dart';
import 'mission_proof_upload_screen.dart';

class MissionListScreen extends StatefulWidget {
  const MissionListScreen({super.key});

  @override
  State<MissionListScreen> createState() => _MissionListScreenState();
}

class _MissionListScreenState extends State<MissionListScreen> {
  String _selectedTab = 'monthly';
  bool _isAttendanceCompleted = false;

  final MissionService _missionService = MissionService();

  bool _isLoading = true;
  List<MissionDefinition> _missions = [];

  Map<String, Map<String, dynamic>> _missionProgress = {};

  final Set<int> _completedDays = {
    1,
    2,
    3,
    5,
    6,
    8,
    9,
    10,
    12,
    13,
    14,
    15,
  };

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    try {
      final results = await Future.wait([
        _missionService.getMissions(),
        _missionService.getMissionProgress(),
      ]);

      final missions =
      results[0] as List<MissionDefinition>;

      final missionProgress =
      results[1] as Map<String, Map<String, dynamic>>;

      if (!mounted) {
        return;
      }

      setState(() {
        _missions = missions;
        _missionProgress = missionProgress;

        _isAttendanceCompleted =
            _missionProgress['attendance']?['status'] ==
                'completed';

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '미션 정보를 불러오지 못했습니다: $e',
          ),
        ),
      );
    }
  }

  Map<String, dynamic> _toMissionUiData(
      MissionDefinition mission,
      ) {
    final progressData =
    _missionProgress[mission.id];

    final isCompleted =
        progressData?['status'] == 'completed';

    switch (mission.type) {
      case 'attendance':
        return {
          'id': mission.id,
          'title': mission.title,
          'description': '오늘 출석하고 포인트를 받아보세요',
          'progress': _isAttendanceCompleted ? 1 : 0,
          'target': 1,
          'points': mission.points,
          'icon': Icons.calendar_month,
          'color': const Color(0xFFFF6CAE),
          'requiresApproval': mission.requiresApproval,
        };

      case 'budget_success':
        return {
          'id': mission.id,
          'title': mission.title,
          'description': '설정한 예산 안에서 소비해보세요',
          'progress': isCompleted ? 1 : 0,
          'target': 1,
          'points': mission.points,
          'icon': Icons.savings_outlined,
          'color': const Color(0xFF8566FF),
          'requiresApproval': mission.requiresApproval,
        };

      case 'photo_proof':
        return {
          'id': mission.id,
          'title': mission.title,
          'description': '사진 인증 후 관리자 승인이 필요해요',
          'progress': isCompleted ? 1 : 0,
          'target': 1,
          'points': mission.points,
          'icon': Icons.camera_alt_outlined,
          'color': const Color(0xFF5B8DEF),
          'requiresApproval': mission.requiresApproval,
        };

      default:
        return {
          'id': mission.id,
          'title': mission.title,
          'description': '미션에 도전해보세요',
          'progress': isCompleted ? 1 : 0,
          'target': 1,
          'points': mission.points,
          'icon': Icons.flag_outlined,
          'color': const Color(0xFF36BFA0),
          'requiresApproval': mission.requiresApproval,
        };
    }
  }

  Future<void> _openMission(Map<String, dynamic> mission) async {
    if (mission['id'] == 'attendance') {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => const AttendanceCheckScreen(),
        ),
      );

      if (result == true && mounted) {
        setState(() {
          _isAttendanceCompleted = true;
          _completedDays.add(DateTime.now().day);
        });
      }

      return;
    }

    if (mission['id'] == 'photo_proof') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MissionProofUploadScreen(
            missionTitle: mission['title'] as String,
          ),
        ),
      );

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mission['title']} 기능은 다음 단계에서 구현합니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF5F5F8);
    const darkTextColor = Color(0xFF252735);
    const pinkColor = Color(0xFFFF68AE);
    const purpleColor = Color(0xFF8566FF);

    final monthlyMissions = _missions
        .where((mission) => !mission.requiresApproval)
        .map(_toMissionUiData)
        .toList();

    final challengeMissions = _missions
        .where((mission) => mission.requiresApproval)
        .map(_toMissionUiData)
        .toList();

    final missions = _selectedTab == 'monthly'
        ? monthlyMissions
        : challengeMissions;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F8),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '예산 미션 기록',
          style: TextStyle(
            color: darkTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
        children: [
          _buildSummaryCard(
            pinkColor: pinkColor,
            purpleColor: purpleColor,
          ),
          const SizedBox(height: 18),
          _buildMissionSection(
            missions: missions,
            pinkColor: pinkColor,
          ),
          const SizedBox(height: 18),
          _buildCalendarSection(
            pinkColor: pinkColor,
          ),
          const SizedBox(height: 18),
          _buildRewardSection(),
          const SizedBox(height: 18),
          _buildPointGuide(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required Color pinkColor,
    required Color purpleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pinkColor,
            purpleColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: purpleColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '7월 미션 성과',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '이번 달도 잘하고 있어요!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryStat(
                  label: '완료 미션',
                  value: '8개',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryStat(
                  label: '획득 포인트',
                  value: '850 P',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryStat(
                  label: '달성률',
                  value: '72%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                child: Text(
                  '월간 진행률',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '72%',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: 0.72,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSection({
    required List<Map<String, dynamic>> missions,
    required Color pinkColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '진행 중인 미션',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMissionTab(
                  value: 'monthly',
                  label: '월간 미션',
                  pinkColor: pinkColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMissionTab(
                  value: 'challenge',
                  label: '도전 미션',
                  pinkColor: pinkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...missions.map(
                (mission) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildMissionCard(
                mission: mission,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionTab({
    required String value,
    required String label,
    required Color pinkColor,
  }) {
    final isSelected = _selectedTab == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = value;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF252735)
              : const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : const Color(0xFF777A88),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMissionCard({
    required Map<String, dynamic> mission,
  }) {
    final progress = mission['progress'] as int;
    final target = mission['target'] as int;

    final isCompleted =
        target > 0 && progress >= target;

    final progressRate =
    target == 0 ? 0.0 : progress / target;

    return InkWell(
      onTap: () => _openMission(mission),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFFFF68AE)
                : const Color(0xFFE9EAF0),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: (mission['color'] as Color)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check
                        : mission['icon'] as IconData,
                    color: mission['color'] as Color,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission['title'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isCompleted
                            ? '오늘 미션을 완료했어요'
                            : mission['description'] as String,
                        style: const TextStyle(
                          color: Color(0xFF8F929E),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFFFEAF3)
                        : const Color(0xFFF0EDFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isCompleted
                        ? '완료'
                        : '+${mission['points']} P',
                    style: TextStyle(
                      color: isCompleted
                          ? const Color(0xFFFF68AE)
                          : const Color(0xFF8566FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: isCompleted ? 1 : progressRate,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE9EAF0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        mission['color'] as Color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isCompleted ? '완료' : '$progress / $target',
                  style: const TextStyle(
                    color: Color(0xFF878A96),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection({
    required Color pinkColor,
  }) {
    const daysInMonth = 31;
    const firstWeekday = 3;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '7월 미션 캘린더',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF979AA6),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              _CalendarLabel('일'),
              _CalendarLabel('월'),
              _CalendarLabel('화'),
              _CalendarLabel('수'),
              _CalendarLabel('목'),
              _CalendarLabel('금'),
              _CalendarLabel('토'),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 7,
              crossAxisSpacing: 7,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox();
              }

              final day = index - firstWeekday + 1;
              final isCompleted = _completedDays.contains(day);
              final isToday = day == DateTime.now().day;

              return Container(
                decoration: BoxDecoration(
                  color: isCompleted
                      ? pinkColor
                      : const Color(0xFFF2F3F6),
                  shape: BoxShape.circle,
                  border: isToday
                      ? Border.all(
                    color: const Color(0xFF8566FF),
                    width: 2,
                  )
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.white
                          : const Color(0xFF777A86),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRewardSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 획득 보상',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          _buildRewardItem(
            icon: Icons.calendar_month,
            title: '7일 연속 출석',
            date: '7월 14일',
            points: '+70 P',
            color: const Color(0xFFFF68AE),
          ),
          const Divider(height: 24),
          _buildRewardItem(
            icon: Icons.savings_outlined,
            title: '주간 예산 지키기',
            date: '7월 10일',
            points: '+150 P',
            color: const Color(0xFF8566FF),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardItem({
    required IconData icon,
    required String title,
    required String date,
    required String points,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: color,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                date,
                style: const TextStyle(
                  color: Color(0xFF9699A4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          points,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPointGuide() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFDFBC),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Color(0xFFE89B24),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '미션을 완료하면 포인트를 받을 수 있어요. 포인트는 아바타 상점에서 사용할 수 있습니다.',
              style: TextStyle(
                color: Color(0xFF8C8074),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarLabel extends StatelessWidget {
  final String text;

  const _CalendarLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF999CA7),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}