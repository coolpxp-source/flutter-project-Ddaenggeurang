import 'package:flutter/material.dart';
import '../../services/home_refresh_service.dart';
import '../../screens/expense/expense_input_screen.dart';
import '../../screens/income/income_input_screen.dart';
import '../../screens/saving/saving_input_screen.dart';
import '../../screens/record/bulk_record_screen.dart';

/// 홈 화면 우측 하단 빠른 기록 FAB.
/// 탭하면 사진업로드/퉁치기/저축/수입/지출 5개 미니 버튼이 세로로 순차 등장한다.
class QuickAddFab extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onToggle;
  const QuickAddFab({super.key, required this.isOpen, required this.onToggle});

  @override
  State<QuickAddFab> createState() => _QuickAddFabState();
}

class _QuickAddFabState extends State<QuickAddFab> with SingleTickerProviderStateMixin {
  // home_screen.dart의 _C 팔레트와 동일한 값 (private이라 직접 참조 불가해 복제)
  static const _mint = Color(0xFF00C2A8);
  static const _amberDeep = Color(0xFF8A5200);
  static const _amber = Color(0xFFFFA733);
  static const _blue = Color(0xFF4F7DF3);
  static const _purple = Color(0xFF6C5CE7);
  static const _expense = Color(0xFFF04438);
  static const _ink = Color(0xFF221A20);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  // 아이템 5개를 순차적으로(계단식) 등장시키기 위한 Interval 애니메이션.
  // 열릴 때는 맨 아래(지출)부터 위(사진업로드)로, 리스트 순서상 index 0(사진업로드)이
  // 화면에서는 맨 위에 있으므로 staggerFactor로 역순 딜레이를 준다.
  late final List<Animation<double>> _itemAnimations = List.generate(5, (i) {
    final reversedIndex = 4 - i; // 지출(마지막)이 가장 먼저 튀어나오게
    final start = reversedIndex * 0.10;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOutBack),
      reverseCurve: Interval(start, end, curve: Curves.easeIn),
    );
  });

  @override
  void didUpdateWidget(covariant QuickAddFab old) {
    super.didUpdateWidget(old);
    if (widget.isOpen != old.isOpen) {
      if (widget.isOpen) {
        _controller.forward(from: 0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(BuildContext context, Widget screen) {
    widget.onToggle();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => HomeRefreshService.requestRefresh());
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (
      label: '사진 업로드',
      icon: Icons.camera_alt_outlined,
      color: _mint,
      onTap: () => _go(context, const ExpenseInputScreen()),
      ),
      (
      label: '퉁치기',
      icon: Icons.flash_on_rounded,
      color: _amberDeep,
      onTap: () => _go(context, const BulkRecordScreen()),
      ),
      (
      label: '저축',
      icon: Icons.savings_outlined,
      color: _blue,
      onTap: () => _go(context, const SavingInputScreen()),
      ),
      (
      label: '수입',
      icon: Icons.add_card_rounded,
      color: _purple,
      onTap: () => _go(context, const IncomeInputScreen()),
      ),
      (
      label: '지출',
      icon: Icons.remove_circle_outline_rounded,
      color: _expense,
      onTap: () => _go(context, const ExpenseInputScreen()),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // 애니메이션 값이 0에 완전히 수렴하면 레이아웃 공간 자체를 접어서
            // 닫혀 있을 때 불필요한 빈 여백이 안 남게 한다.
            final anyVisible = _itemAnimations.any((a) => a.value > 0.001);
            if (!anyVisible) return const SizedBox.shrink();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _AnimatedMiniFabItem(
                    animation: _itemAnimations[i],
                    label: items[i].label,
                    icon: items[i].icon,
                    color: items[i].color,
                    onTap: items[i].onTap,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        ),
        FloatingActionButton(
          onPressed: widget.onToggle,
          backgroundColor: widget.isOpen ? Colors.white : _amber,
          elevation: 6,
          child: AnimatedRotation(
            turns: widget.isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.add, color: widget.isOpen ? _ink : Colors.white),
          ),
        ),
      ],
    );
  }
}

/// 등장/퇴장 시 페이드 + 오른쪽에서 슬라이드 + 살짝 스케일되는 미니 버튼 한 줄.
class _AnimatedMiniFabItem extends StatelessWidget {
  final Animation<double> animation;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedMiniFabItem({
    required this.animation,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final value = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(24 * (1 - value), 0),
            child: Transform.scale(
              scale: 0.7 + (0.3 * value),
              alignment: Alignment.centerRight,
              child: child,
            ),
          ),
        );
      },
      child: IgnorePointer(
        ignoring: animation.value < 0.5,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF221A20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              heroTag: label,
              onPressed: onTap,
              backgroundColor: color,
              elevation: 5,
              child: Icon(icon, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}