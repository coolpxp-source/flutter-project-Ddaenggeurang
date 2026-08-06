import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/user_service.dart';
import 'ddaeng_modal.dart';

const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _accent = Color(0xFFF5A623);

/// 룰렛 10칸의 포인트 값 — 0은 꽝, null은 "다시"(즉시 재도전) 칸.
/// 칸 수로 확률을 조정한다: 10P가 제일 많고(3칸=30%) 그다음 꽝(2칸=20%),
/// 나머지 5P/15P/20P/50P/다시는 1칸씩(각 10%).
const List<int?> _prizes = [10, 0, 10, 5, 10, 15, null, 20, 0, 50];

/// 5일 연속 출석마다(loginStreak이 5의 배수) 획득 포인트를 2배로 준다.
const _doubleDayStreakUnit = 5;

Color _colorForPrize(int? prize) {
  if (prize == null) return const Color(0xFF6C5CE7); // 다시 - 보라
  switch (prize) {
    case 50:
      return const Color(0xFFF04438); // red
    case 20:
      return const Color(0xFF00A98A); // mint
    case 15:
      return const Color(0xFF4F7DF3); // blue
    case 10:
      return const Color(0xFFF5A623); // amber
    case 5:
      return const Color(0xFFFF6F91); // pink
    default:
      return const Color(0xFFB0A89F); // 꽝 - 회색
  }
}

String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);
String _prefsKey(String uid) => 'lastRouletteDate_$uid';

/// 홈 화면 진입 시 하루 한 번(체크 안 하면 세션마다) 띄울지 판단한다.
Future<bool> shouldShowAttendanceRoulette(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefsKey(uid)) != _todayKey();
}

Future<void> _markHandledToday(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey(uid), _todayKey());
}

/// 출석 룰렛 모달을 띄운다. 이미 오늘 처리(스핀 또는 "오늘은 그만 보기")됐으면
/// 호출부에서 [shouldShowAttendanceRoulette]로 먼저 걸러야 한다.
Future<void> showAttendanceRoulette(BuildContext context, {required String uid}) {
  return DdaengModal.custom<void>(
    context,
    child: _RouletteContent(uid: uid),
  );
}

class _RouletteContent extends StatefulWidget {
  final String uid;
  const _RouletteContent({required this.uid});

  @override
  State<_RouletteContent> createState() => _RouletteContentState();
}

