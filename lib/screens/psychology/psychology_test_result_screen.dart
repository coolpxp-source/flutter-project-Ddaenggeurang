import 'package:flutter/material.dart';
import 'personalized_budget_recommendation_screen.dart';

class PsychologyTestResultScreen extends StatelessWidget {
  const PsychologyTestResultScreen({
    super.key,
    required this.resultType,
    required this.totalScore,
  });

  final String resultType;
  final int totalScore;

  @override
  Widget build(BuildContext context) {
    final resultData = _getResultData(resultType);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '테스트 결과',
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
              _buildResultCard(resultData),
              const SizedBox(height: 20),
              _buildScoreCard(),
              const SizedBox(height: 20),
              _buildAdviceCard(resultData),
              const SizedBox(height: 28),
              _buildBudgetButton(context),
              const SizedBox(height: 12),
              _buildFinishButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getResultData(String type) {
    switch (type) {
      case 'impulsive_spender':
        return {
          'title': '충동 소비형',
          'emoji': '⚡',
          'description':
          '마음에 드는 것을 발견하면 빠르게 구매하는 편이에요. '
              '소비 전 잠깐의 고민 시간을 가지면 더 만족스러운 소비를 할 수 있어요.',
          'advice':
          '구매하고 싶은 물건이 생기면 바로 결제하지 말고 하루 정도 장바구니에 넣어두세요.',
          'color': const Color(0xFFFF6B81),
        };

      case 'emotion_spender':
        return {
          'title': '감정 소비형',
          'emoji': '💭',
          'description':
          '기분이나 상황에 따라 소비가 달라지는 편이에요. '
              '스트레스와 소비의 관계를 확인하는 것이 중요해요.',
          'advice':
          '소비 전에 지금 필요한 물건인지, 기분 전환을 위한 소비인지 한 번 생각해 보세요.',
          'color': const Color(0xFFFFA94D),
        };

      case 'balanced_spender':
        return {
          'title': '균형 소비형',
          'emoji': '⚖️',
          'description':
          '필요한 소비와 절약 사이에서 비교적 균형을 잘 유지하고 있어요. '
              '지금의 소비 습관을 꾸준히 유지해 보세요.',
          'advice':
          '월별 예산을 조금 더 구체적으로 나누면 현재의 좋은 소비 습관을 더욱 안정적으로 유지할 수 있어요.',
          'color': const Color(0xFF8566FF),
        };

      case 'planned_spender':
      default:
        return {
          'title': '계획 소비형',
          'emoji': '📋',
          'description':
          '소비 전에 충분히 고민하고 계획적으로 지출하는 편이에요. '
              '예산 관리 능력이 뛰어난 소비 유형이에요.',
          'advice':
          '지나친 절약 때문에 필요한 소비까지 미루지 않도록 적절한 여유 예산도 만들어 보세요.',
          'color': const Color(0xFF36BFA0),
        };
    }
  }

  Widget _buildResultCard(
      Map<String, dynamic> resultData,
      ) {
    final color = resultData['color'] as Color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            const Color(0xFFFFF1F7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                resultData['emoji'] as String,
                style: const TextStyle(
                  fontSize: 42,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '나의 소비 유형은',
            style: TextStyle(
              color: Color(0xFF8A7D83),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            resultData['title'] as String,
            style: TextStyle(
              color: color,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            resultData['description'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF655A5F),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
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
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEF4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.bar_chart_rounded,
              color: Color(0xFFE66A9F),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '소비 성향 점수',
              style: TextStyle(
                color: Color(0xFF555762),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '$totalScore / 40',
            style: const TextStyle(
              color: Color(0xFF252735),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard(
      Map<String, dynamic> resultData,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFFD4E2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFE66A9F),
              ),
              SizedBox(width: 9),
              Text(
                '땡그랑의 소비 팁',
                style: TextStyle(
                  color: Color(0xFF3D3237),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resultData['advice'] as String,
            style: const TextStyle(
              color: Color(0xFF755F68),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetButton(
      BuildContext context,
      ) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PersonalizedBudgetRecommendationScreen(
                    resultType: resultType,
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
          '나에게 맞는 예산 추천받기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildFinishButton(
      BuildContext context,
      ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: TextButton(
        onPressed: () {
          Navigator.popUntil(
            context,
                (route) => route.isFirst,
          );
        },
        child: const Text(
          '테스트 종료',
          style: TextStyle(
            color: Color(0xFF777A86),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}