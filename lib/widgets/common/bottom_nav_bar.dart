import 'package:flutter/material.dart';

enum NavTab { home, expense, aiConsult, community, myPage }

class BottomNavBar extends StatelessWidget {
  final NavTab currentTab;
  final ValueChanged<NavTab> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  static const Color activeColor = Color(0xFFF5A623);
  static const Color inactiveColor = Color(0xFFACA49E);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildItem(NavTab.home, Icons.home, '홈'),
            _buildItem(NavTab.expense, Icons.description, '지출'),
            _buildItem(NavTab.aiConsult, Icons.chat_bubble, 'AI상담'),
            _buildItem(NavTab.community, Icons.groups, '커뮤니티'),
            _buildItem(NavTab.myPage, Icons.person, '마이'),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(NavTab tab, IconData icon, String label) {
    final bool isActive = currentTab == tab;
    final Color color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () => onTabSelected(tab),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            // 활성 탭 밑 인디케이터 바
            Container(
              width: 24,
              height: 2.5,
              decoration: BoxDecoration(
                color: isActive ? activeColor : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}