import 'package:flutter/material.dart';

import '../../services/mission_service.dart';

class AttendanceCheckScreen extends StatefulWidget {
  const AttendanceCheckScreen({super.key});

  @override
  State<AttendanceCheckScreen> createState() =>
      _AttendanceCheckScreenState();
}

class _AttendanceCheckScreenState
    extends State<AttendanceCheckScreen> {
  final MissionService _missionService = MissionService();

  bool _isAttended = false;
  bool _isLoading = false;

  Future<void> _checkAttendance() async {
    if (_isAttended || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final success = await _missionService.checkAttendance();

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (success) {
        _isAttended = true;
      }
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('출석 완료! 10포인트를 획득했습니다.'),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('출석 체크'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isAttended
                  ? Icons.check_circle
                  : Icons.calendar_today,
              size: 100,
            ),
            const SizedBox(height: 24),
            Text(
              _isAttended
                  ? '오늘 출석을 완료했습니다!'
                  : '오늘도 출석하고 포인트를 받아보세요.',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '출석 보상 10포인트',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isAttended || _isLoading
                    ? null
                    : _checkAttendance,
                child: Text(
                  _isLoading
                      ? '처리 중...'
                      : _isAttended
                      ? '출석 완료'
                      : '출석 체크',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}