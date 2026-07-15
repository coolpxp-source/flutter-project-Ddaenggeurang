import 'package:flutter/material.dart';

/// 사이드바(Drawer) 안의 메뉴 한 줄.
/// icon/title/destinationScreen만 넘기면 탭 시 사이드바 닫고 해당 화면으로 이동.
class DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget destinationScreen;
  final Color iconColor;
  final Color iconBg;

  const DrawerMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.destinationScreen,
    this.iconColor = _accent,
    this.iconBg = _accentSoft,
  });

  static const _accent = Color(0xFFF5A623);
  static const _accentSoft = Color(0xFFFFF0A6);
  static const _ink = Color(0xFF221A16);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      visualDensity: VisualDensity.compact,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
      onTap: () {
        Navigator.pop(context); // 사이드바 먼저 닫기
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => destinationScreen),
        );
      },
    );
  }
}

/// 메뉴 그룹 제목 (예: "지출/수입", "저축/투자" 같은 섹션 구분용)
class DrawerSectionLabel extends StatelessWidget {
  final String label;

  const DrawerSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8A7E77),
        ),
      ),
    );
  }
}