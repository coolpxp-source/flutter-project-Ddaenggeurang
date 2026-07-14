import 'package:flutter/material.dart';

/// 사이드바(Drawer) 안의 메뉴 한 줄.
/// icon/title/destinationScreen만 넘기면 탭 시 사이드바 닫고 해당 화면으로 이동.
class DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget destinationScreen;

  const DrawerMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.destinationScreen,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}