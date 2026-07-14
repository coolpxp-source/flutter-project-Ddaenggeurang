import 'package:flutter/material.dart';

class PersonalizedBudgetRecommendationScreen extends StatelessWidget {
  const PersonalizedBudgetRecommendationScreen({
    super.key,
    required this.resultType,
  });

  final String resultType;

  @override
  Widget build(BuildContext context) {
    final budgetData = _getBudgetData(resultType);

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

  Widget _buildApplyButton(
      BuildContext context,
      ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '추천 예산 적용 기능은 로그인 및 예산 기능 연동 후 연결됩니다.',
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE66A9F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
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