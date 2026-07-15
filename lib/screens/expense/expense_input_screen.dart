import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../models/emotion_tag_model.dart';
import '../../models/category_model.dart';
import '../../services/expense_service.dart';
import '../../services/category_service.dart';
import '../../widgets/expense/category_quick_chip.dart';
import '../../widgets/expense/category_icon_map.dart';

/// 10_내역입력_기본 - 지출 입력 화면
///
/// TODO: 사진 촬영/갤러리 버튼은 ML Kit OCR 연동 후 결과를 아래 폼에 자동 채우는 방식으로 연결
/// TODO: "일시불" 태그 탭 시 할부 개월 선택 바텀시트 → InstallmentPlanService와 연결
/// TODO: 카테고리 "+ 추가"는 category/category_management_screen.dart로 이동
/// TODO: 지금은 기본 카테고리(isCustom=false)만 불러옴 — 사용자 커스텀 카테고리는
///       CategoryService.getMyCustomCategories(userId, ...)와 합쳐서 보여줘야 함
class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({super.key});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _expenseService = ExpenseService();
  final _categoryService = CategoryService();
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

  late final Stream<List<CategoryModel>> _categoryStream;

  @override
  void initState() {
    super.initState();
    // 화면 전체에서 한 번만 구독 — build마다 새 스트림 만들지 않도록 initState에서 생성
    _categoryStream =
        _categoryService.getDefaultCategories(transactionType: TransactionType.expense);
  }

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

  void _selectCategory(CategoryModel category) {
    setState(() {
      _selectedCategoryLabel = category.name;
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
            const SizedBox(height: 8),
            _buildCategoryGrid(),
          ],
        ),
      ),
    );
  }

  /// nature에 맞는 카테고리를 실제 Firestore에서 불러와 대분류(parentName)별로 묶어서 표시
  Widget _buildCategoryGrid() {
    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('카테고리를 불러오지 못했어요: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12)),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = all.where((c) => c.nature == _selectedNature).toList();

        if (filtered.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('등록된 카테고리가 없어요', style: TextStyle(color: Colors.grey)),
          );
        }

        // 대분류(parentName)별로 그룹핑, 원본 순서 유지
        final Map<String, List<CategoryModel>> grouped = {};
        for (final c in filtered) {
          grouped.putIfAbsent(c.parentName, () => []).add(c);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: entry.value.map((c) {
                      return SizedBox(
                        width: 76,
                        child: CategoryQuickChip(
                          icon: CategoryIconMap.iconFor(c.name),
                          label: c.name,
                          isSelected: _selectedCategoryId == c.categoryId,
                          onTap: () => _selectCategory(c),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// 고정비 / 변동비 / 기타 3분류 세그먼트
  /// 여기서 고른 값에 따라 아래 카테고리 목록 + 감정태그 노출 여부가 결정됨
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