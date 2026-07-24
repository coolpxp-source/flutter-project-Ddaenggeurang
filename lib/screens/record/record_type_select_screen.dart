import 'package:flutter/material.dart';
import '../expense/expense_input_screen.dart';
import '../income/income_input_screen.dart';
import '../saving/saving_input_screen.dart';
import '../record/bulk_record_screen.dart';
import '../../utils/app_colors.dart';

/// 1단계 - "기록하고 싶은 메뉴를 선택하세요!"
/// 여기서 고르면 바로 각 입력폼으로 이동 (중간에 사진/직접입력 선택 단계 없음 —
/// 사진업로드는 지출 화면에만 배너로 내장돼 있고 수입/저축엔 없음)
class RecordTypeSelectScreen extends StatelessWidget {
  const RecordTypeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.ink),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroBanner(),
              const SizedBox(height: 24),

              _RecordTypeCard(
                title: '지출',
                subtitle: '고정 / 변동 / 기타',
                icon: Icons.storefront_rounded,
                color: AppColors.expenseDeep,
                iconBg: AppColors.expense.withValues(alpha: 0.15),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseInputScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RecordTypeCard(
                title: '수입',
                subtitle: '월급 / 용돈 / 기타',
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.income,
                iconBg: AppColors.incomeSoft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IncomeInputScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RecordTypeCard(
                title: '저축',
                subtitle: '적금 / 예금 / 투자',
                icon: Icons.savings_rounded,
                color: AppColors.saving,
                iconBg: AppColors.savingSoft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavingInputScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RecordTypeCard(
                title: '퉁치기 / 한번에 기록하기',
                subtitle: '밀린 내역을 한꺼번에',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.utility,
                iconBg: AppColors.utilitySoft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BulkRecordScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 다른 입력 화면들의 히어로 카드(그라데이션)와 통일한 안내 배너
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC168), Color(0xFFFF7A45), Color(0xFFFF5C7A)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6A66).withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('🐶', style: TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 14),
          const Text(
            '기록하고 싶은\n메뉴를 선택하세요!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 다른 입력 화면의 _sectionCard와 동일한 톤(흰 배경 + boxShadow)의 선택 카드
class _RecordTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconBg;
  final VoidCallback onTap;

  const _RecordTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSub),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.inkSub.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}