import 'package:flutter/material.dart';

import '../../models/budget_model.dart';
import '../../services/budget_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'category_budget_setting_screen.dart';

// ══════════════════════ 브랜드 색상 (온보딩 화면과 통일) ══════════════════════
class _C {
  static const navy = Color(0xFF0D2247);
  static const blue = Color(0xFF2F6BFF);
  static const blueDeep = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFEEF4FF);
  static const gold = Color(0xFFFFC93C);
  static const ink = Color(0xFF191F28);
  static const inkSub = Color(0xFF8B95A1);
  static const line = Color(0xFFEEEEF3);
  static const bg = Color(0xFFF7F8FA);
  static const red = Color(0xFFF04438);
  static const redSoft = Color(0xFFFEF3F2);
}

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

  // 저번 달 전체 예산 (비교용)
  int _previousBudgetTotal = 0;

  // 로딩 및 저장 상태
  bool _isLoading = true;
  bool _isSaving = false;

  /// 현재 연월을 YYYY-MM 형식으로 반환
  String get _currentMonth {
    final DateTime now = DateTime.now();

    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// 저번 달을 YYYY-MM 형식으로 반환
  String get _previousMonth {
    final DateTime now = DateTime.now();
    final DateTime prev = DateTime(now.year, now.month - 1);
    return '${prev.year}-${prev.month.toString().padLeft(2, '0')}';
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

        // 저번 달 예산 조회 (비교용, 없으면 null)
        _budgetService.getBudget(
          userId: widget.userId,
          month: _previousMonth,
        ),
      ]);

      final BudgetModel? budget = results[0] as BudgetModel?;
      final int subscriptionTotal = results[1] as int;
      final BudgetModel? previousBudget = results[2] as BudgetModel?;

      if (!mounted) {
        return;
      }

      setState(() {
        _subscriptionTotal = subscriptionTotal;
        _previousBudgetTotal = previousBudget?.totalBudget ?? 0;

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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _C.line,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 18, 24, 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '예산 시작일 선택',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _C.ink,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: 31,
                      itemBuilder: (context, index) {
                        final int day = index + 1;
                        final bool sel = _startDay == day;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () =>
                                  Navigator.pop(bottomSheetContext, day),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: sel ? _C.blueSoft : _C.bg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: sel ? _C.navy : Colors.transparent,
                                    width: 1.4,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '매월 $day일',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: sel
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: sel ? _C.navy : _C.ink,
                                        ),
                                      ),
                                    ),
                                    if (sel)
                                      Container(
                                        width: 26,
                                        height: 26,
                                        decoration: const BoxDecoration(
                                          color: _C.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 17,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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
          child: CircularProgressIndicator(color: _C.blue),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          '예산 설정',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: _C.ink,
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
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _C.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_currentMonth 전체 예산',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.inkSub,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalBudgetController,
                            autovalidateMode:
                            AutovalidateMode.onUserInteraction,
                            textAlign: TextAlign.left,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              // 입력과 동시에 천 단위 쉼표 표시
                              ThousandsFormatter(),
                            ],
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: _C.navy,
                            ),
                            decoration: const InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Color(0xFFCBD2D9),
                                fontWeight: FontWeight.w900,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              border: InputBorder.none,
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
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 5, left: 6),
                          child: Text(
                            '원',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _C.inkSub,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // 숫자 금액 아래 한글 금액 표시
                    Text(
                      _totalBudget > 0
                          ? koreanAmount(_totalBudget)
                          : '금액을 입력해 주세요',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _totalBudget > 0
                            ? _C.blue
                            : const Color(0xFFB0B8C1),
                      ),
                    ),
                  ],
                ),
              ),
              _buildMonthCompareChart(),
              const SizedBox(height: 12),

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
                  color: _C.redSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: _C.red,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '전체 예산에서 고정지출과 구독료를 제외한 금액을 '
                            '카테고리별로 나눌 수 있습니다.',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _C.red,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 카테고리별 예산 설정 버튼
              _buildSettingTile(
                title: _categoryBudgets.isEmpty
                    ? '카테고리 예산 설정'
                    : '카테고리 예산 수정',
                subtitle: _categoryBudgets.isEmpty
                    ? '카테고리별로 예산을 나눠보세요.'
                    : '${_categoryBudgets.length}개 카테고리에 배분됨',
                trailingText: '',
                icon: Icons.tune_rounded,
                onTap: _openCategorySetting,
              ),
              const SizedBox(height: 22),

              // 예산 계산 결과
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _isCategoryBudgetExceeded
                        ? _C.red
                        : _C.line,
                    width: _isCategoryBudgetExceeded ? 1.4 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
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
                      isExpense: true,
                    ),
                    const SizedBox(height: 12),
                    _buildAmountRow(
                      label: '구독료',
                      amount: _subscriptionTotal,
                      isExpense: true,
                    ),
                    Divider(height: 28, color: _C.line),
                    _buildAmountRow(
                      label: '가용 예산',
                      amount: _availableBudget,
                      valueColor: _isAvailableBudgetNegative
                          ? _C.red
                          : _C.blue,
                      isBold: true,
                    ),
                    if (_categoryBudgets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAmountRow(
                        label: '카테고리 배분 합계',
                        amount: _categoryTotal,
                        valueColor: _isCategoryBudgetExceeded
                            ? _C.red
                            : _C.ink,
                      ),
                      const SizedBox(height: 12),
                      _buildAmountRow(
                        label: '미배분 예산',
                        amount: _availableBudget - _categoryTotal,
                        valueColor: _isCategoryBudgetExceeded
                            ? _C.red
                            : _C.blueDeep,
                      ),
                    ],

                    // 예산 초과 실시간 안내
                    if (_isCategoryBudgetExceeded) ...[
                      const SizedBox(height: 16),
                      _buildWarningBanner('예산을 초과했어요!'),
                    ],

                    if (_isAvailableBudgetNegative) ...[
                      const SizedBox(height: 16),
                      _buildWarningBanner('전체 예산이 고정지출과 구독료보다 적어요!'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  // 예산 초과 시 저장 버튼 비활성화
                  onPressed: _isSaveDisabled ? null : _saveBudget,
                  style: FilledButton.styleFrom(
                    backgroundColor: _C.navy,
                    disabledBackgroundColor: const Color(0xFFE5E8EB),
                    disabledForegroundColor: const Color(0xFFB0B8C1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                      fontWeight: FontWeight.w700,
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

  /// 이번 달 vs 저번 달 예산 비교 미니 차트
  Widget _buildMonthCompareChart() {
    // 둘 다 0이면 비교할 데이터가 없으니 표시 안 함
    if (_totalBudget <= 0 && _previousBudgetTotal <= 0) {
      return const SizedBox.shrink();
    }

    final int maxValue =
    [_totalBudget, _previousBudgetTotal, 1].reduce((a, b) => a > b ? a : b);
    final double prevRatio = _previousBudgetTotal / maxValue;
    final double currRatio = _totalBudget / maxValue;

    final bool increased = _totalBudget >= _previousBudgetTotal;
    final int diff = (_totalBudget - _previousBudgetTotal).abs();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '저번 달 대비',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _C.ink,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                increased
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 15,
                color: increased ? _C.red : _C.blue,
              ),
              const SizedBox(width: 2),
              Text(
                _previousBudgetTotal == 0
                    ? '저번 달 데이터 없음'
                    : '${comma(diff)}원 ${increased ? '늘었어요' : '줄었어요'}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _C.inkSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildHBar(
            label: '이번 달',
            amount: _totalBudget,
            ratio: currRatio,
            color: _C.blue,
            textColor: _C.blueDeep,
          ),
          const SizedBox(height: 14),
          _buildHBar(
            label: '저번 달',
            amount: _previousBudgetTotal,
            ratio: prevRatio,
            color: const Color(0xFFD8E3FF),
            textColor: _C.inkSub,
          ),
        ],
      ),
    );
  }

  /// 막대 하나 (라벨 + 가로 바 + 금액)
  Widget _buildHBar({
    required String label,
    required int amount,
    required double ratio,
    required Color color,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _C.inkSub,
              ),
            ),
            Text(
              '${comma(amount)}원',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              Container(
                height: 14,
                width: double.infinity,
                color: _C.bg,
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                height: 14,
                width: MediaQuery.of(context).size.width *
                    ratio.clamp(0.03, 1.0) *
                    0.72, // 카드 패딩 감안한 대략적 비율
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 예산 초과 경고 배너
  Widget _buildWarningBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: _C.redSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: _C.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _C.red,
              ),
            ),
          ),
        ],
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _C.line,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: _C.blueSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: _C.blue,
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
                        fontWeight: FontWeight.w800,
                        color: _C.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _C.inkSub,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingText.isNotEmpty) ...[
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: _C.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0B8C1),
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
    Color valueColor = _C.ink,
    bool isBold = false,
    bool isExpense = false,
  }) {
    // 지출성 항목(고정지출, 구독료)은 금액 앞에 '-' 표시
    final String prefix = isExpense && amount > 0 ? '-' : '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
            isBold ? FontWeight.bold : FontWeight.normal,
            color: _C.inkSub,
          ),
        ),
        Text(
          '$prefix${comma(amount)}원',
          style: TextStyle(
            fontSize: isBold ? 17 : 14,
            fontWeight:
            isBold ? FontWeight.bold : FontWeight.w600,
            color: isExpense && amount > 0 ? _C.red : valueColor,
          ),
        ),
      ],
    );
  }
}