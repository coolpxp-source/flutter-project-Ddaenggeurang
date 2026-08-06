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
    const Color backgroundColor = Color(0xFFF7F6FA);
    const Color pinkColor = Color(0xFFFF68AE);
    const Color purpleColor = Color(0xFF8566FF);
    const Color darkTextColor = Color(0xFF252735);

    if (_isInitialLoading) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: purpleColor,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '출석 체크',
          style: TextStyle(
            color: darkTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            22,
            18,
            22,
            28,
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(
                  24,
                  28,
                  24,
                  26,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isAttended
                        ? const [
                      Color(0xFF8566FF),
                      Color(0xFF5F8DFF),
                    ]
                        : const [
                      Color(0xFFFF79B5),
                      Color(0xFF8566FF),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: purpleColor.withValues(alpha: 0.24),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.42),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedSwitcher(
                        duration:
                        const Duration(milliseconds: 350),
                        transitionBuilder: (
                            Widget child,
                            Animation<double> animation,
                            ) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Icon(
                          _isAttended
                              ? Icons.verified_rounded
                              : Icons.calendar_month_rounded,
                          key: ValueKey<bool>(_isAttended),
                          size: 72,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _isAttended
                          ? '오늘 출석 완료!'
                          : '오늘도 출석해볼까요?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isAttended
                          ? '10포인트가 지급되었습니다.'
                          : '매일 출석하고 포인트를 모아보세요.',
                      style: TextStyle(
                        color:
                        Colors.white.withValues(alpha: 0.88),
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color:
                        Colors.white.withValues(alpha: 0.18),
                        borderRadius:
                        BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(
                            alpha: 0.32,
                          ),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monetization_on_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '오늘의 출석 보상 +10P',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEAF3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: pinkColor,
                      ),
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            '꾸준한 출석이 중요해요',
                            style: TextStyle(
                              color: darkTextColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '출석 보상은 하루에 한 번만 받을 수 있어요.',
                            style: TextStyle(
                              color: Color(0xFF8F929E),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _isAttended
                        ? null
                        : const LinearGradient(
                      colors: [
                        Color(0xFFFF68AE),
                        Color(0xFF8566FF),
                      ],
                    ),
                    color: _isAttended
                        ? const Color(0xFFE9EAF0)
                        : null,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: _isAttended
                        ? null
                        : [
                      BoxShadow(
                        color: purpleColor.withValues(
                          alpha: 0.22,
                        ),
                        blurRadius: 14,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isAttended || _isLoading
                        ? null
                        : _checkAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor:
                      Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(18),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : Row(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isAttended
                              ? Icons.check_rounded
                              : Icons.touch_app_rounded,
                          color: _isAttended
                              ? const Color(0xFF999CA7)
                              : Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isAttended
                              ? '오늘 출석 완료'
                              : '출석 도장 찍기',
                          style: TextStyle(
                            color: _isAttended
                                ? const Color(0xFF999CA7)
                                : Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}