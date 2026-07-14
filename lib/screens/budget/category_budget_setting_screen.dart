import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryBudgetSettingScreen extends StatefulWidget {
  // 카테고리에 배분할 수 있는 최대 금액
  final int availableBudget;

  // 기존에 저장된 카테고리 예산
  final Map<String, int> initialCategoryBudgets;

  const CategoryBudgetSettingScreen({
    super.key,
    required this.availableBudget,
    required this.initialCategoryBudgets,
  });

  @override
  State<CategoryBudgetSettingScreen> createState() =>
      _CategoryBudgetSettingScreenState();
}

class _CategoryBudgetSettingScreenState
    extends State<CategoryBudgetSettingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 카테고리 기본 정보
  final List<_BudgetCategory> _categories = const [
    _BudgetCategory(
      keyName: 'food',
      name: '식비',
      icon: Icons.restaurant_outlined,
    ),
    _BudgetCategory(
      keyName: 'transport',
      name: '교통',
      icon: Icons.directions_bus_outlined,
    ),
    _BudgetCategory(
      keyName: 'shopping',
      name: '쇼핑',
      icon: Icons.shopping_bag_outlined,
    ),
    _BudgetCategory(
      keyName: 'culture',
      name: '문화',
      icon: Icons.movie_outlined,
    ),
    _BudgetCategory(
      keyName: 'housing',
      name: '주거',
      icon: Icons.home_outlined,
    ),
    _BudgetCategory(
      keyName: 'etc',
      name: '기타',
      icon: Icons.more_horiz,
    ),
  ];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();

    // 기존 예산을 입력창 초기값으로 설정
    for (final category in _categories) {
      final int amount =
          widget.initialCategoryBudgets[category.keyName] ?? 0;

      _controllers[category.keyName] = TextEditingController(
        text: amount > 0 ? amount.toString() : '',
      );

      _controllers[category.keyName]!.addListener(_refreshTotal);
    }
  }

  void _refreshTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  int _parseAmount(String value) {
    return int.tryParse(
      value.replaceAll(',', '').trim(),
    ) ??
        0;
  }

  /// 입력된 카테고리 예산 총액
  int get _categoryTotal {
    return _controllers.values.fold<int>(
      0,
          (sum, controller) {
        return sum + _parseAmount(controller.text);
      },
    );
  }

  /// 남은 배분 가능 금액
  int get _remainingBudget {
    return widget.availableBudget - _categoryTotal;
  }

  /// 카테고리별 예산을 이전 화면으로 전달
  void _completeSetting() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_categoryTotal > widget.availableBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카테고리 예산 합계가 가용 예산을 초과했습니다.'),
        ),
      );
      return;
    }

    final Map<String, int> result = {};

    for (final category in _categories) {
      result[category.keyName] = _parseAmount(
        _controllers[category.keyName]!.text,
      );
    }

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    for (final entry in _controllers.entries) {
      entry.value.removeListener(_refreshTotal);
      entry.value.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isExceeded = _remainingBudget < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '카테고리별 예산 설정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    20,
                  ),
                  children: [
                    // 상단 안내 카드
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF2F6BFF),
                            child: Icon(
                              Icons.auto_awesome_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '가용 예산 ${_formatAmount(widget.availableBudget)}원을 '
                                  '카테고리별로 나눠 설정해 주세요.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 카테고리별 입력 카드
                    ..._categories.map(
                          (category) {
                        return _buildCategoryCard(category);
                      },
                    ),

                    const SizedBox(height: 10),

                    // 합계 영역
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE4E7EC),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            label: '카테고리 예산 합계',
                            value: '${_formatAmount(_categoryTotal)}원',
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            label: isExceeded ? '초과 금액' : '남은 예산',
                            value:
                            '${_formatAmount(_remainingBudget.abs())}원',
                            valueColor: isExceeded
                                ? Colors.red
                                : const Color(0xFF12B76A),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 하단 저장 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  18,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: isExceeded ? null : _completeSetting,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF101828),
                    ),
                    child: const Text(
                      '설정하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(_BudgetCategory category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE4E7EC),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF2F4F7),
            child: Icon(
              category.icon,
              color: const Color(0xFF475467),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              category.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 130,
            child: TextFormField(
              controller: _controllers[category.keyName],
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: '원',
                isDense: true,
                border: InputBorder.none,
              ),
              validator: (value) {
                final int amount = _parseAmount(value ?? '');

                if (amount < 0) {
                  return '0원 이상';
                }

                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color valueColor = const Color(0xFF101828),
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF667085),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  static String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
    );
  }
}

class _BudgetCategory {
  final String keyName;
  final String name;
  final IconData icon;

  const _BudgetCategory({
    required this.keyName,
    required this.name,
    required this.icon,
  });
}