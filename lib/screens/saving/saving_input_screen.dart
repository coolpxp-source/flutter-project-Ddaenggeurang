import 'package:flutter/material.dart';
import '../../models/saving_model.dart';
import '../../models/category_model.dart';
import '../../services/saving_service.dart';
import '../../services/category_service.dart';

/// 저축/투자 추가하기 - 사진업로드 없이 직접입력만
///
/// TODO: 지금은 기본 카테고리(isCustom=false)만 불러옴 — 사용자 커스텀 카테고리는
///       CategoryService.getMyCustomCategories(userId, ...)와 합쳐서 보여줘야 함
class SavingInputScreen extends StatefulWidget {
  const SavingInputScreen({super.key});

  @override
  State<SavingInputScreen> createState() => _SavingInputScreenState();
}

class _SavingInputScreenState extends State<SavingInputScreen> {
  final _savingService = SavingService();
  final _categoryService = CategoryService();
  final _amountController = TextEditingController(text: '0');
  final _accountNameController = TextEditingController();
  final _memoController = TextEditingController();

  // 투자 전용 필드
  final _brokerageController = TextEditingController();
  final _assetNameController = TextEditingController();
  final _quantityController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  CategoryModel? _selectedCategory;

  late final Stream<List<CategoryModel>> _categoryStream;

  @override
  void initState() {
    super.initState();
    _categoryStream =
        _categoryService.getDefaultCategories(transactionType: TransactionType.saving);
  }

  // 시딩 데이터의 저축 카테고리명이 '투자'인 경우에만 투자 상세 필드 노출
  bool get _isInvestment => _selectedCategory?.name == '투자';

  @override
  void dispose() {
    _amountController.dispose();
    _accountNameController.dispose();
    _memoController.dispose();
    _brokerageController.dispose();
    _assetNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  int get _amount => int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('항목을 선택해주세요')),
      );
      return;
    }
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요')),
      );
      return;
    }
    if (_isInvestment &&
        (_brokerageController.text.isEmpty || _assetNameController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('증권사와 종목명을 입력해주세요')),
      );
      return;
    }

    // TODO: userId는 실제 로그인 유저 uid로 교체 (FirebaseAuth.instance.currentUser?.uid)
    const userId = 'TODO_USER_ID';

    final saving = SavingModel(
      savingId: '',
      userId: userId,
      date: _selectedDate,
      categoryId: _selectedCategory!.categoryId,
      accountName: _accountNameController.text.isEmpty ? null : _accountNameController.text,
      amount: _amount,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
      investmentDetail: _isInvestment
          ? InvestmentDetail(
        brokerage: _brokerageController.text,
        assetName: _assetNameController.text,
        quantity: double.tryParse(_quantityController.text),
      )
          : null,
    );

    await _savingService.addSaving(saving);

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
        title: const Text('저축/투자 입력'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('항목', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildCategoryChips(),
            const SizedBox(height: 20),

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
              label: '계좌명',
              child: SizedBox(
                width: 180,
                child: TextField(
                  controller: _accountNameController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '예: 국민은행 청년희망적금',
                    isDense: true,
                  ),
                ),
              ),
            ),
            _buildFormRow(
              label: '금액',
              child: SizedBox(
                width: 140,
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
            ),

            // 투자 카테고리일 때만 증권사/종목/수량 추가 노출
            if (_isInvestment) ...[
              const Divider(height: 32),
              const Text('투자 상세', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 8),
              _buildFormRow(
                label: '증권사',
                child: SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _brokerageController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '예: 토스증권',
                      isDense: true,
                    ),
                  ),
                ),
              ),
              _buildFormRow(
                label: '종목명',
                child: SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _assetNameController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '예: S&P500 ETF',
                      isDense: true,
                    ),
                  ),
                ),
              ),
              _buildFormRow(
                label: '수량 (선택)',
                child: SizedBox(
                  width: 100,
                  child: TextField(
                    controller: _quantityController,
                    textAlign: TextAlign.right,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '예: 5',
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],

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
          ],
        ),
      ),
    );
  }

  /// 저축 카테고리(청약/적금/예금/파킹통장/투자)를 실제 Firestore에서 불러와 칩으로 표시
  Widget _buildCategoryChips() {
    return StreamBuilder<List<CategoryModel>>(
      stream: _categoryStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('카테고리를 불러오지 못했어요: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12));
        }

        final categories = snapshot.data ?? [];
        if (categories.isEmpty) {
          return const Text('등록된 저축 카테고리가 없어요', style: TextStyle(color: Colors.grey));
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((c) {
            final selected = _selectedCategory?.categoryId == c.categoryId;
            return ChoiceChip(
              label: Text(c.name),
              selected: selected,
              onSelected: (_) => setState(() => _selectedCategory = c),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFormRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), child],
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