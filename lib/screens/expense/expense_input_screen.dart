import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatter 사용
import '../../utils/currency_formatter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';

class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({super.key});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final ExpenseService _expenseService = ExpenseService();

  DateTime _selectedDate = DateTime.now();

  // DB 카테고리 로드 상태
  bool _isLoadingCategories = true;
  List<Map<String, dynamic>> _allCategories = [];

  // 선택 상태 관리
  ExpenseNature _selectedNature = ExpenseNature.variable;
  String? _selectedParentCategory;
  String? _selectedCategoryId;

  // 감정 태그
  final List<String> _emotionTags = ['충동적', '스트레스', '사회적', '계획적'];
  String? _selectedEmotion;

  // 🚀 부가 자동화 3종 상태 변수 (참조 필드용)
  bool _isInstallment = false; // 할부 여부
  int _installmentMonths = 3;  // 할부 개월 수 (기본 3개월)

  bool _isRecurring = false; // 정기결제/구독 여부
  bool _isTravel = false; // 여행 여부

  @override
  void initState() {
    super.initState();
    _loadCategoriesFromDB();
  }

  Future<void> _loadCategoriesFromDB() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categories').get();
      if (mounted) {
        setState(() {
          _allCategories = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      print('카테고리 로드 에러: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  void _onNatureChanged(ExpenseNature newNature) {
    setState(() {
      _selectedNature = newNature;
      _selectedParentCategory = null;
      _selectedCategoryId = null;

      if (newNature != ExpenseNature.variable) {
        _selectedEmotion = null;
      }

      // 명세서 규칙: nature=fixed일 때 여행 태깅 제외
      if (newNature == ExpenseNature.fixed) {
        _isTravel = false;
      }
    });
  }

  Future<void> _saveExpense() async {
    // 1. 기본 필수값 검사
    if (_amountController.text.isEmpty || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액과 소분류 카테고리를 모두 선택해주세요!')),
      );
      return;
    }

    // 2. 감정 태그 방어 로직 (변동비일 경우 필수)
    if (_selectedNature == ExpenseNature.variable && _selectedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('변동비 지출입니다. 감정 태그(🔥/😩/🤝/📝)를 반드시 선택해주세요!')),
      );
      return;
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
      final int amount = int.parse(_amountController.text.replaceAll(',', ''));

      // 💡 임시로 자동화 연결 ID 생성 (화면의 스위치 값에 따라 할당)
      final String? tempInstallmentPlanId = _isInstallment ? 'temp_install_id' : null;
      final String? tempRecurringPaymentId = _isRecurring ? 'temp_recur_id' : null;
      final String? tempTravelId = _isTravel ? 'temp_travel_id' : null;

      // ExpenseModel 생성 (모델에 정의된 정확한 파라미터명 사용)
      final newExpense = ExpenseModel(
        expenseId: '', // 파이어스토어에서 자동 생성되도록 비워둠
        userId: userId,
        amount: amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text,
        nature: _selectedNature,
        emotionTag: _selectedNature == ExpenseNature.variable ? _selectedEmotion : null,

        // 👇 모델에 정의된 변수명으로 매핑!
        installmentPlanId: tempInstallmentPlanId,
        recurringPaymentId: tempRecurringPaymentId,
        travelId: tempTravelId,
      );

      // _expenseService.dart 안에 있는 실제 저장 함수 이름에 맞춰서 주석을 풀고 사용하세요!
      await _expenseService.addExpense(newExpense);

      print('✅ 저장 시도 완료: 금액=$amount, 성격=${_selectedNature.label}');
      print('🔗 연결 ID: 할부=$tempInstallmentPlanId, 구독=$tempRecurringPaymentId, 여행=$tempTravelId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지출 내역이 성공적으로 저장되었습니다!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('🔥 저장 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
    final natureFilteredCategories = _allCategories.where((c) {
      final dbNature = (c['nature'] ?? '').toString().toLowerCase();
      return dbNature.contains(_selectedNature.name.toLowerCase());
    }).toList();

    final List<String> parentCategories = natureFilteredCategories
        .map((c) => (c['parentName'] ?? c['parent'] ?? '미분류') as String)
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : natureFilteredCategories.where((c) {
      final parent = c['parentName'] ?? c['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('지출 기록')),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 금액 입력 (원화 표시 & 천 단위 콤마)
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()], // 콤마 포매터 적용
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: '결제 금액',
                prefixText: '₩ ', // 원화 기호 추가
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 지출 성격 (Nature)
            const Text('1. 지출 성격', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: [
                ChoiceChip(
                  label: const Text('고정비'),
                  selected: _selectedNature == ExpenseNature.fixed,
                  onSelected: (val) => _onNatureChanged(ExpenseNature.fixed),
                ),
                ChoiceChip(
                  label: const Text('변동비'),
                  selected: _selectedNature == ExpenseNature.variable,
                  onSelected: (val) => _onNatureChanged(ExpenseNature.variable),
                ),
                ChoiceChip(
                  label: const Text('기타 (경조사 등)'),
                  selected: _selectedNature == ExpenseNature.other,
                  onSelected: (val) => _onNatureChanged(ExpenseNature.other),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 3. 대분류 드롭다운
            const Text('2. 대분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: parentCategories.contains(_selectedParentCategory) ? _selectedParentCategory : null,
              hint: const Text('대분류 선택'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: parentCategories.isEmpty
                  ? [const DropdownMenuItem(value: null, child: Text('해당 성격의 카테고리가 없습니다'))]
                  : parentCategories.map((String parentName) {
                return DropdownMenuItem<String>(
                  value: parentName,
                  child: Text(parentName),
                );
              }).toList(),
              onChanged: parentCategories.isEmpty ? null : (String? newParent) {
                setState(() {
                  _selectedParentCategory = newParent;
                  _selectedCategoryId = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // 4. 소분류 드롭다운
            const Text('3. 소분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: childCategories.any((c) => c['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
              hint: const Text('소분류 선택'),
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _selectedParentCategory == null
                  ? [const DropdownMenuItem(value: null, child: Text('먼저 대분류를 선택하세요'))]
                  : childCategories.isEmpty
                  ? [const DropdownMenuItem(value: null, child: Text('소분류가 없습니다'))]
                  : childCategories.map((categoryData) {
                return DropdownMenuItem<String>(
                  value: categoryData['id'],
                  child: Text(categoryData['name']),
                );
              }).toList(),
              onChanged: _selectedParentCategory == null || childCategories.isEmpty
                  ? null
                  : (String? newId) {
                setState(() {
                  _selectedCategoryId = newId;
                });
              },
            ),
            const SizedBox(height: 24),

            // 5. 변동비 전용 감정 태그
            if (_selectedNature == ExpenseNature.variable) ...[
              const Text('감정 태그', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                children: _emotionTags.map((tag) {
                  return ChoiceChip(
                    label: Text(tag),
                    selected: _selectedEmotion == tag,
                    onSelected: (bool selected) {
                      setState(() {
                        _selectedEmotion = selected ? tag : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // 6. 🚀 부가 자동화 3종 연결 (할부, 구독, 여행)
            const Divider(thickness: 2),
            const Text('부가 기능 연결 (옵션)', style: TextStyle(fontWeight: FontWeight.bold)),

            // 6-1. 할부
            SwitchListTile(
              title: const Text('할부 결제인가요?'),
              subtitle: const Text('무이자 균등금액으로 분할 기록됩니다.'),
              value: _isInstallment,
              onChanged: (bool value) {
                setState(() {
                  _isInstallment = value;
                  if (value) _isRecurring = false; // 할부와 구독은 보통 겹치지 않음
                });
              },
            ),
            if (_isInstallment)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    const Text('할부 개월 수: '),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _installmentMonths,
                      items: [2, 3, 4, 5, 6, 10, 12, 24].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value개월'),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          setState(() => _installmentMonths = newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),

            // 6-2. 정기결제(구독)
            SwitchListTile(
              title: const Text('매월 반복되는 정기결제/구독인가요?'),
              subtitle: const Text('다음 달부터 자동으로 내역이 생성됩니다.'),
              value: _isRecurring,
              onChanged: (bool value) {
                setState(() {
                  _isRecurring = value;
                  if (value) _isInstallment = false;
                });
              },
            ),

            // 6-3. 여행 (고정비일 때는 비활성화)
            SwitchListTile(
              title: const Text('현재 진행 중인 여행 지출인가요?'),
              subtitle: _selectedNature == ExpenseNature.fixed
                  ? const Text('고정비는 여행 지출로 태깅할 수 없습니다.', style: TextStyle(color: Colors.red))
                  : const Text('진행 중인 여행 예산에 포함됩니다.'),
              value: _isTravel,
              onChanged: _selectedNature == ExpenseNature.fixed
                  ? null // 고정비면 클릭 불가
                  : (bool value) {
                setState(() => _isTravel = value);
              },
            ),
            const Divider(thickness: 2),
            const SizedBox(height: 16),

            // 7. 날짜 및 메모
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('결제일: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                OutlinedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: const Text('날짜 변경'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // 8. 저장 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveExpense,
              child: const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}