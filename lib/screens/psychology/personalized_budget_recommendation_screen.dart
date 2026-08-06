import 'package:flutter/material.dart';
import '../../services/psychology_test_service.dart';
import '../../widgets/common/app_snack_bar.dart';

class PersonalizedBudgetRecommendationScreen
    extends StatefulWidget {
  const PersonalizedBudgetRecommendationScreen({
    super.key,
    required this.resultType,
  });

  final String resultType;

  @override
  State<PersonalizedBudgetRecommendationScreen>
  createState() =>
      _PersonalizedBudgetRecommendationScreenState();
}

class _PersonalizedBudgetRecommendationScreenState
    extends State<PersonalizedBudgetRecommendationScreen> {
  final PsychologyTestService _psychologyTestService =
  PsychologyTestService();
  // 사용자 안내 스낵바 표시 메서드
  void _showMessage(
      String message, {
        AppSnackBarType type = AppSnackBarType.info,
      }) {
    AppSnackBar.show(
      context,
      message: message,
      type: type,
    );
  }

  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final budgetData =
    _getBudgetData(widget.resultType);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '맞춤 예산 추천',
          style: TextStyle(
            color: Color(0xFF252735),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            children: [
              _buildHeaderCard(budgetData),
              const SizedBox(height: 20),
              _buildBudgetRatioCard(budgetData),
              const SizedBox(height: 20),
              _buildTipCard(budgetData),
              const SizedBox(height: 28),
              _buildApplyButton(context),
            ],
          ),
        ),
      ),
    );
  }

  // 현재 월 예산에 추천 카테고리 예산을 적용하는 메서드
  // 현재 월 예산에 추천 카테고리 예산을 적용하는 메서드
  Future<void> _applyRecommendedBudget() async {
    if (_isApplying) {
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final Map<String, int> categoryBudgets =
      await _psychologyTestService.applyRecommendedBudget(
        resultType: widget.resultType,
      );

      if (!mounted) {
        return;
      }

      final int totalApplied =
      categoryBudgets.values.fold<int>(
        0,
            (sum, amount) => sum + amount,
      );

      _showMessage(
        '추천 예산이 적용되었습니다. '
            '카테고리 예산 총 ${_formatAmount(totalApplied)}원',
        type: AppSnackBarType.success,
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message,
        type: AppSnackBarType.warning,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      debugPrint('추천 예산 적용 실패: $error');

      _showMessage(
        '추천 예산을 적용하지 못했습니다. 잠시 후 다시 시도해 주세요.',
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

// 금액에 천 단위 구분 기호를 적용하는 메서드
  String _formatAmount(int amount) {
    return amount
        .toString()
        .replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  Map<String, dynamic> _getBudgetData(String type) {
    switch (type) {
      case 'impulsive_spender':
        return {
          'title': '충동 소비형 맞춤 예산',
          'description':
          '자유 소비 한도를 조금 낮추고 저축 비율을 높여 과소비를 예방하는 구성이에요.',
          'living': 50,
          'saving': 30,
          'flexible': 20,
          'tip':
          '자유 소비 예산을 별도로 분리해두면 충동 구매를 줄이는 데 도움이 될 수 있어요.',
        };

      case 'emotion_spender':
        return {
          'title': '감정 소비형 맞춤 예산',
          'description':
          '예상하지 못한 감정 소비를 고려해 여유 예산을 조금 확보한 구성이에요.',
          'living': 50,
          'saving': 25,
          'flexible': 25,
          'tip':
          '기분 전환용 소비 예산을 미리 정해두면 죄책감 없이 계획적으로 사용할 수 있어요.',
        };

      case 'balanced_spender':
        return {
          'title': '균형 소비형 맞춤 예산',
          'description':
          '생활비와 저축, 자유 소비의 균형을 유지하는 구성이에요.',
          'living': 50,
          'saving': 30,
          'flexible': 20,
          'tip':
          '현재 소비 습관을 유지하면서 저축 목표에 따라 비율을 조금씩 조정해 보세요.',
        };

      case 'planned_spender':
      default:
        return {
          'title': '계획 소비형 맞춤 예산',
          'description':
          '계획적인 소비 습관을 살려 저축 비율을 높인 구성이에요.',
          'living': 45,
          'saving': 40,
          'flexible': 15,
          'tip':
          '지나친 절약으로 피로해지지 않도록 자유 소비 예산도 일정 부분 남겨두는 것이 좋아요.',
        };
    }
  }

  Widget _buildHeaderCard(
      Map<String, dynamic> budgetData,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFDCE9),
            Color(0xFFE8E0FF),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Color(0xFFE66A9F),
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            budgetData['title'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF332A30),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            budgetData['description'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF786C72),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRatioCard(
      Map<String, dynamic> budgetData,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '추천 예산 비율',
            style: TextStyle(
              color: Color(0xFF252735),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _buildBudgetRow(
            icon: Icons.home_rounded,
            label: '생활비',
            percent: budgetData['living'] as int,
            color: const Color(0xFF8566FF),
          ),
          const SizedBox(height: 18),
          _buildBudgetRow(
            icon: Icons.savings_rounded,
            label: '저축',
            percent: budgetData['saving'] as int,
            color: const Color(0xFF36BFA0),
          ),
          const SizedBox(height: 18),
          _buildBudgetRow(
            icon: Icons.shopping_bag_rounded,
            label: '자유 소비',
            percent: budgetData['flexible'] as int,
            color: const Color(0xFFFF68AE),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetRow({
    required IconData icon,
    required String label,
    required int percent,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF555762),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 9,
            backgroundColor: const Color(0xFFEDEEF3),
            valueColor: AlwaysStoppedAnimation<Color>(
              color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipCard(
      Map<String, dynamic> budgetData,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFDFBC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            color: Color(0xFFE89B24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              budgetData['tip'] as String,
              style: const TextStyle(
                color: Color(0xFF8C8074),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 추천 예산 적용 안내 버튼
  // 추천 예산 실제 적용 버튼
  Widget _buildApplyButton(
      BuildContext context,
      ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
        _isApplying ? null : _applyRecommendedBudget,
        style: ElevatedButton.styleFrom(
          backgroundColor:
          const Color(0xFFE66A9F),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          const Color(0xFFE8AFC7),
          disabledForegroundColor:
          Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
        ),
        child: _isApplying
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : const Text(
          '추천 예산 적용하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}