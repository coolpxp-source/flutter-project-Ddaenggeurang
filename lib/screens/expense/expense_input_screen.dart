import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/expense_model.dart';
import '../../services/category_service.dart';
import '../../services/expense_service.dart';
import '../../utils/formatters.dart';
import '../../models/transaction_item.dart';

class ExpenseInputScreen extends StatefulWidget {
  final TransactionItem? editItem;
  const ExpenseInputScreen({super.key, this.editItem});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _expenseService = ExpenseService();
  final _amountController = TextEditingController(text: '0');
  final _memoController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingCategories = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _allCategories = [];

  ExpenseNature _selectedNature = ExpenseNature.variable;
  String? _selectedParentCategory;
  String? _selectedCategoryId;

  final List<String> _emotionTags = ['충동적', '스트레스', '사회적', '계획적'];
  String? _selectedEmotion;

  bool _isInstallment = false;
  int _installmentMonths = 3;
  bool _isRecurring = false;
  bool _isTravel = false;

  @override
  void initState() {
    super.initState();

    if (widget.editItem != null) {
      final item = widget.editItem!;
      _amountController.text = item.amount.toString();
      _selectedDate = item.date;
      if (item.subtitle != null) _memoController.text = item.subtitle!;
      _selectedEmotion = item.emotionTag;
    }

    _loadCategoriesFromDB().then((_) {
      if (widget.editItem != null) {
        _fetchOriginalExpense(widget.editItem!.id);
      }
    });
  }

