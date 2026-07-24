import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../services/budget_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'category_budget_setting_screen.dart';

class BudgetSettingScreen extends StatefulWidget {
  final String userId;

  const BudgetSettingScreen({
    super.key,
    required this.userId,
  });

  @override
  State<BudgetSettingScreen> createState() => _BudgetSettingScreenState();
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

  // 활성 구독료 합계
  int _subscriptionTotal = 0;

  // 카테고리별 예산
  Map<String, int> _categoryBudgets = {};

  // 로딩 및 저장 상태
  bool _isLoading = true;
  bool _isSaving = false;

  /// 현재 연월을 YYYY-MM 형식으로 반환
  String get _currentMonth {
    final DateTime now = DateTime.now();

    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// 입력된 전체 예산
  int get _totalBudget {
    return int.tryParse(
      _totalBudgetController.text.replaceAll(',', '').trim(),
    ) ??
        0;
  }

  /// 전체 예산에서 고정지출과 구독료를 제외한 금액
  int get _availableBudget {
    return _totalBudget - _fixedExpenseTotal - _subscriptionTotal;
  }

  /// 카테고리별 예산 합계
  int get _categoryTotal {
    return _categoryBudgets.values.fold<int>(
      0,
          (sum, amount) => sum + amount,
    );
  }

  /// 카테고리 예산 합계가 가용 예산을 초과했는지 확인
  bool get _isCategoryBudgetExceeded {
    return _categoryTotal > _availableBudget;
  }

  /// 전체 예산보다 고정지출과 구독료 합계가 큰지 확인
  bool get _isAvailableBudgetNegative {
    return _availableBudget < 0;
  }

  /// 저장 버튼 비활성화 조건
  bool get _isSaveDisabled {
    return _isSaving ||
        _totalBudget <= 0 ||
        _isAvailableBudgetNegative ||
        _isCategoryBudgetExceeded;
  }

  @override
  void initState() {
    super.initState();

    // 전체 예산 입력값이 바뀌면 계산 결과 갱신
    _totalBudgetController.addListener(_refreshScreen);

    // 기존 예산과 구독료 조회
    _loadBudget();
  }

  /// 전체 예산 변경 시 화면 갱신
  void _refreshScreen() {
    if (mounted) {
      setState(() {});
    }
  }

  /// 기존 예산과 활성 구독료 불러오기
  Future<void> _loadBudget() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final List<Object?> results = await Future.wait<Object?>([
        // 현재 월 예산 조회
        _budgetService.getBudget(
          userId: widget.userId,
          month: _currentMonth,
        ),

        // 활성 구독료 합계 조회
        _budgetService.getSubscriptionTotal(
          widget.userId,
        ),
      ]);

      final BudgetModel? budget = results[0] as BudgetModel?;
      final int subscriptionTotal = results[1] as int;

      if (!mounted) {
        return;
      }

      setState(() {
        _subscriptionTotal = subscriptionTotal;

        // 저장된 예산이 있으면 화면에 자동 반영
        if (budget != null) {
          _totalBudgetController.text = comma(budget.totalBudget);
          _startDay = budget.startDay;
          _fixedExpenseTotal = budget.fixedExpenseTotal;

          _categoryBudgets = Map<String, int>.from(
            budget.categoryBudgets,
          );
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

      await DdaengModal.alert(
        context,
        title: '예산을 불러오지 못했어요',
        message: '$e',
        type: ModalType.danger,
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

    if (selectedDay != null && mounted) {
      setState(() {
        _startDay = selectedDay;
      });
    }
  }

  /// 카테고리별 예산 설정 화면으로 이동
  Future<void> _openCategorySetting() async {
    if (_totalBudget <= 0) {
      await DdaengModal.alert(
        context,
        title: '전체 예산을 입력해 주세요',
        message: '카테고리별 예산을 설정하려면 전체 예산이 먼저 필요해요.',
        type: ModalType.warning,
      );
      return;
    }

    if (_isAvailableBudgetNegative) {
      await DdaengModal.alert(
        context,
        title: '사용 가능한 예산이 부족해요',
        message: '전체 예산이 고정지출과 구독료의 합계보다 적습니다.',
        type: ModalType.warning,
      );
      return;
    }

    final Map<String, int>? result =
    await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryBudgetSettingScreen(
          availableBudget: _availableBudget,
          initialCategoryBudgets: Map<String, int>.from(
            _categoryBudgets,
          ),
        ),
      ),
    );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _categoryBudgets = Map<String, int>.from(result);
    });

    // 카테고리 설정 결과가 가용 예산을 초과하면 간단한 알림 표시
    if (_isCategoryBudgetExceeded && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('예산을 초과했어요!'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  /// 예산 저장 및 수정
  Future<void> _saveBudget() async {
    if (_isSaving) {
      return;
    }

    // 전체 예산 입력값 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 고정지출과 구독료가 전체 예산보다 큰 경우
    if (_isAvailableBudgetNegative) {
      await DdaengModal.alert(
        context,
        title: '사용 가능한 예산이 부족해요',
        message: '전체 예산이 고정지출과 구독료의 합계보다 적습니다.',
        type: ModalType.warning,
      );
      return;
    }

    // 카테고리 예산 합계가 가용 예산보다 큰 경우
    if (_isCategoryBudgetExceeded) {
      await DdaengModal.alert(
        context,
        title: '예산을 초과했어요!',
        message: '카테고리 예산 합계를 가용 예산 안으로 조정해 주세요.',
        type: ModalType.warning,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Firestore에 신규 저장 또는 기존 문서 수정
      await _budgetService.saveBudget(
        userId: widget.userId,
        month: _currentMonth,
        totalBudget: _totalBudget,
        startDay: _startDay,
        fixedExpenseTotal: _fixedExpenseTotal,
        subscriptionTotal: _subscriptionTotal,
        categoryBudgets: Map<String, int>.from(
          _categoryBudgets,
        ),
      );

      if (!mounted) {
        return;
      }

      await DdaengModal.alert(
        context,
        title: '예산 설정을 저장했어요',
        type: ModalType.success,
      );

      // 저장된 값을 다시 조회해 화면 동기화
      await _loadBudget();
    } catch (e) {
      if (!mounted) {
        return;
      }

      await DdaengModal.alert(
        context,
        title: '예산을 저장하지 못했어요',
        message: '$e',
        type: ModalType.danger,
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
    // 예산 정보 조회 중
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
              16,
              20,
              32,
            ),
            children: [
              // 전체 예산 입력 카드
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
                      autovalidateMode:
                      AutovalidateMode.onUserInteraction,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        // 입력과 동시에 천 단위 쉼표 표시
                        ThousandsFormatter(),
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
                    const SizedBox(height: 8),

                    // 숫자 금액 아래 한글 금액 표시
                    Text(
                      _totalBudget > 0
                          ? koreanAmount(_totalBudget)
                          : '금액을 입력해 주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _totalBudget > 0
                            ? const Color(0xFF667085)
                            : const Color(0xFF98A2B3),
                      ),
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

              // 안내 카드
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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

              // 카테고리별 예산 설정 버튼
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // 예산 계산 결과
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isCategoryBudgetExceeded
                        ? const Color(0xFFF04438)
                        : const Color(0xFFE4E7EC),
                  ),
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
                      valueColor: _isAvailableBudgetNegative
                          ? const Color(0xFFF04438)
                          : const Color(0xFF12B76A),
                      isBold: true,
                    ),
                    if (_categoryBudgets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAmountRow(
                        label: '카테고리 배분 합계',
                        amount: _categoryTotal,
                        valueColor: _isCategoryBudgetExceeded
                            ? const Color(0xFFF04438)
                            : const Color(0xFF101828),
                      ),
                      const SizedBox(height: 12),
                      _buildAmountRow(
                        label: '미배분 예산',
                        amount: _availableBudget - _categoryTotal,
                        valueColor: _isCategoryBudgetExceeded
                            ? const Color(0xFFF04438)
                            : const Color(0xFF2F6BFF),
                      ),
                    ],

                    // 예산 초과 실시간 안내
                    if (_isCategoryBudgetExceeded) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: Color(0xFFF04438),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '예산을 초과했어요!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF04438),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_isAvailableBudgetNegative) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3F2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 20,
                              color: Color(0xFFF04438),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '전체 예산이 고정지출과 구독료보다 적어요!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF04438),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  // 예산 초과 시 저장 버튼 비활성화
                  onPressed: _isSaveDisabled ? null : _saveBudget,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF101828),
                    disabledBackgroundColor: const Color(0xFFD0D5DD),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      : Text(
                    _isCategoryBudgetExceeded
                        ? '예산을 확인해 주세요'
                        : '저장하기',
                    style: const TextStyle(
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

  /// 설정 메뉴 카드
  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required String trailingText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF0FDF4),
                child: Icon(
                  icon,
                  color: const Color(0xFF12B76A),
                  size: 20,
                ),
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

  /// 금액 요약 행
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
          '${comma(amount)}원',
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
}