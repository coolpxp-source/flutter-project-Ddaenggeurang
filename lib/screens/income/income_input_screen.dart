import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/formatters.dart';
import '../../models/income_model.dart';
import '../../services/income_service.dart';
import '../../models/transaction_item.dart';

class IncomeInputScreen extends StatefulWidget {
  final TransactionItem? editItem;
  const IncomeInputScreen({super.key, this.editItem});

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final IncomeService _incomeService = IncomeService();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _incomeCategories = [];
  bool _isLoadingCategories = true;

  String? _selectedParentCategory;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _isRecurring = false;
  int _payDay = 1;
  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.editItem != null) {
      final item = widget.editItem!;
      _amountController.text = item.amount.toString();
      _selectedDate = item.date;
      if (item.subtitle != null) _memoController.text = item.subtitle!;
      _currentAmount = item.amount;
    }

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      setState(() => _currentAmount = int.tryParse(text) ?? 0);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap = await db.collection('categories').where('transactionType', isEqualTo: 'income').get();
      // 💡 복합 색인 에러 방지용 메모리 필터링
      final customSnap = await db.collection('customCategories').where('userId', isEqualTo: userId).get();

      List<String> hiddenIds = [];
      final userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('hiddenCategories')) {
        hiddenIds = List<String>.from(userDoc.data()!['hiddenCategories']);
      }

      List<Map<String, dynamic>> loaded = [];
      for (var doc in defaultSnap.docs) {
        if (!hiddenIds.contains(doc.id)) loaded.add({'id': doc.id, ...doc.data()});
      }
      for (var doc in customSnap.docs) {
        final data = doc.data();
        if (data['transactionType'] == 'income' && data['isHidden'] != true) {
          loaded.add({'id': doc.id, ...data});
        }
      }

      setState(() {
        _incomeCategories = loaded;
        _isLoadingCategories = false;

        if (widget.editItem != null && _incomeCategories.isNotEmpty) {
          final matched = _incomeCategories.firstWhere(
                (c) => c['name'] == widget.editItem!.title,
            orElse: () => _incomeCategories.first,
          );
          _selectedCategoryId = matched['id'];
          _selectedCategoryName = matched['name'];
          _selectedParentCategory = matched['parentName']?.toString() ?? matched['parent']?.toString() ?? '미분류';
        }
      });
    } catch (e) {
      debugPrint('카테고리 로드 에러: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _saveIncome() async {
    if (_currentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수입 금액을 입력해주세요!')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('소분류 카테고리를 선택해주세요!')));
      return;
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
      final String? recurringTemplateId = _isRecurring ? 'temp_recurring_income_id' : null;

      final newIncome = IncomeModel(
        incomeId: widget.editItem != null ? widget.editItem!.id : '',
        userId: userId,
        amount: _currentAmount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text,
        recurringIncomeTemplateId: recurringTemplateId,
      );

      if (widget.editItem == null) {
        await _incomeService.addIncome(newIncome);
      } else {
        await _incomeService.updateIncome(widget.editItem!.id, newIncome.toFirestore());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('수입 내역이 저장되었습니다!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('🔥 저장 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double estimatedGross = _currentAmount / 0.967;

    final List<String> parentCategories = _incomeCategories
        .map((category) => (category['parentName'] ?? category['parent'] ?? '미분류').toString())
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : _incomeCategories.where((category) {
      final parent = category['parentName'] ?? category['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    // 💡 핵심: 대분류 이름에 '정기' 문자가 포함되어 있으면 정기수입으로 간주
    final bool isRegularIncome = _selectedParentCategory != null && _selectedParentCategory!.contains('정기');

    return Scaffold(
      appBar: AppBar(title: const Text('수입 기록')),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: '실수령액 (세후 금액)',
                prefixText: '₩ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
              ),
            ),

            if (_selectedCategoryName == '프리랜서' && _currentAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '약 ${NumberFormat('#,###').format(estimatedGross)}원 (세전 추정)',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(height: 24),

            const Text('1. 대분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: parentCategories.contains(_selectedParentCategory) ? _selectedParentCategory : null,
              hint: const Text('대분류 선택'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: parentCategories.map((parentName) {
                return DropdownMenuItem<String>(value: parentName, child: Text(parentName));
              }).toList(),
              onChanged: parentCategories.isEmpty ? null : (newParent) {
                setState(() {
                  _selectedParentCategory = newParent;
                  _selectedCategoryId = null;
                  _selectedCategoryName = null;

                  // 💡 대분류가 정기수입이 아니면 스위치 끄기
                  if (newParent == null || !newParent.contains('정기')) {
                    _isRecurring = false;
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            const Text('2. 소분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: childCategories.any((category) => category['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
              hint: const Text('소분류 선택'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: childCategories.map((categoryData) {
                return DropdownMenuItem<String>(
                  value: categoryData['id']?.toString(),
                  child: Text(categoryData['name']?.toString() ?? '이름 없음'),
                );
              }).toList(),
              onChanged: _selectedParentCategory == null || childCategories.isEmpty ? null : (newId) {
                setState(() {
                  _selectedCategoryId = newId;
                  _selectedCategoryName = childCategories.firstWhere((c) => c['id'] == newId)['name'];
                });
              },
            ),
            const SizedBox(height: 24),

            // 💡 대분류가 '정기수입'일 때만 부가 기능 표시!
            if (isRegularIncome) ...[
              const Divider(thickness: 2),
              const Text('부가 기능 연결 (옵션)', style: TextStyle(fontWeight: FontWeight.bold)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('매달 자동으로 기록하기'),
                subtitle: const Text('매월 설정한 날짜에 자동으로 내역이 생성됩니다.'),
                value: _isRecurring,
                onChanged: (bool value) => setState(() => _isRecurring = value),
              ),
              if (_isRecurring)
                Row(
                  children: [
                    const Text('매월 입금일: '),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _payDay,
                      items: List.generate(31, (index) => index + 1).map((int day) {
                        return DropdownMenuItem<int>(value: day, child: Text('$day일'));
                      }).toList(),
                      onChanged: (int? newDay) {
                        if (newDay != null) setState(() => _payDay = newDay);
                      },
                    ),
                  ],
                ),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('입금일: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                OutlinedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  child: const Text('날짜 변경'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(labelText: '메모 (선택)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveIncome,
              child: const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}