import 'package:flutter/material.dart';
import '../../screens/category/custom_categories_screen.dart';
import '../../screens/history/installment_recurring_screen.dart';
import '../../screens/history/transaction_history_screen.dart';
import 'drawer_menu_item.dart';
import 'placeholder_screen.dart';
import '../../screens/record/record_type_select_screen.dart';
import '../../screens/record/receipt_upload_screen.dart';
import '../../screens/record/sms_paste_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../screens/subscription/subscription_list_screen.dart';
import '../../screens/travel/travel_mode_start_screen.dart';
import '../../screens/budget/budget_setting_screen.dart';
import '../../screens/budget/budget_vs_expense_screen.dart';
import '../../screens/card_point/card_point_list_screen.dart';
import '../../screens/year_end_simulation/year_end_simulation_screen.dart';
import '../../utils/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

/// 앱 전체에서 공용으로 쓰는 사이드바.
/// 사용법: 각 화면 Scaffold에 drawer: const AppDrawer() 한 줄만 추가.
///
/// 색상은 전부 AppColors 토큰을 참조합니다 (로컬 하드코딩 금지).
/// 헤더 그라데이션은 RecordTypeSelectScreen의 히어로 배너와 동일한 톤으로 통일했습니다.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  // 로그아웃 — setting_screen.dart와 동일한 확인 모달 → signOut 흐름
  Future<void> _logout(BuildContext context) async {
    final ok = await DdaengModal.confirm(
      context,
      title: '로그아웃 하시겠어요?',
      message: '다시 로그인하면 이어서 사용할 수 있어요',
      type: ModalType.warning,
      confirmText: '로그아웃',
    );
    if (ok) await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFC168), Color(0xFFFF7A45), Color(0xFFFF5C7A)],
                stops: [0.0, 0.55, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A66).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
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
            title: '내역 기록하기',
            destinationScreen: const RecordTypeSelectScreen(),
            iconColor: AppColors.expenseDeep,
            iconBg: AppColors.expense.withValues(alpha: 0.15),
          ),
          DrawerMenuItem(
            icon: Icons.list_alt,
            title: '내역 목록',
            destinationScreen: TransactionHistoryScreen(),
            iconColor: AppColors.expenseDeep,
            iconBg: AppColors.expense.withValues(alpha: 0.15),
          ),

          const Divider(color: AppColors.divider),
          const DrawerSectionLabel(label: '자동 등록 관리'),
          DrawerMenuItem(
            icon: Icons.credit_card,
            title: '할부/정기결제 관리',
            destinationScreen: InstallmentRecurringScreen(),
            iconColor: AppColors.utility,
            iconBg: AppColors.utilitySoft,
          ),
          DrawerMenuItem(
            icon: Icons.autorenew,
            title: '구독서비스 관리',
            destinationScreen: SubscriptionListScreen(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            iconColor: AppColors.utility,
            iconBg: AppColors.utilitySoft,
          ),
          DrawerMenuItem(
            icon: Icons.flight_takeoff,
            title: '여행 관리',
            destinationScreen: TravelModeStartScreen(),
            iconColor: AppColors.utility,
            iconBg: AppColors.utilitySoft,
          ),

          const Divider(color: AppColors.divider),
          const DrawerSectionLabel(label: '예산 / 지출 분석'),
          DrawerMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: '예산 설정',
            destinationScreen: BudgetSettingScreen(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            iconColor: AppColors.purple,
            iconBg: AppColors.purpleSoft,
          ),
          DrawerMenuItem(
            icon: Icons.pie_chart_outline_rounded,
            title: '예산 대비 지출',
            destinationScreen: BudgetVsExpenseScreen(
              userId: FirebaseAuth.instance.currentUser!.uid,
            ),
            iconColor: AppColors.purple,
            iconBg: AppColors.purpleSoft,
          ),

          const Divider(color: AppColors.divider),
          const DrawerSectionLabel(label: '부가 기능'),
          DrawerMenuItem(
            icon: Icons.category_outlined,
            title: '카테고리 관리',
            destinationScreen: CustomCategoriesScreen(),
            iconColor: AppColors.pink,
            iconBg: AppColors.pinkSoft,
          ),
          DrawerMenuItem(
            icon: Icons.card_giftcard,
            title: '카드포인트',
            destinationScreen: const CardPointListScreen(),
            iconColor: AppColors.pink,
            iconBg: AppColors.pinkSoft,
          ),
          DrawerMenuItem(
            icon: Icons.calculate_outlined,
            title: '연말정산 시뮬레이션',
            destinationScreen: const YearEndSimulationScreen(),
            iconColor: AppColors.pink,
            iconBg: AppColors.pinkSoft,
          ),

          // 로그아웃 — 다른 메뉴와 톤을 다르게(연한 회색) 둬서 실수 클릭 방지
          const Divider(color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _logout(context),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Color(0xFFB3AEB8)),
                    SizedBox(width: 10),
                    Text('로그아웃',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A7E77))),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                const Text(
                  '땡그랑 v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB3AEB8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}