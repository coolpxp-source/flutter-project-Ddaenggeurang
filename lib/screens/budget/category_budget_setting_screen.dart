import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/formatters.dart';

// ══════════════════════ 브랜드 색상 (예산 설정 화면과 통일) ══════════════════════
class _C {
  static const navy = Color(0xFF0D2247);
  static const blue = Color(0xFF2F6BFF);
  static const blueDeep = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFEEF4FF);
  static const ink = Color(0xFF191F28);
  static const inkSub = Color(0xFF8B95A1);
  static const line = Color(0xFFEEEEF3);
  static const bg = Color(0xFFF7F8FA);
  static const red = Color(0xFFF04438);
  static const redSoft = Color(0xFFFEF3F2);
  static const unallocated = Color(0xFFE4E7EC);
}

class CategoryBudgetSettingScreen extends StatefulWidget {
  // 카테고리에 배분할 수 있는 최대 금액
  final int availableBudget;

  // 기존에 저장된 카테고리 예산
  final Map<String, int> initialCategoryBudgets;

  // 지난 달 카테고리별 예산 (비교용, 없으면 빈 맵)
  final Map<String, int> previousCategoryBudgets;

  const CategoryBudgetSettingScreen({
    super.key,
    required this.availableBudget,
    required this.initialCategoryBudgets,
    this.previousCategoryBudgets = const {},
  });

  @override
  State<CategoryBudgetSettingScreen> createState() =>
      _CategoryBudgetSettingScreenState();
}

