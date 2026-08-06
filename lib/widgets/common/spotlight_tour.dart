import 'package:flutter/material.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);

class SpotlightStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  const SpotlightStep({
    required this.targetKey,
    required this.title,
    required this.description,
  });
}

/// 첫 방문자에게 화면 핵심 요소를 하나씩 순서대로 하이라이트해서 보여주는
/// 스팟라이트 투어 컨트롤러. 대상 위젯에 GlobalKey만 붙이면 되고, 오버레이는
/// Overlay에 직접 꽂아 넣는 방식이라 기존 위젯 트리(레이아웃/스타일)를 전혀
/// 건드리지 않는다 — 화면이 어떻게 생겼든 위에서 얹어 쓸 수 있다.
class SpotlightTourController {
  OverlayEntry? _entry;
  List<SpotlightStep> _steps = const [];
  int _index = 0;
  BuildContext? _context;

  void start(BuildContext context, List<SpotlightStep> steps) {
    if (steps.isEmpty) return;
    _steps = steps;
    _index = 0;
    _context = context;
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  void _show() {
    final context = _context;
    if (context == null || !context.mounted) return;
    _entry?.remove();

    final step = _steps[_index];
    final renderBox = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) {
      // 대상이 화면에 없는 상태(스크롤 밖 등)면 이 스텝은 건너뛴다.
      _next();
      return;
    }
    final targetRect = (renderBox.localToGlobal(Offset.zero) & renderBox.size).inflate(8);

    _entry = OverlayEntry(
      builder: (_) => _SpotlightOverlay(
        targetRect: targetRect,
        title: step.title,
        description: step.description,
        stepIndex: _index,
        totalSteps: _steps.length,
        onNext: _next,
        onSkip: dispose,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  void _next() {
    _index++;
    if (_index >= _steps.length) {
      dispose();
      return;
    }
    _show();
  }

  void dispose() {
    _entry?.remove();
    _entry = null;
  }
}

class _SpotlightOverlay extends StatelessWidget {
  final Rect targetRect;
  final String title;
  final String description;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _SpotlightOverlay({
    required this.targetRect,
    required this.title,
    required this.description,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final spaceBelow = screenSize.height - targetRect.bottom;
    final showBelow = spaceBelow > 200;
    final isLast = stepIndex == totalSteps - 1;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onNext,
            child: CustomPaint(
              painter: _SpotlightPainter(targetRect: targetRect),
              size: Size.infinite,
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: showBelow ? targetRect.bottom + 16 : null,
          bottom: showBelow ? null : screenSize.height - targetRect.top + 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < totalSteps; i++)
                        Container(
                          margin: const EdgeInsets.only(right: 5),
                          width: i == stepIndex ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == stepIndex ? _accent : const Color(0xFFE8E4DE),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onSkip,
                        child: const Text('건너뛰기',
                            style:
                                TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _inkSub)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink)),
                  const SizedBox(height: 6),
                  Text(description,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w500, color: _inkSub, height: 1.4)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isLast ? '시작하기' : '다음',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  const _SpotlightPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final scrimPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath =
        Path()..addRRect(RRect.fromRectAndRadius(targetRect, const Radius.circular(18)));
    final combined = Path.combine(PathOperation.difference, scrimPath, holePath);
    canvas.drawPath(combined, Paint()..color = Colors.black.withValues(alpha: 0.72));
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect, const Radius.circular(18)),
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}
