import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/user_service.dart';
import 'ddaeng_modal.dart';

const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _accent = Color(0xFFF5A623);

/// 룰렛 8칸의 포인트 값 — 0은 꽝. 합계 대비 확률은 그냥 균등(칸 1개=1/8)이라
/// 큰 값(50P)이 자주 나오지 않게 칸 수를 적게 배치했다.
const _prizes = [5, 10, 10, 15, 20, 0, 10, 50];
const _wheelColors = [
  Color(0xFFF5A623), // amber
  Color(0xFFFF6F91), // pink
  Color(0xFF6C5CE7), // purple
  Color(0xFF4F7DF3), // blue
  Color(0xFF00A98A), // mint
  Color(0xFFB0A89F), // 꽝(회색)
  Color(0xFFFFC93C), // gold
  Color(0xFFF04438), // red
];

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
  bool _spinning = false;
  bool _claimed = false;
  int? _resultPoints;
  bool _dontShowToday = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_spinning || _claimed) return;
    setState(() => _spinning = true);

    final index = Random().nextInt(_prizes.length);
    final segAngle = 2 * pi / _prizes.length;
    final centerAngle = -pi / 2 + index * segAngle + segAngle / 2;
    var baseRotation = (-pi / 2 - centerAngle) % (2 * pi);
    if (baseRotation < 0) baseRotation += 2 * pi;
    final target = 4 * 2 * pi + baseRotation; // 4바퀴 더 돌고 정확한 칸에 멈춤

    _rotation = Tween<double>(begin: 0, end: target)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller
      ..reset()
      ..forward();
    await Future.delayed(_controller.duration!);

    final points = _prizes[index];
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _claimed = true;
      _resultPoints = points;
    });
    if (points > 0) {
      await UserService().addPoints(widget.uid, points);
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
          const SizedBox(height: 6),
          Text(
            _claimed
                ? (_resultPoints! > 0 ? '오늘도 좋은 하루 되세요!' : '내일 다시 도전해보세요!')
                : '오늘 첫 방문이네요! 룰렛을 돌려보세요',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: _inkSub),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _rotation,
                  builder: (context, child) =>
                      Transform.rotate(angle: _rotation.value, child: child),
                  child: CustomPaint(
                    size: const Size(220, 220),
                    painter: const _WheelPainter(),
                  ),
                ),
                Positioned(
                  top: -8,
                  child: Icon(Icons.arrow_drop_down_rounded, size: 42, color: _ink.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (_claimed) ...[
            Text(
              _resultPoints! > 0 ? '🎉 ${_resultPoints}P 획득!' : '아쉽지만 꽝이에요',
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
  const _WheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final segAngle = 2 * pi / _prizes.length;

    for (int i = 0; i < _prizes.length; i++) {
      final startAngle = -pi / 2 + i * segAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segAngle,
        true,
        Paint()..color = _wheelColors[i % _wheelColors.length],
      );
      canvas.drawLine(
        center,
        center + Offset(cos(startAngle), sin(startAngle)) * radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 2,
      );

      final labelAngle = startAngle + segAngle / 2;
      final labelPos = center + Offset(cos(labelAngle), sin(labelAngle)) * (radius * 0.66);
      final label = _prizes[i] > 0 ? '${_prizes[i]}P' : '꽝';
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

    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