class _CategoryBudgetSettingScreenState
    extends State<CategoryBudgetSettingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 카테고리 기본 정보 (카테고리별 고유 색상 포함)
  final List<_BudgetCategory> _categories = const [
    _BudgetCategory(
      keyName: 'food',
      name: '식비',
      icon: Icons.restaurant_outlined,
      color: Color(0xFFFF6B81),
    ),
    _BudgetCategory(
      keyName: 'transport',
      name: '교통',
      icon: Icons.directions_bus_outlined,
      color: Color(0xFF4DA6FF),
    ),
    _BudgetCategory(
      keyName: 'shopping',
      name: '쇼핑',
      icon: Icons.shopping_bag_outlined,
      color: Color(0xFFFFB84D),
    ),
    _BudgetCategory(
      keyName: 'culture',
      name: '문화',
      icon: Icons.movie_outlined,
      color: Color(0xFFB197FC),
    ),
    _BudgetCategory(
      keyName: 'housing',
      name: '주거',
      icon: Icons.home_outlined,
      color: Color(0xFF20C997),
    ),
    _BudgetCategory(
      keyName: 'etc',
      name: '기타',
      icon: Icons.more_horiz,
      color: Color(0xFFADB5BD),
    ),
  ];

  final Map<String, TextEditingController> _controllers = {};

  // 마지막으로 입력한 카테고리 (여기에만 잔여 예산 안내를 표시)
  String? _lastEditedKey;

  @override
  void initState() {
    super.initState();

    // 기존 예산을 입력창 초기값으로 설정
    for (final category in _categories) {
      final int amount =
          widget.initialCategoryBudgets[category.keyName] ?? 0;

      _controllers[category.keyName] = TextEditingController(
        text: amount > 0 ? comma(amount) : '',
      );

      _controllers[category.keyName]!.addListener(
            () => _onCategoryChanged(category.keyName),
      );
    }
  }

  /// 카테고리 입력값이 바뀔 때마다 호출 — 마지막으로 만진 카테고리를 기록
  void _onCategoryChanged(String keyName) {
    if (mounted) {
      setState(() {
        _lastEditedKey = keyName;
      });
    }
  }

  int _parseAmount(String value) {
    return int.tryParse(
      value.replaceAll(',', '').trim(),
    ) ??
        0;
  }

  /// 카테고리별 현재 입력 금액
  int _amountOf(String keyName) {
    return _parseAmount(_controllers[keyName]?.text ?? '');
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

  /// 가장 많이 배분된 카테고리 (배분액이 하나도 없으면 null)
  _BudgetCategory? get _topCategory {
    if (_categoryTotal <= 0) return null;

    _BudgetCategory? top;
    int topAmount = 0;

    for (final category in _categories) {
      final int amount = _amountOf(category.keyName);
      if (amount > topAmount) {
        topAmount = amount;
        top = category;
      }
    }

    return top;
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
      result[category.keyName] = _amountOf(category.keyName);
    }

    Navigator.pop(context, result);
  }

  @override
  void dispose() {
    // 각 컨트롤러는 화면 종료 시 반드시 해제한다.
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isExceeded = _remainingBudget < 0;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          '카테고리별 예산 설정',
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
                        color: _C.blueSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: _C.blue,
                            child: Icon(
                              Icons.auto_awesome_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '가용 예산 ${comma(widget.availableBudget)}원을 '
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

                    // 도넛 차트: 카테고리별 비중 시각화
                    _buildDonutCard(),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isExceeded ? _C.red : _C.line,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow(
                            label: '카테고리 예산 합계',
                            value: '${comma(_categoryTotal)}원',
                          ),
                          const SizedBox(height: 10),
                          _buildSummaryRow(
                            label: isExceeded ? '초과 금액' : '남은 예산',
                            value: '${comma(_remainingBudget.abs())}원',
                            valueColor:
                            isExceeded ? _C.red : _C.blueDeep,
                          ),
                        ],
                      ),
                    ),

                    // 지난 달 카테고리별 비교
                    if (widget.previousCategoryBudgets.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _buildPreviousMonthCompare(),
                    ],
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
                      backgroundColor: _C.navy,
                      disabledBackgroundColor: const Color(0xFFE5E8EB),
                      disabledForegroundColor: const Color(0xFFB0B8C1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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

  /// 도넛 차트 + 배분 비중 카드
  Widget _buildDonutCard() {
    final int chartBase = widget.availableBudget > _categoryTotal
        ? widget.availableBudget
        : (_categoryTotal > 0 ? _categoryTotal : 1);

    final List<_DonutSlice> slices = [];

    for (final category in _categories) {
      final int amount = _amountOf(category.keyName);
      if (amount > 0) {
        slices.add(_DonutSlice(
          color: category.color,
          fraction: amount / chartBase,
        ));
      }
    }

    final int unallocated = chartBase - _categoryTotal;
    if (unallocated > 0) {
      slices.add(_DonutSlice(
        color: _C.unallocated,
        fraction: unallocated / chartBase,
      ));
    }

    final _BudgetCategory? top = _topCategory;

    return Container(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(110, 110),
                  painter: _DonutChartPainter(slices: slices),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _categoryTotal > 0
                          ? '${(_categoryTotal / chartBase * 100).round()}%'
                          : '0%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _C.navy,
                      ),
                    ),
                    const Text(
                      '배분됨',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: _C.inkSub,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  top != null ? '${top.name}에 가장 많이 배분했어요' : '아직 배분한 카테고리가 없어요',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
                const SizedBox(height: 10),
                ..._categories.where((c) => _amountOf(c.keyName) > 0).map(
                      (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _C.inkSub,
                            ),
                          ),
                        ),
                        Text(
                          '${(_amountOf(c.keyName) / chartBase * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _C.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 지난 달 카테고리별 비교 카드
  Widget _buildPreviousMonthCompare() {
    return Container(
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
            '지난 달과 비교',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _C.ink,
            ),
          ),
          const SizedBox(height: 14),
          ..._categories.map((category) {
            final int current = _amountOf(category.keyName);
            final int previous =
                widget.previousCategoryBudgets[category.keyName] ?? 0;

            if (current == 0 && previous == 0) {
              return const SizedBox.shrink();
            }

            final int diff = current - previous;
            final bool increased = diff > 0;
            final bool unchanged = diff == 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(category.icon, size: 16, color: category.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _C.ink,
                      ),
                    ),
                  ),
                  Text(
                    '${comma(current)}원',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _C.ink,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (!unchanged)
                    Row(
                      children: [
                        Icon(
                          increased
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 13,
                          color: increased ? _C.red : _C.blue,
                        ),
                        Text(
                          comma(diff.abs()),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: increased ? _C.red : _C.blue,
                          ),
                        ),
                      ],
                    )
                  else
                    const Text(
                      '동일',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _C.inkSub,
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 카테고리별 금액 입력 카드
  ///
  /// 수입 입력 화면과 동일하게:
  /// - 입력 전에는 큰 글씨로 0원만 표시
  /// - 숫자를 입력하면 천 단위 쉼표가 적용됨
  /// - 금액이 1원 이상일 때만 아래에 한글 금액 자막 표시
  /// - 마지막으로 입력한 카테고리에만 남은 예산 안내 표시
  Widget _buildCategoryCard(_BudgetCategory category) {
    final TextEditingController controller =
    _controllers[category.keyName]!;
    final int amount = _amountOf(category.keyName);

    // 전체 카테고리 입력 후 남아 있는 예산
    final int remainingAfterThis =
        widget.availableBudget - _categoryTotal;
    final bool exceeded = remainingAfterThis < 0;
    final bool isLastEdited =
        category.keyName == _lastEditedKey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exceeded && isLastEdited
              ? _C.red
              : _C.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리명과 아이콘
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                category.color.withOpacity(0.14),
                child: Icon(
                  category.icon,
                  color: category.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 큰 금액 입력 영역
          TextFormField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            inputFormatters: [
              // 숫자 이외 입력을 막고 천 단위 쉼표를 자동 적용
              FilteringTextInputFormatter.digitsOnly,
              ThousandsFormatter(),
            ],
            style: const TextStyle(
              fontSize: 29,
              height: 1.15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: _C.ink,
            ),
            cursorColor: _C.blue,
            decoration: InputDecoration(
              // 값이 없을 때는 수입 입력 화면처럼 0원 표시
              hintText: '0',
              hintStyle: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB0B8C1),
              ),
              suffixText: '원',
              suffixStyle: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: amount > 0
                    ? _C.ink
                    : const Color(0xFFB0B8C1),
              ),
              isDense: true,
              contentPadding:
              const EdgeInsets.only(bottom: 10),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _C.line,
                  width: 1.2,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: category.color,
                  width: 1.8,
                ),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _C.red,
                  width: 1.4,
                ),
              ),
              focusedErrorBorder:
              const UnderlineInputBorder(
                borderSide: BorderSide(
                  color: _C.red,
                  width: 1.8,
                ),
              ),
            ),
            validator: (value) {
              final int parsed =
              _parseAmount(value ?? '');

              if (parsed < 0) {
                return '0원 이상 입력해 주세요.';
              }

              return null;
            },
          ),

          // 입력값이 1원 이상일 때만 한글 금액 자막 표시
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: amount > 0
                ? Padding(
              key: ValueKey<int>(amount),
              padding:
              const EdgeInsets.only(top: 7),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  koreanAmount(amount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _C.inkSub,
                  ),
                ),
              ),
            )
                : const SizedBox.shrink(
              key: ValueKey<String>('empty'),
            ),
          ),

          // 마지막으로 입력한 카테고리에만 남은 예산 또는 초과 안내
          if (isLastEdited && amount > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color:
                exceeded ? _C.redSoft : _C.blueSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    exceeded
                        ? Icons.error_outline_rounded
                        : Icons
                        .check_circle_outline_rounded,
                    size: 16,
                    color:
                    exceeded ? _C.red : _C.blue,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      exceeded
                          ? '전체 예산을 ${comma(remainingAfterThis.abs())}원 초과했어요'
                          : '전체 남은 예산 ${comma(remainingAfterThis)}원',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: exceeded
                            ? _C.red
                            : _C.blueDeep,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
    Color valueColor = _C.ink,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: _C.inkSub,
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
}

class _BudgetCategory {
  final String keyName;
  final String name;
  final IconData icon;
  final Color color;

  const _BudgetCategory({
    required this.keyName,
    required this.name,
    required this.icon,
    required this.color,
  });
}

/// 도넛 차트 한 조각
class _DonutSlice {
  final Color color;
  final double fraction;

  const _DonutSlice({required this.color, required this.fraction});
}

/// 도넛 차트를 직접 그리는 CustomPainter
class _DonutChartPainter extends CustomPainter {
  final List<_DonutSlice> slices;

  _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = size.width * 0.16;
    final Rect rect = Offset.zero & size;
    final Rect arcRect = rect.deflate(strokeWidth / 2);

    if (slices.isEmpty) {
      final paint = Paint()
        ..color = _C.unallocated
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawArc(arcRect, 0, 6.28319, false, paint);
      return;
    }

    double startAngle = -1.5708; // -90도(위쪽)부터 시작

    for (final slice in slices) {
      final double sweepAngle = slice.fraction * 6.28319;

      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return true;
  }
}