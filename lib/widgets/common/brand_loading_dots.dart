import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const _mint = Color(0xFF63C5B5);
const _gold = Color(0xFFFFC93C);

/// 브랜드 컬러(민트/골드)로 순서대로 튀어오르는 3점 로딩 인디케이터.
/// 스플래시 화면, 공용 로딩 화면 등에서 재사용.
class BrandLoadingDots extends StatelessWidget {
  final double dotSize;
  const BrandLoadingDots({super.key, this.dotSize = 8});

  @override
  Widget build(BuildContext context) {
    final colors = [_mint, _gold, _mint];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: dotSize * 0.5),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
          )
              .animate(
                delay: Duration(milliseconds: 150 * i),
                onPlay: (c) => c.repeat(reverse: true),
              )
              .moveY(begin: 0, end: -dotSize, duration: 500.ms, curve: Curves.easeInOut)
              .fadeIn(duration: 500.ms),
        );
      }),
    );
  }
}
