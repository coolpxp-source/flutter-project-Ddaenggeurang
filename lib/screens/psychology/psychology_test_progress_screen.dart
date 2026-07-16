import 'package:flutter/material.dart';
import 'psychology_test_result_screen.dart';
import '../../services/psychology_test_service.dart';
class PsychologyTestProgressScreen extends StatefulWidget {
  const PsychologyTestProgressScreen({super.key});

  @override
  State<PsychologyTestProgressScreen> createState() =>
      _PsychologyTestProgressScreenState();
}

class _PsychologyTestProgressScreenState
    extends State<PsychologyTestProgressScreen> {
  int _currentQuestionIndex = 0;
  int? _selectedOptionIndex;
  final List<int> _answers = [];
  final PsychologyTestService _psychologyTestService =
  PsychologyTestService();
  bool _isSavingResult = false;

  final List<Map<String, dynamic>> _questions = [
    {
      'question': '사고 싶은 물건이 생겼을 때 나는?',
      'options': [
        {
          'text': '바로 구매하는 편이다',
          'score': 4,
        },
        {
          'text': '조금 고민한 뒤 구매한다',
          'score': 3,
        },
        {
          'text': '필요성을 충분히 따져본다',
          'score': 2,
        },
        {
          'text': '대부분 구매하지 않는다',
          'score': 1,
        },
      ],
    },
    {
      'question': '스트레스를 받을 때 소비하는 편인가요?',
      'options': [
        {
          'text': '자주 소비한다',
          'score': 4,
        },
        {
          'text': '가끔 소비한다',
          'score': 3,
        },
        {
          'text': '거의 소비하지 않는다',
          'score': 2,
        },
        {
          'text': '전혀 소비하지 않는다',
          'score': 1,
        },
      ],
    },
    {
      'question': '할인 상품을 발견했을 때 나는?',
      'options': [
        {
          'text': '필요 없어도 구매한다',
          'score': 4,
        },
        {
          'text': '조금 고민해 본다',
          'score': 3,
        },
        {
          'text': '필요한 경우에만 구매한다',
          'score': 2,
        },
        {
          'text': '할인 여부에 크게 영향받지 않는다',
          'score': 1,
        },
      ],
    },
    {
      'question': '한 달 예산을 정해두고 소비하나요?',
      'options': [
        {
          'text': '전혀 정하지 않는다',
          'score': 4,
        },
        {
          'text': '대략적으로만 생각한다',
          'score': 3,
        },
        {
          'text': '예산을 정하지만 자주 초과한다',
          'score': 2,
        },
        {
          'text': '예산을 정하고 최대한 지킨다',
          'score': 1,
        },
      ],
    },
    {
      'question': '친구들이 물건을 구매하면 나도 사고 싶어지나요?',
      'options': [
        {
          'text': '매우 그렇다',
          'score': 4,
        },
        {
          'text': '조금 그렇다',
          'score': 3,
        },
        {
          'text': '별로 그렇지 않다',
          'score': 2,
        },
        {
          'text': '전혀 그렇지 않다',
          'score': 1,
        },
      ],
    },
    {
      'question': '계획에 없던 지출을 하고 나면 나는?',
      'options': [
        {
          'text': '크게 신경 쓰지 않는다',
          'score': 4,
        },
        {
          'text': '조금 후회하지만 또 반복한다',
          'score': 3,
        },
        {
          'text': '다음 소비를 줄이려고 한다',
          'score': 2,
        },
        {
          'text': '원래 계획에 없는 소비는 거의 하지 않는다',
          'score': 1,
        },
      ],
    },
    {
      'question': '월급이나 용돈을 받으면 가장 먼저 하는 행동은?',
      'options': [
        {
          'text': '사고 싶었던 것을 산다',
          'score': 4,
        },
        {
          'text': '필요한 지출부터 한다',
          'score': 3,
        },
        {
          'text': '일부는 저축하고 나머지를 쓴다',
          'score': 2,
        },
        {
          'text': '먼저 예산을 나누고 저축한다',
          'score': 1,
        },
      ],
    },
    {
      'question': 'SNS에서 인기 있는 상품을 보면?',
      'options': [
        {
          'text': '유행하면 사고 싶어진다',
          'score': 4,
        },
        {
          'text': '후기를 찾아본다',
          'score': 3,
        },
        {
          'text': '필요한지 먼저 생각한다',
          'score': 2,
        },
        {
          'text': '거의 영향을 받지 않는다',
          'score': 1,
        },
      ],
    },
    {
      'question': '큰 금액의 물건을 구매하기 전 나는?',
      'options': [
        {
          'text': '마음에 들면 바로 구매한다',
          'score': 4,
        },
        {
          'text': '잠깐 고민한 뒤 구매한다',
          'score': 3,
        },
        {
          'text': '가격과 후기를 충분히 비교한다',
          'score': 2,
        },
        {
          'text': '예산을 미리 모은 뒤 구매한다',
          'score': 1,
        },
      ],
    },
    {
      'question': '이번 달 지출이 예상보다 많아졌다면?',
      'options': [
        {
          'text': '다음 달에 해결하면 된다고 생각한다',
          'score': 4,
        },
        {
          'text': '조금 걱정하지만 평소처럼 소비한다',
          'score': 3,
        },
        {
          'text': '남은 기간의 지출을 줄인다',
          'score': 2,
        },
        {
          'text': '지출 내역을 확인하고 바로 예산을 조정한다',
          'score': 1,
        },
      ],
    },
  ];

  void _selectOption(int index) {
    setState(() {
      _selectedOptionIndex = index;
    });
  }

  void _goToNextQuestion() {
    if (_selectedOptionIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('답변을 선택해 주세요.'),
        ),
      );
      return;
    }

    final currentQuestion =
    _questions[_currentQuestionIndex];

    final options =
    List<Map<String, dynamic>>.from(
      currentQuestion['options'] as List,
    );

    final selectedScore =
    options[_selectedOptionIndex!]['score'] as int;

    if (_answers.length > _currentQuestionIndex) {
      _answers[_currentQuestionIndex] =
          selectedScore;
    } else {
      _answers.add(selectedScore);
    }

    if (_currentQuestionIndex <
        _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedOptionIndex = null;
      });

      return;
    }

    _calculateResult();
  }

  // 테스트 결과 계산 및 저장 메서드
  Future<void> _calculateResult() async {
    if (_isSavingResult) {
      return;
    }

    final totalScore = _answers.fold<int>(
      0,
          (sum, score) => sum + score,
    );

    String resultType;

    if (totalScore >= 34) {
      resultType = 'impulsive_spender';
    } else if (totalScore >= 26) {
      resultType = 'emotion_spender';
    } else if (totalScore >= 18) {
      resultType = 'balanced_spender';
    } else {
      resultType = 'planned_spender';
    }

    setState(() {
      _isSavingResult = true;
    });

    try {
      await _psychologyTestService.saveTestResult(
        resultType: resultType,
        totalScore: totalScore,
      );

      if (!mounted) {
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PsychologyTestResultScreen(
            resultType: resultType,
            totalScore: totalScore,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테스트 결과 저장에 실패했습니다: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingResult = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex];
    final progress =
        (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '소비심리 테스트',
          style: TextStyle(
            color: Color(0xFF252735),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProgressSection(progress),
              const SizedBox(height: 34),
              _buildQuestionCard(question),
              const SizedBox(height: 24),
              Expanded(
                child: _buildOptionList(
                  List<Map<String, dynamic>>.from(
                    question['options'] as List,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _buildNextButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(double progress) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '${_currentQuestionIndex + 1} / ${_questions.length}',
              style: const TextStyle(
                color: Color(0xFF555762),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFE66A9F),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 9,
            backgroundColor: const Color(0xFFFFE2EC),
            valueColor: const AlwaysStoppedAnimation<Color>(
              Color(0xFFE66A9F),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
      Map<String, dynamic> question,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE0EC),
            Color(0xFFE9DFFF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${_currentQuestionIndex + 1}',
            style: const TextStyle(
              color: Color(0xFFE66A9F),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            question['question'] as String,
            style: const TextStyle(
              color: Color(0xFF332A30),
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionList(
      List<Map<String, dynamic>> options,
      ) {
    return ListView.separated(
      itemCount: options.length,
      separatorBuilder: (_, __) =>
      const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final isSelected =
            _selectedOptionIndex == index;

        return InkWell(
          onTap: () => _selectOption(index),
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(
              milliseconds: 180,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 17,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFFFEDF4)
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE66A9F)
                    : const Color(0xFFE7E8ED),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE66A9F)
                        : const Color(0xFFF1F2F5),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 17,
                    )
                        : Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Color(0xFF888B96),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                      options[index]['text'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF3A3035)
                          : const Color(0xFF555762),
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNextButton() {
    final isLastQuestion =
        _currentQuestionIndex == _questions.length - 1;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSavingResult
            ? null
            : _goToNextQuestion,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE66A9F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isSavingResult
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Text(
          isLastQuestion
              ? '결과 확인하기'
              : '다음 질문',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}