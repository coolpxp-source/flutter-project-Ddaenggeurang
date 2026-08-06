import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/brand_loading_dots.dart';

const _mintSoft = Color(0xFFD9F2EC);
const _gold = Color(0xFFFFC93C);
const _goldSoft = Color(0xFFFFF0C2);

const _kFall = Duration(milliseconds: 1000); // 로고가 동전처럼 떨어져 저금통에 들어가는 낙하+바운스 시간
const _kImpact = Duration(milliseconds: 600); // 첫 착지(땡그랑!) 시점 — 플래시/반짝임은 이 타이밍에 맞춘다
const _kEntrance = Duration(milliseconds: 1330); // 로고 등장 애니메이션(낙하+찌그러짐 임팩트) 완료 시점
const _kHold = Duration(milliseconds: 1400);

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
                      // 착지 그림자 — 코인이 가까워질수록(낙하할수록) 커지고 진해져서
                      // "저금통 바닥으로 다가온다"는 원근감을 준다. 착지 순간 살짝 눌렸다 편다.
                      Positioned(
                        bottom: 22,
                        child: Container(
                          width: 150,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.22),
                                Colors.black.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(duration: _kFall, curve: Curves.easeIn)
                            .scaleXY(begin: 0.25, end: 1.0, duration: _kFall, curve: Curves.easeIn)
                            .then()
                            .scaleXY(begin: 1.0, end: 0.82, duration: 130.ms, curve: Curves.easeOut)
                            .then()
                            .scaleXY(begin: 0.82, end: 1.0, duration: 200.ms, curve: Curves.easeOutBack),
                      ),

                      // 임팩트 플래시 — 동전(로고)이 저금통 바닥에 땡그랑 떨어지는 순간 터지는 빛
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
                          .animate(delay: _kImpact)
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
                                  delay: _kImpact + s.delay,
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

                      // 로고: 멀리서 작게 시작해 떨어지며 커지다가(원근감) 저금통 바닥에
                      // 통통 튀며 착지 + 찌그러졌다 펴지는 임팩트, 이후 은은한 숨쉬기 루프
                      Image.asset('assets/images/ddaeng_logo_transparent_trimmed.png', width: 232)
                          .animate()
                          .fadeIn(duration: 120.ms, curve: Curves.easeOut)
                          .moveY(
                              begin: -260, end: 0, duration: _kFall, curve: Curves.bounceOut)
                          .scale(
                              begin: const Offset(0.55, 0.55),
                              end: const Offset(1, 1),
                              duration: _kFall,
                              curve: Curves.easeIn)
                          .rotate(begin: -0.28, end: 0, duration: 540.ms, curve: Curves.easeOut)
                          .then()
                          .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.12, 0.82),
                              duration: 130.ms,
                              curve: Curves.easeOut)
                          .then()
                          .scale(
                              begin: const Offset(1.12, 0.82),
                              end: const Offset(1, 1),
                              duration: 200.ms,
                              curve: Curves.easeOutBack)
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
