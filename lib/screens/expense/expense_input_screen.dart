import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../models/emotion_tag_model.dart';
import '../../services/expense_service.dart';
import '../../widgets/expense/category_quick_chip.dart';

/// 10_내역입력_기본 - 지출 입력 화면
///
/// TODO: 사진 촬영/갤러리 버튼은 ML Kit OCR 연동 후 결과를 아래 폼에 자동 채우는 방식으로 연결
/// TODO: "일시불" 태그 탭 시 할부 개월 선택 바텀시트 → InstallmentPlanService와 연결
/// TODO: 카테고리 "+ 추가"는 category/category_management_screen.dart로 이동
class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({super.key});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _expenseService = ExpenseService();
  final _amountController = TextEditingController(text: '0');
  final _placeController = TextEditingController();
  final _memoController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedCategoryId;
  String? _selectedCategoryLabel;
  bool _isFixed = false; // 고정지출 토글 (false = 변동비 → 감정태그 활성화)
  EmotionTag? _selectedEmotionTag;
  bool _isInstallment = false; // "일시불" 태그 탭 시 true로 전환 (할부 개월 선택 필요)

  // 하단 퀵 카테고리 - 실제로는 category_service에서 자주쓰는 카테고리 불러오는 걸로 교체 예정
  final _quickCategories = const [
    {'icon': Icons.restaurant, 'label': '식비'},
    {'icon': Icons.local_cafe, 'label': '카페'},
    {'icon': Icons.directions_bus, 'label': '교통'},
    {'icon': Icons.shopping_bag, 'label': '쇼핑'},
    {'icon': Icons.home, 'label': '생활비'},
    {'icon': Icons.medical_services, 'label': '의료'},
  ];

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

  void _selectQuickCategory(String label) {
    setState(() {
      _selectedCategoryLabel = label;
      // TODO: 실제 categoryId는 category_service에서 label로 조회해서 채워야 함
      _selectedCategoryId = label;
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
      nature: _isFixed ? ExpenseNature.fixed : ExpenseNature.variable,
      emotionTag: _isFixed ? null : _selectedEmotionTag?.code,
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
            _buildFormRow(
              label: '고정지출',
              child: Switch(
                value: _isFixed,
                onChanged: (v) => setState(() => _isFixed = v),
              ),
            ),

            // 변동비일 때만 감정태그 노출 (시안엔 없었지만 모델 규칙상 필요)
            if (!_isFixed) ...[
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
              children: _quickCategories.map((c) {
                final label = c['label'] as String;
                return CategoryQuickChip(
                  icon: c['icon'] as IconData,
                  label: label,
                  isSelected: _selectedCategoryLabel == label,
                  onTap: () => _selectQuickCategory(label),
                );
              }).toList(),
            ),
          ],
        ),
      ),
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