import 'package:flutter/material.dart';
import '../../screens/category/custom_categories.dart';
import '../../screens/history/transaction_history_screen.dart';
import 'drawer_menu_item.dart';
import 'placeholder_screen.dart';
import '../../screens/record/record_type_select_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/subscription/subscription_list_screen.dart';
import '../../screens/travel/travel_mode_start_screen.dart';
import '../../screens/budget/budget_setting_screen.dart';
import '../../screens/budget/budget_vs_expense_screen.dart';

/// 앱 전체에서 공용으로 쓰는 사이드바.
/// 사용법: 각 화면 Scaffold에 drawer: const AppDrawer() 한 줄만 추가.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // 홈 대시보드와 동일한 팔레트 — 섹션별로 색을 다르게 줘서 화면 간 톤을 통일한다.
  static const _amberDeep = Color(0xFF8A5200);
  static const _amberSoft = Color(0xFFFFF3DE);
  static const _blue = Color(0xFF4F7DF3);
  static const _blueSoft = Color(0xFFE8EFFE);
  static const _pink = Color(0xFFFF6F91);
  static const _pinkSoft = Color(0xFFFFE3EC);
  static const _purple = Color(0xFF6C5CE7);
  static const _purpleSoft = Color(0xFFEDE9FE);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB648), Color(0xFFFF7A45)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Image.asset('assets/images/Icon.png'),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('땡그랑',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text('가계부는 똑똑하게, 소비는 똑바르게!',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const DrawerSectionLabel(label: '수입 / 지출 / 저축'),
          DrawerMenuItem(
            icon: Icons.edit_note,
            title: '수입/지출/저축 기록하기',
            destinationScreen: const RecordTypeSelectScreen(),
            iconColor: _amberDeep,
            iconBg: _amberSoft,
          ),
          const DrawerMenuItem(
            icon: Icons.camera_alt_outlined,
            title: '영수증 촬영 업로드',
            destinationScreen: PlaceholderScreen(title: '영수증 촬영 업로드'),
            iconColor: _amberDeep,
            iconBg: _amberSoft,
          ),
          const DrawerMenuItem(
            icon: Icons.sms_outlined,
            title: '문자내역 붙여넣기',
            destinationScreen: PlaceholderScreen(title: '문자내역 붙여넣기'),
            iconColor: _amberDeep,
            iconBg: _amberSoft,
          ),
          const DrawerMenuItem(
            icon: Icons.list_alt,
            title: '내역 목록',
            destinationScreen: TransactionHistoryScreen(),
            iconColor: _amberDeep,
            iconBg: _amberSoft,
          ),

          const Divider(),
          const DrawerSectionLabel(label: '자동 등록 관리'),
          const DrawerMenuItem(
            icon: Icons.credit_card,
            title: '할부 관리',
            destinationScreen: PlaceholderScreen(title: '할부 관리'),
            iconColor: _blue,
            iconBg: _blueSoft,
          ),
          DrawerMenuItem(
            icon: Icons.autorenew,
            title: '구독/정기결제 관리',
            destinationScreen: SubscriptionListScreen(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            iconColor: _blue,
            iconBg: _blueSoft,
          ),
          const DrawerMenuItem(
            icon: Icons.flight_takeoff,
            title: '여행 관리',
            destinationScreen: TravelModeStartScreen(),
            iconColor: _blue,
            iconBg: _blueSoft,
          ),

          const Divider(),
          const DrawerSectionLabel(label: '부가 기능'),
          const DrawerMenuItem(
            icon: Icons.card_giftcard,
            title: '카드포인트',
            destinationScreen: PlaceholderScreen(title: '카드포인트'),
            iconColor: _pink,
            iconBg: _pinkSoft,
          ),
          const DrawerMenuItem(
            icon: Icons.calculate_outlined,
            title: '연말정산 시뮬레이션',
            destinationScreen: PlaceholderScreen(title: '연말정산 시뮬레이션'),
            iconColor: _pink,
            iconBg: _pinkSoft,
          ),

          const Divider(),
          const DrawerSectionLabel(label: '설정'),
          DrawerMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: '예산 설정',
            destinationScreen: BudgetSettingScreen(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            iconColor: _purple,
            iconBg: _purpleSoft,
          ),
          DrawerMenuItem(
            icon: Icons.pie_chart_outline_rounded,
            title: '예산 대비 지출',
            destinationScreen: BudgetVsExpenseScreen(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            iconColor: _purple,
            iconBg: _purpleSoft,
          ),
          DrawerMenuItem(
            icon: Icons.category_outlined,
            title: '카테고리 관리',
            destinationScreen: CustomCategoriesScreen(),
            iconColor: _purple,
            iconBg: _purpleSoft,
          ),
          const DrawerMenuItem(
            icon: Icons.emoji_emotions_outlined,
            title: '감정태그',
            destinationScreen: PlaceholderScreen(title: '감정태그'),
            iconColor: _purple,
            iconBg: _purpleSoft,
          ),
        ],
      ),
    );
  }
}