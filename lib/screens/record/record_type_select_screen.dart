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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildSpeechBubble('기록하고 싶은\n메뉴를 선택하세요!'),
              const SizedBox(height: 16),
              const _MascotFace(),
              const SizedBox(height: 32),

              _RecordTypeButton(
                title: '지출',
                subtitle: '고정 / 변동 / 기타',
                color: AppColors.expense.withValues(alpha: 0.18),
                textColor: AppColors.expenseDeep,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpenseInputScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RecordTypeButton(
                title: '수입',
                subtitle: '월급 / 용돈 / 기타',
                color: AppColors.incomeSoft,
                textColor: AppColors.income,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IncomeInputScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RecordTypeButton(
                title: '저축',
                subtitle: '적금 / 예금 / 투자',
                color: AppColors.savingSoft,
                textColor: AppColors.saving,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavingInputScreen()),
                ),
              ),
              const SizedBox(height: 12),
              _RecordTypeButton(
                title: '퉁치기 / 한번에 기록하기',
                subtitle: '밀린 내역을 한꺼번에',
                color: AppColors.utilitySoft,
                textColor: AppColors.utility,
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

  Widget _buildSpeechBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.expenseDeep,
          height: 1.4,
        ),
      ),
    );
  }
}

/// 마스코트(강아지) 자리 — 실제 캐릭터 이미지/애니메이션으로 교체 예정
/// TODO: assets/coach 쪽 실제 마스코트 이미지 or Lottie로 교체
class _MascotFace extends StatelessWidget {
  const _MascotFace();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        color: Color(0xFFFBC02D),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text('🐶', style: TextStyle(fontSize: 48)),
    );
  }
}

class _RecordTypeButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _RecordTypeButton({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}