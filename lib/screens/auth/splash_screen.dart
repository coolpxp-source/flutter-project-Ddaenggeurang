import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/brand_loading_dots.dart';

const _mintSoft = Color(0xFFD9F2EC);
const _gold = Color(0xFFFFC93C);
const _goldSoft = Color(0xFFFFF0C2);

const _kEntrance = Duration(milliseconds: 550);
const _kHold = Duration(milliseconds: 1500);

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(_kEntrance + _kHold, widget.onFinished);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, _mintSoft, Colors.white],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ── 은은하게 떠다니는 배경 블롭 ──
            Positioned(
              top: 90,
              left: 10,
              child: _Blob(color: _mintSoft, size: 130)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: 18, duration: 3200.ms, curve: Curves.easeInOut),
            ),
            Positioned(
              bottom: 130,
              right: 10,
              child: _Blob(color: _goldSoft, size: 110)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -14, duration: 2800.ms, curve: Curves.easeInOut),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  height: 280,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // 임팩트 플래시 — 로고가 팍! 하고 등장하는 순간 터지는 빛
                      Container(
                        width: 260,
                        height: 260,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [_goldSoft, Colors.transparent],
                          ),
                        ),
                      )
                          .animate(delay: _kEntrance)
                          .fadeIn(duration: 1.ms)
                          .scale(
                              begin: const Offset(0.2, 0.2),
                              end: const Offset(1.3, 1.3),
                              duration: 420.ms,
                              curve: Curves.easeOut)
                          .fadeOut(duration: 420.ms, curve: Curves.easeOut),

                      // 반짝임 파티클 (로고 주변)
                      ..._sparkles.map((s) => Positioned(
                            left: s.dx,
                            top: s.dy,
                            child: Icon(Icons.auto_awesome_rounded, size: s.size, color: _gold)
                                .animate(
                                  delay: _kEntrance + s.delay,
                                  onPlay: (c) => c.repeat(),
                                )
                                .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                                .scale(
                                    begin: const Offset(0.4, 0.4),
                                    end: const Offset(1, 1),
                                    duration: 400.ms)
                                .then(delay: 600.ms)
                                .fadeOut(duration: 400.ms)
                                .scale(begin: const Offset(1, 1), end: const Offset(0.4, 0.4)),
                          )),

                      // 로고: 확! 팝인 등장(탄성) 후 은은한 숨쉬기 루프
                      Image.asset('assets/images/ddaeng_logo_transparent_trimmed.png', width: 232)
                          .animate()
                          .fadeIn(duration: 180.ms, curve: Curves.easeOut)
                          .scale(
                              begin: const Offset(0.35, 0.35),
                              end: const Offset(1, 1),
                              duration: _kEntrance,
                              curve: Curves.elasticOut)
                          .rotate(
                              begin: -0.05, end: 0, duration: _kEntrance, curve: Curves.easeOut)
                          .then()
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                              begin: 1.0, end: 1.03, duration: 1600.ms, curve: Curves.easeInOut),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const BrandLoadingDots()
                    .animate()
                    .fadeIn(delay: _kEntrance + 250.ms, duration: 350.ms),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Sparkle {
  final double dx;
  final double dy;
  final double size;
  final Duration delay;
  const _Sparkle(this.dx, this.dy, this.size, this.delay);
}

const _sparkles = [
  _Sparkle(4, 30, 18, Duration(milliseconds: 0)),
  _Sparkle(248, 22, 14, Duration(milliseconds: 180)),
  _Sparkle(10, 220, 12, Duration(milliseconds: 360)),
  _Sparkle(252, 226, 16, Duration(milliseconds: 90)),
];

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}
