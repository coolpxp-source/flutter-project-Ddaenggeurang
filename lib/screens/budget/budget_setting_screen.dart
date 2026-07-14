import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/budget_model.dart';
import '../../services/budget_service.dart';
import 'category_budget_setting_screen.dart';

class BudgetSettingScreen extends StatefulWidget {
  // 현재 로그인 사용자 UID
  final String userId;

  const BudgetSettingScreen({
    super.key,
    required this.userId,
  });

  @override
  State<BudgetSettingScreen> createState() =>
      _BudgetSettingScreenState();
}

class _BudgetSettingScreenState extends State<BudgetSettingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _totalBudgetController =
  TextEditingController();

  final BudgetService _budgetService = BudgetService();

  // 예산 시작일
  int _startDay = 1;

  // 고정지출 합계
  int _fixedExpenseTotal = 0;

  // 구독료 합계
  int _subscriptionTotal = 0;

  // 카테고리별 예산
  Map<String, int> _categoryBudgets = {};

  bool _isLoading = true;
  bool _isSaving = false;

  /// 현재 월을 2026-07 형식으로 반환
  String get _currentMonth {
    final DateTime now = DateTime.now();

    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  int get _totalBudget {
    return int.tryParse(
      _totalBudgetController.text
          .replaceAll(',', '')
          .trim(),
    ) ??
        0;
  }

  /// 전체 예산에서 고정지출과 구독료를 제외한 금액
  int get _availableBudget {
    return _totalBudget -
        _fixedExpenseTotal -
        _subscriptionTotal;
  }

  int get _categoryTotal {
    return _categoryBudgets.values.fold(
      0,
          (sum, amount) => sum + amount,
    );
  }

  @override
  void initState() {
    super.initState();

    _totalBudgetController.addListener(_refreshScreen);
    _loadBudget();
  }

  void _refreshScreen() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 기존 예산과 구독료 불러오기
  Future<void> _loadBudget() async {
    try {
      final results = await Future.wait([
        _budgetService.getBudget(
          userId: widget.userId,
          month: _currentMonth,
        ),
        _budgetService.getSubscriptionTotal(widget.userId),
      ]);

      final BudgetModel? budget = results[0] as BudgetModel?;
      final int subscriptionTotal = results[1] as int;

      if (!mounted) {
        return;
      }

      setState(() {
        _subscriptionTotal = subscriptionTotal;

        if (budget != null) {
          _totalBudgetController.text =
              budget.totalBudget.toString();

          _startDay = budget.startDay;
          _fixedExpenseTotal = budget.fixedExpenseTotal;
          _categoryBudgets =
          Map<String, int>.from(budget.categoryBudgets);
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예산 정보를 불러오지 못했습니다.\n$e'),
        ),
      );
    }
  }

  /// 예산 시작일 선택
  Future<void> _selectStartDay() async {
    final int? selectedDay = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SizedBox(
            height: 360,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '예산 시작일 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 31,
                    itemBuilder: (context, index) {
                      final int day = index + 1;

                      return ListTile(
                        title: Text('매월 $day일'),
                        trailing: _startDay == day
                            ? const Icon(
                          Icons.check,
                          color: Color(0xFF12B76A),
                        )
                            : null,
                        onTap: () {
                          Navigator.pop(
                            bottomSheetContext,
                            day,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedDay != null) {
      setState(() {
        _startDay = selectedDay;
      });
    }
  }

  /// 카테고리별 예산 설정 화면으로 이동
  Future<void> _openCategorySetting() async {
    if (_totalBudget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 전체 예산을 입력해 주세요.'),
        ),
      );
      return;
    }

    if (_availableBudget < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전체 예산이 고정지출과 구독료보다 적습니다.'),
        ),
      );
      return;
    }

    final result = await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBudgetSettingScreen(
          availableBudget: _availableBudget,
          initialCategoryBudgets: _categoryBudgets,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _categoryBudgets = result;
      });
    }
  }

  /// Firestore에 예산 저장
  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_availableBudget < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('전체 예산이 고정지출과 구독료보다 적습니다.'),
        ),
      );
      return;
    }

    if (_categoryTotal > _availableBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('카테고리 예산 합계가 가용 예산을 초과했습니다.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _budgetService.saveBudget(
        userId: widget.userId,
        month: _currentMonth,
        totalBudget: _totalBudget,
        startDay: _startDay,
        fixedExpenseTotal: _fixedExpenseTotal,
        subscriptionTotal: _subscriptionTotal,
        categoryBudgets: _categoryBudgets,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('예산 설정이 저장되었습니다.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('예산 저장 중 오류가 발생했습니다.\n$e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _totalBudgetController.removeListener(_refreshScreen);
    _totalBudgetController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final bool isAvailableBudgetNegative = _availableBudget < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '예산 설정',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              32,
            ),
            children: [
              // 전체 예산 카드
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFE4E7EC),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D101828),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '$_currentMonth 전체 예산',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _totalBudgetController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF12B76A),
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        suffixText: '원',
                        filled: true,
                        fillColor: Color(0xFFF0FDF4),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(
                            Radius.circular(12),
                          ),
                        ),
                      ),
                      validator: (value) {
                        final int amount = int.tryParse(
                          value
                              ?.replaceAll(',', '')
                              .trim() ??
                              '',
                        ) ??
                            0;

                        if (amount <= 0) {
                          return '전체 예산을 입력하세요.';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 예산 시작일 설정
              _buildSettingTile(
                title: '예산 시작일',
                subtitle: '매월 $_startDay일부터 예산을 계산합니다.',
                trailingText: '$_startDay일',
                icon: Icons.calendar_today_outlined,
                onTap: _selectStartDay,
              ),
              const SizedBox(height: 12),

              // 카테고리별 예산 안내
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE4E7EC),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF667085),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '전체 예산에서 고정지출과 구독료를 제외한 금액을 '
                            '카테고리별로 나눌 수 있습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 카테고리 예산 설정 버튼
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _openCategorySetting,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    _categoryBudgets.isEmpty
                        ? '카테고리 예산 설정'
                        : '카테고리 예산 수정',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF12B76A),
                    side: const BorderSide(
                      color: Color(0xFF12B76A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 예산 계산 결과
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildAmountRow(
                      label: '전체 예산',
                      amount: _totalBudget,
                    ),
                    const SizedBox(height: 12),
                    _buildAmountRow(
                      label: '고정지출',
                      amount: _fixedExpenseTotal,
                    ),
                    const SizedBox(height: 12),
                    _buildAmountRow(
                      label: '구독료',
                      amount: _subscriptionTotal,
                    ),
                    const Divider(height: 28),
                    _buildAmountRow(
                      label: '가용 예산',
                      amount: _availableBudget,
                      valueColor: isAvailableBudgetNegative
                          ? Colors.red
                          : const Color(0xFF12B76A),
                      isBold: true,
                    ),
                    if (_categoryBudgets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAmountRow(
                        label: '카테고리 배분 합계',
                        amount: _categoryTotal,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 최종 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveBudget,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF101828),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '저장하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required String trailingText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF475467),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailingText,
                style: const TextStyle(
                  color: Color(0xFF12B76A),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountRow({
    required String label,
    required int amount,
    Color valueColor = const Color(0xFF101828),
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
            isBold ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF667085),
          ),
        ),
        Text(
          '${_formatAmount(amount)}원',
          style: TextStyle(
            fontSize: isBold ? 17 : 14,
            fontWeight:
            isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  static String _formatAmount(int amount) {
    final bool isNegative = amount < 0;
    final String number = amount.abs().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
    );

    return isNegative ? '-$number' : number;
  }
}