class _RouletteContentState extends State<_RouletteContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double> _rotation = const AlwaysStoppedAnimation(0);
  double _currentRotation = 0;
  bool _spinning = false;
  bool _claimed = false;
  int? _resultPoints;
  bool _dontShowToday = false;
  bool _doubleDay = false;
  int _streak = 0;
  String? _retryMessage;

  int get _streakIntoCycle => _streak % _doubleDayStreakUnit;
  int get _daysUntilDoubleDay =>
      _doubleDay ? 0 : _doubleDayStreakUnit - _streakIntoCycle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _loadDoubleDayStatus();
  }

  // 홈 화면 진입 시마다 새로 계산되는 loginStreak을 그대로 읽어서 판단한다
  // (룰렛 전용 카운터를 따로 두지 않고 기존 연속출석 데이터를 재사용).
  Future<void> _loadDoubleDayStatus() async {
    final profile = await UserService().getUser(widget.uid);
    final streak = profile?.loginStreak ?? 0;
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _doubleDay = streak > 0 && streak % _doubleDayStreakUnit == 0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || _claimed) return;
    setState(() {
      _spinning = true;
      _retryMessage = null;
    });

    final index = Random().nextInt(_prizes.length);
    final segAngle = 2 * pi / _prizes.length;
    final centerAngle = -pi / 2 + index * segAngle + segAngle / 2;
    var baseRotation = (-pi / 2 - centerAngle) % (2 * pi);
    if (baseRotation < 0) baseRotation += 2 * pi;
    // "다시" 재도전 시 바퀴가 0으로 스냅되지 않도록, 현재 각도 기준으로
    // 이어서 몇 바퀴 더 돌아 목표 칸(baseRotation)에 멈추게 계산한다.
    final currentMod = _currentRotation % (2 * pi);
    var delta = (baseRotation - currentMod) % (2 * pi);
    if (delta < 0) delta += 2 * pi;
    final target = _currentRotation + 4 * 2 * pi + delta;

    _rotation = Tween<double>(begin: _currentRotation, end: target)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller
      ..reset()
      ..forward();
    await Future.delayed(_controller.duration!);
    _currentRotation = target;

    final prize = _prizes[index];
    if (!mounted) return;

    if (prize == null) {
      // 다시 칸 — 오늘 처리 완료로 마크하지 않고 바로 재도전 가능하게 둔다.
      setState(() {
        _spinning = false;
        _retryMessage = '다시 나왔어요! 한 번 더 돌려보세요 🔄';
      });
      return;
    }

    final awarded = _doubleDay ? prize * 2 : prize;
    setState(() {
      _spinning = false;
      _claimed = true;
      _resultPoints = awarded;
    });
    if (awarded > 0) {
      await UserService().addPoints(widget.uid, awarded);
    }
    await _markHandledToday(widget.uid);
  }

  Future<void> _close() async {
    if (_dontShowToday && !_claimed) {
      await _markHandledToday(widget.uid);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('출석 룰렛 🎰',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _ink)),
          if (_doubleDay) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFC93C), Color(0xFFF5A623)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉 오늘은 ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Text('×2',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFFFFF6D8))),
                  const Text(' 찬스!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Row(
              children: List.generate(_doubleDayStreakUnit, (i) {
                final dayNum = i + 1;
                final filled = dayNum <= _streakIntoCycle;
                final isBonusSlot = dayNum == _doubleDayStreakUnit;
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: isBonusSlot ? 0 : 5),
                    height: 24,
                    decoration: BoxDecoration(
                      color: filled
                          ? (isBonusSlot ? const Color(0xFFFFC93C) : _accent)
                          : const Color(0xFFF0EAE3),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: filled
                          ? [
                              BoxShadow(
                                  color: (isBonusSlot ? const Color(0xFFFFC93C) : _accent)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2)),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: isBonusSlot
                        ? Text('×2',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: filled ? Colors.white : const Color(0xFFC79A2E)))
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 5),
            Text('$_daysUntilDoubleDay일 후 2배 찬스',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _inkSub)),
          ],
          const SizedBox(height: 6),
          Text(
            _claimed
                ? (_resultPoints! > 0 ? '오늘도 좋은 하루 되세요!' : '내일 다시 도전해보세요!')
                : (_retryMessage ?? '오늘 첫 방문이네요! 룰렛을 돌려보세요'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _inkSub),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 220,
            height: 232,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 12,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: _rotation,
                      builder: (context, child) =>
                          Transform.rotate(angle: _rotation.value, child: child),
                      child: CustomPaint(
                        size: const Size(220, 220),
                        painter: _WheelPainter(doubleDay: _doubleDay),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 5, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_drop_down_rounded, size: 36, color: _accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_claimed) ...[
            Text(
              _resultPoints! > 0
                  ? '🎉 ${_resultPoints}P 획득!${_doubleDay ? ' (2배 적용)' : ''}'
                  : '아쉽지만 꽝이에요',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _resultPoints! > 0 ? _accent : _inkSub),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _close,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('확인', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _spinning ? null : _spin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: const Color(0xFFFFE9A8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _spinning
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('룰렛 돌리기', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: _dontShowToday,
                    onChanged: (v) => setState(() => _dontShowToday = v ?? false),
                    activeColor: _accent,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('오늘은 그만 보기',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _inkSub)),
                const Spacer(),
                TextButton(
                  onPressed: _close,
                  style: TextButton.styleFrom(foregroundColor: _inkSub),
                  child: const Text('닫기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final bool doubleDay;
  const _WheelPainter({required this.doubleDay});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outerRadius = size.width / 2;
    // 바깥 금색 베젤 — 카지노 룰렛 느낌의 두꺼운 테두리.
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFFE9A8), Color(0xFFE8A73C)])
            .createShader(Rect.fromCircle(center: center, radius: outerRadius)),
    );

    final radius = outerRadius - 9;
    final segAngle = 2 * pi / _prizes.length;

    for (int i = 0; i < _prizes.length; i++) {
      final startAngle = -pi / 2 + i * segAngle;
      final prize = _prizes[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle,
        true,
        Paint()..color = _colorForPrize(prize),
      );
      canvas.drawLine(
        center,
        center + Offset(cos(startAngle), sin(startAngle)) * radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 2,
      );

      final labelAngle = startAngle + segAngle / 2;
      final labelPos = center + Offset(cos(labelAngle), sin(labelAngle)) * (radius * 0.64);
      // 2배 찬스인 날은 칸에 적힌 숫자 자체를 실제 지급액(2배)으로 보여준다.
      final displayValue = (prize != null && doubleDay) ? prize * 2 : prize;
      final label = displayValue == null ? '다시' : (displayValue > 0 ? '${displayValue}P' : '꽝');
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(labelPos.dx, labelPos.dy);
      canvas.rotate(labelAngle + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // 유리 같은 광택 하이라이트 — 좌상단에 은은한 흰색 그라데이션을 덧씌운다.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    final glossCenter = center.translate(-radius * 0.15, -radius * 0.4);
    canvas.drawCircle(
      glossCenter,
      radius * 0.85,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: glossCenter, radius: radius * 0.85)),
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    // 중앙 허브 — 금색 그라데이션 + 흰 테두리.
    canvas.drawCircle(center, 13, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFFF6D8), Color(0xFFFFC93C)])
            .createShader(Rect.fromCircle(center: center, radius: 10)),
    );
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => oldDelegate.doubleDay != doubleDay;
}