  Future<void> _fetchOriginalExpense(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('expenses').doc(docId).get();
      if (doc.exists && mounted) {
        final originalExpense = ExpenseModel.fromFirestore(doc);
        setState(() {
          _selectedNature = originalExpense.nature;
          _selectedCategoryId = originalExpense.categoryId;
          try {
            final matchedCategory = _allCategories.firstWhere((cat) => cat['id'] == originalExpense.categoryId);
            _selectedParentCategory = matchedCategory['parentName']?.toString() ?? matchedCategory['parent']?.toString();
          } catch (e) {
            debugPrint('카테고리 매칭 실패: $e');
          }
          _isInstallment = originalExpense.installmentPlanId != null;
          _isRecurring = originalExpense.recurringPaymentId != null;
          _isTravel = originalExpense.travelId != null;
        });
      }
    } catch (e) {
      debugPrint('원본 지출 내역 로드 실패: $e');
    }
  }

  // 💡 복합 색인 에러 방지를 위해 메모리 필터링 방식으로 개선
  Future<void> _loadCategoriesFromDB() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap = await db.collection('categories').where('transactionType', isEqualTo: 'expense').get();
      // 에러의 주범이었던 where 체이닝 제거 -> 클라이언트(앱)에서 필터링
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
        // 앱에서 직접 expense 타입만 골라냅니다.
        if (data['transactionType'] == 'expense' && data['isHidden'] != true) {
          loaded.add({'id': doc.id, ...data});
        }
      }

      if (!mounted) return;
      setState(() {
        _allCategories = loaded;
        _isLoadingCategories = false;
      });
    } catch (error) {
      debugPrint('카테고리 로드 오류: $error');
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
    }
  }

  void _onNatureChanged(ExpenseNature newNature) {
    setState(() {
      _selectedNature = newNature;
      _selectedParentCategory = null;
      _selectedCategoryId = null;

      if (newNature != ExpenseNature.variable) _selectedEmotion = null;
      if (newNature == ExpenseNature.fixed) _isTravel = false;
    });
  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;
    if (_amountController.text.trim().isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('금액과 소분류 카테고리를 모두 선택해주세요.')));
      return;
    }
    if (_selectedNature == ExpenseNature.variable && _selectedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('변동비 지출은 감정 태그를 선택해야 합니다.')));
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그인된 사용자가 없습니다.\n로그인 후 다시 시도해주세요.')));
      return;
    }

    final amountText = _amountController.text.replaceAll(',', '').trim();
    final int? amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('올바른 지출 금액을 입력해주세요.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String userId = currentUser.uid;
      final newExpense = ExpenseModel(
        expenseId: widget.editItem != null ? widget.editItem!.id : '',
        userId: userId,
        amount: amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text.trim(),
        nature: _selectedNature,
        emotionTag: _selectedNature == ExpenseNature.variable ? _selectedEmotion : null,
        installmentPlanId: _isInstallment ? 'temp_install_id' : null,
        recurringPaymentId: _isRecurring ? 'temp_recur_id' : null,
        travelId: _isTravel ? 'temp_travel_id' : null,
      );

      if (widget.editItem == null) {
        await _expenseService.addExpense(newExpense);
      } else {
        await _expenseService.updateExpense(widget.editItem!.id, newExpense.toFirestore());
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지출 내역이 성공적으로 저장되었습니다.')));
      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('지출 저장 오류: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $error'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final natureFilteredCategories = _allCategories.where((category) {
      // 💡 커스텀 카테고리도 성격(nature)에 맞게 잘 뜨도록 보강
      String dbNature = (category['nature'] ?? 'variable').toString().toLowerCase();
      if (dbNature.isEmpty || dbNature == 'null') dbNature = 'variable';
      return dbNature.contains(_selectedNature.name.toLowerCase());
    }).toList();

    final List<String> parentCategories = natureFilteredCategories
        .map((category) => (category['parentName'] ?? category['parent'] ?? '미분류').toString())
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : natureFilteredCategories.where((category) {
      final parent = category['parentName'] ?? category['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.editItem == null ? '지출 기록' : '지출 수정')),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountController,
              enabled: !_isSaving,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: '결제 금액',
                prefixText: '₩ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            const Text('1. 지출 성격', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('고정비'),
                  selected: _selectedNature == ExpenseNature.fixed,
                  onSelected: _isSaving ? null : (_) => _onNatureChanged(ExpenseNature.fixed),
                ),
                ChoiceChip(
                  label: const Text('변동비'),
                  selected: _selectedNature == ExpenseNature.variable,
                  onSelected: _isSaving ? null : (_) => _onNatureChanged(ExpenseNature.variable),
                ),
                ChoiceChip(
                  label: const Text('기타 (경조사 등)'),
                  selected: _selectedNature == ExpenseNature.other,
                  onSelected: _isSaving ? null : (_) => _onNatureChanged(ExpenseNature.other),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text('2. 대분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: parentCategories.contains(_selectedParentCategory) ? _selectedParentCategory : null,
              hint: const Text('대분류 선택'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: parentCategories.map((parentName) {
                return DropdownMenuItem<String>(value: parentName, child: Text(parentName));
              }).toList(),
              onChanged: _isSaving || parentCategories.isEmpty ? null : (newParent) {
                setState(() {
                  _selectedParentCategory = newParent;
                  _selectedCategoryId = null;
                });
              },
            ),
            const SizedBox(height: 16),

            const Text('3. 소분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
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
              onChanged: _isSaving || _selectedParentCategory == null || childCategories.isEmpty ? null : (newId) {
                setState(() => _selectedCategoryId = newId);
              },
            ),
            const SizedBox(height: 24),

            if (_selectedNature == ExpenseNature.variable) ...[
              const Text('감정 태그', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _emotionTags.map((tag) {
                  return ChoiceChip(
                    label: Text(tag),
                    selected: _selectedEmotion == tag,
                    onSelected: _isSaving ? null : (selected) {
                      setState(() => _selectedEmotion = selected ? tag : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            const Divider(thickness: 2),
            const Text('부가 기능 연결 (옵션)', style: TextStyle(fontWeight: FontWeight.bold)),

            SwitchListTile(
              title: const Text('할부 결제인가요?'),
              subtitle: const Text('무이자 균등금액으로 분할 기록됩니다.'),
              value: _isInstallment,
              onChanged: _isSaving ? null : (value) {
                setState(() {
                  _isInstallment = value;
                  if (value) _isRecurring = false;
                });
              },
            ),
            if (_isInstallment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Text('할부 개월 수:'),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _installmentMonths,
                      items: const [2, 3, 4, 5, 6, 10, 12, 24].map((value) {
                        return DropdownMenuItem<int>(value: value, child: Text('$value개월'));
                      }).toList(),
                      onChanged: _isSaving ? null : (newValue) {
                        if (newValue != null) setState(() => _installmentMonths = newValue);
                      },
                    ),
                  ],
                ),
              ),

            SwitchListTile(
              title: const Text('매월 반복되는 정기결제/구독인가요?'),
              subtitle: _isTravel
                  ? const Text('여행 지출은 정기결제로 설정할 수 없습니다.', style: TextStyle(color: Colors.red))
                  : const Text('다음 달부터 자동으로 내역이 생성됩니다.'),
              value: _isRecurring,
              onChanged: _isSaving || _isTravel ? null : (value) {
                setState(() {
                  _isRecurring = value;
                  if (value) _isInstallment = false;
                });
              },
            ),

            SwitchListTile(
              title: const Text('현재 진행 중인 여행 지출인가요?'),
              subtitle: _isRecurring
                  ? const Text('정기결제는 여행 지출로 설정할 수 없습니다.', style: TextStyle(color: Colors.red))
                  : (_selectedNature == ExpenseNature.fixed
                  ? const Text('고정비는 여행 지출로 태깅할 수 없습니다.', style: TextStyle(color: Colors.red))
                  : const Text('진행 중인 여행 예산에 포함됩니다.')),
              value: _isTravel,
              onChanged: _isSaving || _isRecurring || _selectedNature == ExpenseNature.fixed ? null : (value) {
                setState(() {
                  _isTravel = value;
                  if (value) _isRecurring = false;
                });
              },
            ),

            const Divider(thickness: 2),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('결제일: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                OutlinedButton(
                  onPressed: _isSaving ? null : () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && mounted) setState(() => _selectedDate = picked);
                  },
                  child: const Text('날짜 변경'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _memoController,
              enabled: !_isSaving,
              decoration: const InputDecoration(labelText: '메모 (선택)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : _saveExpense,
              child: _isSaving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}