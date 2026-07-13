import 'package:flutter/material.dart';

import 'attendance_check_screen.dart';
import '../avatar/point_shop_screen.dart';

class MissionListScreen extends StatefulWidget {
  const MissionListScreen({super.key});

  @override
  State<MissionListScreen> createState() => _MissionListScreenState();
}

class _MissionListScreenState extends State<MissionListScreen> {
  bool _isAttendanceCompleted = false;

  final List<Map<String, dynamic>> _missions = [
    {
      'id': 'attendance',
      'title': '출석 체크',
      'description': '매일 1회',
      'points': 10,
      'icon': Icons.event_available,
      'enabled': true,
    },
    {
      'id': 'budget',
      'title': '예산 안에서 소비하기',
      'description': '오늘 지출이 예산 이내예요',
      'points': 20,
      'icon': Icons.track_changes,
      'enabled': true,
    },
    {
      'id': 'share',
      'title': '친구에게 앱 공유하기',
      'description': '최초 1회',
      'points': 50,
      'icon': Icons.share,
      'enabled': false,
    },
  ];

  final List<Map<String, dynamic>> _avatarItems = [
    {
      'name': '모자',
      'price': 300,
      'icon': Icons.checkroom,
    },
    {
      'name': '신발',
      'price': 200,
      'icon': Icons.ice_skating,
    },
  ];

  Future<void> _openMission(Map<String, dynamic> mission) async {
    if (mission['enabled'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아직 참여할 수 없는 미션입니다.'),
        ),
      );
      return;
    }

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
        });
      }

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${mission['title']} 기능은 다음 단계에서 구현합니다.'),
      ),
    );
  }

  void _openPointShop() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PointShopScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF20A67A);
    const backgroundColor = Color(0xFFF7F8F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text(
          '미션',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF26332F),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _buildPointCard(primaryColor),
            const SizedBox(height: 24),

            const Text(
              '오늘의 미션',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF52615C),
              ),
            ),
            const SizedBox(height: 12),

            ..._missions.map((mission) {
              final isCompleted =
                  mission['id'] == 'attendance' &&
                      _isAttendanceCompleted;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildMissionCard(
                  mission: mission,
                  isCompleted: isCompleted,
                  primaryColor: primaryColor,
                ),
              );
            }),

            const SizedBox(height: 20),
            _buildAvatarHeader(primaryColor),
            const SizedBox(height: 12),
            _buildAvatarPreview(primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPointCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '보유 포인트',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF71817B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '2,450 P',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF26332F),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: _openPointShop,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('상점 가기'),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard({
    required Map<String, dynamic> mission,
    required bool isCompleted,
    required Color primaryColor,
  }) {
    final enabled = mission['enabled'] == true;
    final cardEnabled = enabled && !isCompleted;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: cardEnabled
            ? () => _openMission(mission)
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8ECEA),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cardEnabled
                      ? const Color(0xFFEAF8F2)
                      : const Color(0xFFF1F2F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check
                      : mission['icon'] as IconData,
                  color: cardEnabled
                      ? primaryColor
                      : const Color(0xFFB8BDBB),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission['title'] as String,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: cardEnabled
                            ? const Color(0xFF35413D)
                            : const Color(0xFFB1B5B3),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mission['description'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: cardEnabled
                            ? const Color(0xFF89928F)
                            : const Color(0xFFC1C5C3),
                      ),
                    ),
                  ],
                ),
              ),
              _buildMissionStatus(
                mission: mission,
                isCompleted: isCompleted,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionStatus({
    required Map<String, dynamic> mission,
    required bool isCompleted,
    required Color primaryColor,
  }) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F7F1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '✓ 완료',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: mission['enabled'] == true
            ? primaryColor
            : const Color(0xFFF0F1F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '+${mission['points']} P',
        style: TextStyle(
          color: mission['enabled'] == true
              ? Colors.white
              : const Color(0xFFBEC2C0),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildAvatarHeader(Color primaryColor) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '아바타 꾸미기',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF52615C),
            ),
          ),
        ),
        TextButton(
          onPressed: _openPointShop,
          child: Text(
            '전체 보기',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPreview(Color primaryColor) {
    return Row(
      children: _avatarItems.map((item) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: item == _avatarItems.first ? 8 : 0,
              left: item == _avatarItems.last ? 8 : 0,
            ),
            child: InkWell(
              onTap: _openPointShop,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 145,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE8ECEA),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF8F3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF586560),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item['price']} P',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}