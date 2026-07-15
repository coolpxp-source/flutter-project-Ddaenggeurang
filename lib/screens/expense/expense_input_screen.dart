import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../models/emotion_tag_model.dart';
import '../../services/expense_service.dart';
import '../../widgets/expense/category_quick_chip.dart';
import '../../utils/seed_expense_categories.dart'; // TODO(임시): 시딩 끝나면 이 import 삭제
import '../../utils/seed_saving_categories.dart'; // TODO(임시): 시딩 끝나면 이 import 삭제

/// 10_내역입력_기본 - 지출 입력 화면
///
/// TODO: 사진 촬영/갤러리 버튼은 ML Kit OCR 연동 후 결과를 아래 폼에 자동 채우는 방식으로 연결
/// TODO: "일시불" 태그 탭 시 할부 개월 선택 바텀시트 → InstallmentPlanService와 연결
/// TODO: 카테고리 "+ 추가"는 category/category_management_screen.dart로 이동
/// TODO: 퀵카테고리 categoryId는 임시 슬러그값 — category_service로 실제 Firestore
///       categories 컬렉션에서 nature별로 조회하도록 교체 필요
///       구상중 ...
class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({super.key});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

/// 퀵카테고리 하나(임시 데이터) - 실제로는 CategoryModel에서 옴
class _QuickCategory {
  final String categoryId; // TODO: 실제 Firestore 문서ID로 교체
  final String label;
  final IconData icon;
  const _QuickCategory(this.categoryId, this.label, this.icon);
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _expenseService = ExpenseService();
  final _amountController = TextEditingController(text: '0');
  final _placeController = TextEditingController();
  final _memoController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedCategoryLabel;

  // 지출 성격 3분류 — 카테고리의 nature 필드와 항상 일치해야 함
  ExpenseNature _selectedNature = ExpenseNature.variable;

  EmotionTag? _selectedEmotionTag;
  bool _isInstallment = false; // "일시불" 태그 탭 시 true로 전환 (할부 개월 선택 필요)

  // TODO(임시): 시딩 중복 방지용 - 버튼 누르는 동안 다시 못 누르게 막는 플래그
  bool _isSeeding = false;

  // nature별 퀵카테고리 - TODO: category_service.getCategories(nature: ...)로 교체
  static const Map<ExpenseNature, List<_QuickCategory>> _quickCategoriesByNature = {
    ExpenseNature.fixed: [
      _QuickCategory('rent', '월세', Icons.home_outlined),
      _QuickCategory('maintenance_fee', '관리비', Icons.apartment_outlined),
      _QuickCategory('phone_bill', '휴대폰요금', Icons.smartphone_outlined),
      _QuickCategory('internet', '인터넷', Icons.wifi),
      _QuickCategory('insurance', '보험료', Icons.health_and_safety_outlined),
      _QuickCategory('ott', 'OTT/구독', Icons.subscriptions_outlined),
    ],
    ExpenseNature.variable: [
      _QuickCategory('meal', '식사', Icons.restaurant),
      _QuickCategory('cafe', '카페/디저트', Icons.local_cafe),
      _QuickCategory('mart', '마트/장보기', Icons.shopping_cart_outlined),
      _QuickCategory('public_transport', '대중교통', Icons.directions_bus),
      _QuickCategory('clothes', '의류/잡화', Icons.shopping_bag),
      _QuickCategory('hospital', '병원', Icons.medical_services),
    ],
    ExpenseNature.other: [
      _QuickCategory('congratulation_money', '축의금/조의금', Icons.card_giftcard),
      _QuickCategory('birthday_gift', '생일선물', Icons.redeem),
      _QuickCategory('holiday_money', '명절용돈', Icons.celebration_outlined),
      _QuickCategory('uncategorized', '미분류(기타)', Icons.category_outlined),
    ],
  };

  List<_QuickCategory> get _currentQuickCategories =>
      _quickCategoriesByNature[_selectedNature]!;

