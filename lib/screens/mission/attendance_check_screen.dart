import 'package:flutter/material.dart';

import '../../services/mission_service.dart';
import '../../widgets/common/app_snack_bar.dart';

class AttendanceCheckScreen extends StatefulWidget {
  const AttendanceCheckScreen({super.key});

  @override
  State<AttendanceCheckScreen> createState() =>
      _AttendanceCheckScreenState();
}

class _AttendanceCheckScreenState
    extends State<AttendanceCheckScreen> {
  final MissionService _missionService = MissionService();
  // 사용자 안내 스낵바 표시 메서드
  void _showMessage(
      String message, {
        AppSnackBarType type = AppSnackBarType.info,
      }) {
    AppSnackBar.show(
      context,
      message: message,
      type: type,
    );
  }

  bool _isAttended = false;
  bool _isLoading = false;
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceStatus();
  }

  // 오늘 출석 완료 여부 조회 메서드
  Future<void> _loadAttendanceStatus() async {
    try {
      final bool isCompleted =
      await _missionService.isTodayAttendanceCompleted();

      if (!mounted) {
        return;
      }

      setState(() {
        _isAttended = isCompleted;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInitialLoading = false;
      });

      _showMessage(
        '출석 정보를 불러오지 못했습니다.',
        type: AppSnackBarType.error,
      );
    }
  }

  // 오늘 출석 처리 메서드
  Future<void> _checkAttendance() async {
    if (_isAttended || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool success =
      await _missionService.checkAttendance();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        if (success) {
          _isAttended = true;
        }
      });

      if (!success) {
        _showMessage(
          '출석 처리에 실패했습니다.',
          type: AppSnackBarType.error,
        );
        return;
      }

      _showMessage(
        '출석 완료! 10포인트를 획득했습니다.',
        type: AppSnackBarType.success,
      );

      await Future.delayed(
        const Duration(milliseconds: 1200),
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      final String message = e
          .toString()
          .replaceFirst('Exception: ', '');

      _showMessage(
        message,
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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