import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/formatters.dart';
import '../../models/saving_model.dart';
import '../../services/saving_service.dart';

class SavingInputScreen extends StatefulWidget {
  const SavingInputScreen({super.key});

  @override
  State<SavingInputScreen> createState() => _SavingInputScreenState();
}

class _SavingInputScreenState extends State<SavingInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _brokerageController = TextEditingController();
  final TextEditingController _assetNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  final SavingService _savingService = SavingService();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _savingCategories = [];
  bool _isLoadingCategories = true;

  String? _selectedParentCategory;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      setState(() => _currentAmount = int.tryParse(text) ?? 0);
    });
  }

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

  Future<void> _loadCategories() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap = await db.collection('categories').where('transactionType', isEqualTo: 'saving').get();
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
        if (data['transactionType'] == 'saving' && data['isHidden'] != true) {
          loaded.add({'id': doc.id, ...data});
        }
      }

      setState(() {
        _savingCategories = loaded;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('카테고리 로드 에러: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _saveSaving() async {
    if (_currentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저축/투자 금액을 입력해주세요!')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('소분류 카테고리를 선택해주세요!')));
      return;
    }

    if (_selectedCategoryName == '투자' || _selectedCategoryName == '주식') {
      if (_brokerageController.text.isEmpty || _assetNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('증권사명과 종목명을 모두 입력해주세요!')));
        return;
      }
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

      InvestmentDetail? investmentDetail;
      if (_selectedCategoryName == '투자' || _selectedCategoryName == '주식') {
        investmentDetail = InvestmentDetail(
          brokerage: _brokerageController.text,
          assetName: _assetNameController.text,
          quantity: num.tryParse(_quantityController.text),
        );
      }

      final newSaving = SavingModel(
        savingId: '',
        userId: userId,
        date: _selectedDate,
        categoryId: _selectedCategoryId!,
        accountName: _accountNameController.text.isNotEmpty ? _accountNameController.text : null,
        amount: _currentAmount,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        investmentDetail: investmentDetail,
      );

      await _savingService.addSaving(newSaving);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('성공적으로 기록되었습니다!')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('🔥 저장 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> parentCategories = _savingCategories
        .map((category) => (category['parentName'] ?? category['parent'] ?? '미분류').toString())
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : _savingCategories.where((category) {
      final parent = category['parentName'] ?? category['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('저축 / 투자 기록')),
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
                labelText: '이체 / 매수 금액',
                prefixText: '₩ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
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

            const Text('3. 계좌 정보', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                labelText: '계좌명 (선택) - 예: 국민은행 청년희망적금',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            if (_selectedCategoryName == '투자' || _selectedCategoryName == '주식') ...[
              const Divider(thickness: 2),
              const Text('투자 상세 정보', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brokerageController,
                      decoration: const InputDecoration(
                        labelText: '증권사명 (필수)',
                        hintText: '예: 토스증권',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '매수 수량 (선택)',
                        hintText: '예: 2.5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _assetNameController,
                decoration: const InputDecoration(
                  labelText: '종목명 (필수)',
                  hintText: '예: S&P500 ETF',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 2),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('기록일: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
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
              onPressed: _saveSaving,
              child: const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}