  @override
  void dispose() {
    _amountController.dispose();
    _placeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// nature 탭을 바꾸면 이전 nature의 카테고리가 남아있으면 안 되니 초기화
  void _selectNature(ExpenseNature nature) {
    if (_selectedNature == nature) return;
    setState(() {
      _selectedNature = nature;
      _selectedCategoryId = null;
      _selectedCategoryLabel = null;
      if (nature != ExpenseNature.variable) {
        _selectedEmotionTag = null;
      }
    });
  }

  void _selectQuickCategory(_QuickCategory category) {
    setState(() {
      _selectedCategoryLabel = category.label;
      _selectedCategoryId = category.categoryId;
    });
  }

  void _onTapReceiptCapture() {
    // TODO: image_picker(카메라) → ML Kit OCR → 파싱 결과로 폼 채우기
  }

  void _onTapGalleryPick() {
    // TODO: image_picker(갤러리) → ML Kit OCR → 파싱 결과로 폼 채우기
  }

  void _onTapInstallmentTag() {
    // TODO: 할부 개월 선택 바텀시트 표시, 선택 완료 시 _isInstallment = true로 전환
    setState(() => _isInstallment = !_isInstallment);
  }

  // ─────────────────────────────────────────────
  // TODO(임시): 카테고리 시딩용 - Firestore에 categories 컬렉션 채우기.
  // 딱 한 번만 실행할 것! 실행 확인 후 이 메서드 + AppBar의 아이콘 버튼 + 상단 import 2줄 삭제.
  // ─────────────────────────────────────────────
  Future<void> _runSeedOnce() async {
    if (_isSeeding) return; // 중복 클릭 방지

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리 시딩'),
        content: const Text(
          '지출(34개) + 저축(5개) 기본 카테고리를 Firestore에 추가합니다.\n'
              '이미 시딩했다면 중복 생성되니 다시 누르지 마세요.\n계속할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('실행')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSeeding = true);
    try {
      await seedExpenseCategories();
      await seedSavingCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카테고리 시딩 완료! Firestore 콘솔에서 확인해보세요.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시딩 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  Future<void> _save() async {
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카테고리를 선택해주세요')),
      );
      return;
    }

    final amount = int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요')),
      );
      return;
    }

    // TODO: userId는 실제 로그인 유저 uid로 교체 (FirebaseAuth.instance.currentUser?.uid)
    const userId = 'TODO_USER_ID';

    final expense = ExpenseModel(
      expenseId: '',
      userId: userId,
      amount: amount,
      date: _selectedDate,
      categoryId: _selectedCategoryId!,
      nature: _selectedNature,
      emotionTag:
      _selectedNature == ExpenseNature.variable ? _selectedEmotionTag?.code : null,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
    );

    await _expenseService.addExpense(expense);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('지출 입력'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // TODO(임시): 카테고리 시딩 버튼 - 딱 한 번 누르고 나면 이 IconButton 통째로 삭제
          IconButton(
            icon: _isSeeding
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: '[임시] 카테고리 시딩',
            onPressed: _isSeeding ? null : _runSeedOnce,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuickPhotoBanner(),
            const SizedBox(height: 20),
            const Center(
              child: Text('또는 직접 입력', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
            const SizedBox(height: 16),

            // 지출 성격 3분류 — 가장 먼저 선택, 이 선택에 따라 아래 카테고리 목록이 필터링됨
            _buildNatureSegment(),
            const SizedBox(height: 12),

            _buildFormRow(
              label: '일시',
              child: InkWell(
                onTap: _pickDate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 4),
                    Text(_formatDate(_selectedDate)),
                  ],
                ),
              ),
            ),
            _buildFormRow(
              label: '카테고리',
              labelColor: Colors.green,
              child: Text(_selectedCategoryLabel ?? '선택'),
            ),
            _buildFormRow(
              label: '금액',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _amountController,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        suffixText: '원',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: Text(_isInstallment ? '할부' : '일시불'),
                    onPressed: _onTapInstallmentTag,
                  ),
                ],
              ),
            ),
            _buildFormRow(
              label: '사용처',
              child: SizedBox(
                width: 160,
                child: TextField(
                  controller: _placeController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '입력 (선택)',
                    isDense: true,
                  ),
                ),
              ),
            ),
            _buildFormRow(
              label: '메모',
              child: SizedBox(
                width: 160,
                child: TextField(
                  controller: _memoController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '선택 사항',
                    isDense: true,
                  ),
                ),
              ),
            ),

            // 변동비일 때만 감정태그 노출
            if (_selectedNature == ExpenseNature.variable) ...[
              const SizedBox(height: 8),
              const Text('감정태그', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: EmotionTag.values.map((tag) {
                  final selected = _selectedEmotionTag == tag;
                  return ChoiceChip(
                    label: Text('${tag.emoji} ${tag.label}'),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedEmotionTag = tag),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('저장', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('카테고리 선택', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {
                    // TODO: category_management_screen.dart 로 이동
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('추가'),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _currentQuickCategories.map((c) {
                return CategoryQuickChip(
                  icon: c.icon,
                  label: c.label,
                  isSelected: _selectedCategoryLabel == c.label,
                  onTap: () => _selectQuickCategory(c),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 고정비 / 변동비 / 기타 3분류 세그먼트
  /// 여기서 고른 값에 따라 아래 퀵카테고리 목록 + 감정태그 노출 여부가 결정됨
  Widget _buildNatureSegment() {
    return Row(
      children: ExpenseNature.values.map((nature) {
        final selected = _selectedNature == nature;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Center(child: Text(nature.label)),
              selected: selected,
              onSelected: (_) => _selectNature(nature),
              selectedColor: Colors.green.withOpacity(0.15),
              labelStyle: TextStyle(
                color: selected ? Colors.green[800] : Colors.black87,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickPhotoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✨ 사진으로 빠르게 입력', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text(
            '영수증이나 결제 알림 캡처를 올리면 AI가 알아서 채워드려요',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onTapReceiptCapture,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('촬영하기'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _onTapGalleryPick,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('갤러리에서 선택'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required Widget child,
    Color? labelColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: labelColor ?? Colors.black87)),
          child,
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '오늘';
    }
    return '${date.month}/${date.day}';
  }
}