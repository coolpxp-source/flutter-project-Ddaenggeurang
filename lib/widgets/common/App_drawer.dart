import 'package:flutter/material.dart';
import 'Drawer_menu_item.dart';
import 'Placeholder_screen.dart';
import '../../screens/expense/expense_input_screen.dart';

/// 앱 전체에서 공용으로 쓰는 사이드바.
/// 사용법: 각 화면 Scaffold에 drawer: const AppDrawer() 한 줄만 추가.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                '메뉴',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),

          const DrawerSectionLabel(label: '내역 입력 및 조회'),
          DrawerMenuItem(
            icon: Icons.edit_note,
            title: '수입/지출 기록하기',
            destinationScreen: const ExpenseInputScreen(),
          ),
          const DrawerMenuItem(
            icon: Icons.camera_alt_outlined,
            title: '영수증 촬영 업로드',
            destinationScreen: PlaceholderScreen(title: '영수증 촬영 업로드'),
          ),
          const DrawerMenuItem(
            icon: Icons.sms_outlined,
            title: '문자내역 붙여넣기',
            destinationScreen: PlaceholderScreen(title: '문자내역 붙여넣기'),
          ),
          const DrawerMenuItem(
            icon: Icons.list_alt,
            title: '내역 목록',
            destinationScreen: PlaceholderScreen(title: '내역 목록'),
          ),

          const Divider(),
          const DrawerSectionLabel(label: '저축 / 투자'),
          const DrawerMenuItem(
            icon: Icons.savings_outlined,
            title: '저축/투자 기록',
            destinationScreen: PlaceholderScreen(title: '저축/투자 기록'),
          ),

          const Divider(),
          const DrawerSectionLabel(label: '자동 등록 관리'),
          const DrawerMenuItem(
            icon: Icons.credit_card,
            title: '할부 관리',
            destinationScreen: PlaceholderScreen(title: '할부 관리'),
          ),
          const DrawerMenuItem(
            icon: Icons.autorenew,
            title: '구독/정기결제 관리',
            destinationScreen: PlaceholderScreen(title: '구독/정기결제 관리'),
          ),
          const DrawerMenuItem(
            icon: Icons.flight_takeoff,
            title: '여행 관리',
            destinationScreen: PlaceholderScreen(title: '여행 관리'),
          ),

          const Divider(),
          const DrawerSectionLabel(label: '부가 기능'),
          const DrawerMenuItem(
            icon: Icons.card_giftcard,
            title: '카드포인트',
            destinationScreen: PlaceholderScreen(title: '카드포인트'),
          ),
          const DrawerMenuItem(
            icon: Icons.calculate_outlined,
            title: '연말정산 시뮬레이션',
            destinationScreen: PlaceholderScreen(title: '연말정산 시뮬레이션'),
          ),

          const Divider(),
          const DrawerSectionLabel(label: '설정'),
          const DrawerMenuItem(
            icon: Icons.category_outlined,
            title: '카테고리 관리',
            destinationScreen: PlaceholderScreen(title: '카테고리 관리'),
          ),
          const DrawerMenuItem(
            icon: Icons.emoji_emotions_outlined,
            title: '감정태그',
            destinationScreen: PlaceholderScreen(title: '감정태그'),
          ),
        ],
      ),
    );
  }
}