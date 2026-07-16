import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../utils/currency_formatter.dart';

class ExpenseInputScreen extends StatefulWidget {
  const ExpenseInputScreen({
    super.key,
  });

  @override
  State<ExpenseInputScreen> createState() {
    return _ExpenseInputScreenState();
  }
}

<<<<<<< HEAD
class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _expenseService = ExpenseService();
  final _categoryService = categoryService();
  final _amountController = TextEditingController(text: '0');
  final _placeController = TextEditingController();
  final _memoController = TextEditingController();
=======
class _ExpenseInputScreenState
    extends State<ExpenseInputScreen> {
  final TextEditingController _amountController =
  TextEditingController();

  final TextEditingController _memoController =
  TextEditingController();

  final ExpenseService _expenseService =
  ExpenseService();
>>>>>>> e6e0e506bf55ff6b93c41c4a8468799914287a69

  DateTime _selectedDate = DateTime.now();

  /// 카테고리 조회 상태
  bool _isLoadingCategories = true;

  /// 지출 저장 상태
  // ==================================================
  // ✅ 수정: 저장 버튼 중복 클릭 방지
  // ==================================================
  bool _isSaving = false;

  /// Firestore에서 불러온 전체 카테고리
  List<Map<String, dynamic>> _allCategories = [];

  /// 선택된 지출 성격
  ExpenseNature _selectedNature =
      ExpenseNature.variable;

  /// 선택된 대분류
  String? _selectedParentCategory;

  /// 선택된 소분류 문서 ID
  String? _selectedCategoryId;

  /// 감정 태그 목록
  final List<String> _emotionTags = [
    '충동적',
    '스트레스',
    '사회적',
    '계획적',
  ];

  /// 선택된 감정 태그
  String? _selectedEmotion;

  /// 할부 여부
  bool _isInstallment = false;

  /// 할부 개월 수
  int _installmentMonths = 3;

  /// 정기 결제 여부
  bool _isRecurring = false;

  /// 여행 지출 여부
  bool _isTravel = false;

  @override
  void initState() {
    super.initState();
    _loadCategoriesFromDB();
  }

  /// Firestore categories 컬렉션 조회
  Future<void> _loadCategoriesFromDB() async {
    try {
      final snapshot = await FirebaseFirestore
          .instance
          .collection('categories')
          .get();

      if (!mounted) {
        return;
      }

      setState(() {
        _allCategories = snapshot.docs.map((document) {
          return <String, dynamic>{
            'id': document.id,
            ...document.data(),
          };
        }).toList();

        _isLoadingCategories = false;
      });
    } catch (error) {
      debugPrint(
        '카테고리 로드 오류: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCategories = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '카테고리를 불러오지 못했습니다.\n$error',
          ),
        ),
      );
    }
  }

  /// 지출 성격 변경
  void _onNatureChanged(
      ExpenseNature newNature,
      ) {
    setState(() {
      _selectedNature = newNature;
      _selectedParentCategory = null;
      _selectedCategoryId = null;

      /// 변동비가 아니면 감정 태그 초기화
      if (newNature != ExpenseNature.variable) {
        _selectedEmotion = null;
      }

      /// 고정비는 여행 태깅 제외
      if (newNature == ExpenseNature.fixed) {
        _isTravel = false;
      }
    });
  }

  /// 지출 저장
  Future<void> _saveExpense() async {
    if (_isSaving) {
      return;
    }

    /// 금액과 소분류 검사
    if (_amountController.text.trim().isEmpty ||
        _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '금액과 소분류 카테고리를 모두 선택해주세요.',
          ),
        ),
      );
      return;
    }

    /// 변동비는 감정 태그 필수
    if (_selectedNature ==
        ExpenseNature.variable &&
        _selectedEmotion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '변동비 지출은 감정 태그를 선택해야 합니다.',
          ),
        ),
      );
      return;
    }

    // ==================================================
    // ✅ 수정 핵심 1:
    // 현재 Firebase 로그인 사용자 가져오기
    // ==================================================
    final User? currentUser =
        FirebaseAuth.instance.currentUser;

    // ==================================================
    // ✅ 수정 핵심 2:
    // 로그인 사용자가 없으면 test_user_id로 저장하지 않고
    // 저장 작업을 중단
    // ==================================================
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '로그인된 사용자가 없습니다.\n'
                '로그인 후 다시 시도해주세요.',
          ),
        ),
      );
      return;
    }

    final amountText = _amountController.text
        .replaceAll(',', '')
        .trim();

    final int? amount =
    int.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '올바른 지출 금액을 입력해주세요.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // ==================================================
      // ✅ 수정 핵심 3:
      // test_user_id가 아니라 실제 로그인 UID 사용
      // ==================================================
      final String userId =
          currentUser.uid;

      /// 화면 스위치 상태에 따른 임시 연결 ID
      final String? tempInstallmentPlanId =
      _isInstallment
          ? 'temp_install_id'
          : null;

      final String? tempRecurringPaymentId =
      _isRecurring
          ? 'temp_recur_id'
          : null;

      final String? tempTravelId =
      _isTravel
          ? 'temp_travel_id'
          : null;

      /// 지출 모델 생성
      final newExpense = ExpenseModel(
        /// Firestore에서 자동 문서 ID 생성
        expenseId: '',

        // ==================================================
        // ✅ 수정 핵심 4:
        // expenses 문서의 userId에 실제 UID가 저장됨
        // ==================================================
        userId: userId,

        amount: amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text.trim(),
        nature: _selectedNature,

        emotionTag:
        _selectedNature ==
            ExpenseNature.variable
            ? _selectedEmotion
            : null,

        installmentPlanId:
        tempInstallmentPlanId,

        recurringPaymentId:
        tempRecurringPaymentId,

        travelId:
        tempTravelId,
      );

      /// expenses 컬렉션에 저장
      final String expenseId =
      await _expenseService.addExpense(
        newExpense,
      );

      debugPrint(
        '================================',
      );

      debugPrint(
        '[지출 저장 완료]',
      );

      debugPrint(
        'expenseId: $expenseId',
      );

      // ==================================================
      // ✅ 수정: 실제 저장된 UID를 콘솔에서 확인
      // ==================================================
      debugPrint(
        'userId: $userId',
      );

      debugPrint(
        'amount: $amount',
      );

      debugPrint(
        'date: $_selectedDate',
      );

      debugPrint(
        'categoryId: $_selectedCategoryId',
      );

      debugPrint(
        '할부 연결: $tempInstallmentPlanId',
      );

      debugPrint(
        '구독 연결: $tempRecurringPaymentId',
      );

      debugPrint(
        '여행 연결: $tempTravelId',
      );

      debugPrint(
        '================================',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '지출 내역이 성공적으로 저장되었습니다.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (error) {
      debugPrint(
        '지출 저장 오류: $error',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '저장 실패: $error',
          ),
          backgroundColor: Colors.red,
        ),
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
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// 선택된 성격과 일치하는 카테고리만 필터링
    final natureFilteredCategories =
    _allCategories.where((category) {
      final dbNature =
      (category['nature'] ?? '')
          .toString()
          .toLowerCase();

      return dbNature.contains(
        _selectedNature.name.toLowerCase(),
      );
    }).toList();

    /// 대분류 목록
    final List<String> parentCategories =
    natureFilteredCategories
        .map(
          (category) =>
          (category['parentName'] ??
              category['parent'] ??
              '미분류')
              .toString(),
    )
        .toSet()
        .toList();

    /// 선택한 대분류에 해당하는 소분류 목록
    final List<Map<String, dynamic>>
    childCategories =
    _selectedParentCategory == null
        ? []
        : natureFilteredCategories.where(
          (category) {
        final parent =
            category['parentName'] ??
                category['parent'] ??
                '미분류';

        return parent ==
            _selectedParentCategory;
      },
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '지출 기록',
        ),
      ),
      body: _isLoadingCategories
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : SingleChildScrollView(
        padding:
        const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            /// 금액 입력
            TextField(
              controller:
              _amountController,
              enabled: !_isSaving,
              keyboardType:
              TextInputType.number,
              inputFormatters: [
                CurrencyFormatter(),
              ],
              style: const TextStyle(
                fontSize: 24,
                fontWeight:
                FontWeight.bold,
              ),
              decoration:
              const InputDecoration(
                labelText: '결제 금액',
                prefixText: '₩ ',
                prefixStyle: TextStyle(
                  fontSize: 24,
                  fontWeight:
                  FontWeight.bold,
                ),
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              '1. 지출 성격',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label:
                  const Text('고정비'),
                  selected:
                  _selectedNature ==
                      ExpenseNature.fixed,
                  onSelected: _isSaving
                      ? null
                      : (_) {
                    _onNatureChanged(
                      ExpenseNature.fixed,
                    );
                  },
                ),
                ChoiceChip(
                  label:
                  const Text('변동비'),
                  selected:
                  _selectedNature ==
                      ExpenseNature.variable,
                  onSelected: _isSaving
                      ? null
                      : (_) {
                    _onNatureChanged(
                      ExpenseNature.variable,
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text(
                    '기타 (경조사 등)',
                  ),
                  selected:
                  _selectedNature ==
                      ExpenseNature.other,
                  onSelected: _isSaving
                      ? null
                      : (_) {
                    _onNatureChanged(
                      ExpenseNature.other,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              '2. 대분류',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: parentCategories.contains(
                _selectedParentCategory,
              )
                  ? _selectedParentCategory
                  : null,
              hint:
              const Text('대분류 선택'),
              decoration:
              const InputDecoration(
                border:
                OutlineInputBorder(),
              ),
              items: parentCategories.map(
                    (parentName) {
                  return DropdownMenuItem<
                      String>(
                    value: parentName,
                    child: Text(
                      parentName,
                    ),
                  );
                },
              ).toList(),
              onChanged:
              _isSaving ||
                  parentCategories
                      .isEmpty
                  ? null
                  : (newParent) {
                setState(() {
                  _selectedParentCategory =
                      newParent;

                  _selectedCategoryId =
                  null;
                });
              },
            ),

            const SizedBox(height: 16),

            const Text(
              '3. 소분류',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              value: childCategories.any(
                    (category) =>
                category['id'] ==
                    _selectedCategoryId,
              )
                  ? _selectedCategoryId
                  : null,
              hint:
              const Text('소분류 선택'),
              decoration:
              const InputDecoration(
                border:
                OutlineInputBorder(),
              ),
              items: childCategories.map(
                    (categoryData) {
                  return DropdownMenuItem<
                      String>(
                    value: categoryData['id']
                        ?.toString(),
                    child: Text(
                      categoryData['name']
                          ?.toString() ??
                          '이름 없음',
                    ),
                  );
                },
              ).toList(),
              onChanged:
              _isSaving ||
                  _selectedParentCategory ==
                      null ||
                  childCategories.isEmpty
                  ? null
                  : (newId) {
                setState(() {
                  _selectedCategoryId =
                      newId;
                });
              },
            ),

            const SizedBox(height: 24),

            /// 변동비 전용 감정 태그
            if (_selectedNature ==
                ExpenseNature.variable) ...[
              const Text(
                '감정 태그',
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                children:
                _emotionTags.map((tag) {
                  return ChoiceChip(
                    label: Text(tag),
                    selected:
                    _selectedEmotion ==
                        tag,
                    onSelected: _isSaving
                        ? null
                        : (selected) {
                      setState(() {
                        _selectedEmotion =
                        selected
                            ? tag
                            : null;
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),
            ],

            const Divider(
              thickness: 2,
            ),

            const Text(
              '부가 기능 연결 (옵션)',
              style: TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),

            /// 할부 선택
            SwitchListTile(
              title: const Text(
                '할부 결제인가요?',
              ),
              subtitle: const Text(
                '무이자 균등금액으로 분할 기록됩니다.',
              ),
              value: _isInstallment,
              onChanged: _isSaving
                  ? null
                  : (value) {
                setState(() {
                  _isInstallment =
                      value;

                  if (value) {
                    _isRecurring =
                    false;
                  }
                });
              },
            ),

            if (_isInstallment)
              Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Text(
                      '할부 개월 수:',
                    ),
                    const SizedBox(
                      width: 16,
                    ),
                    DropdownButton<int>(
                      value:
                      _installmentMonths,
                      items: const [
                        2,
                        3,
                        4,
                        5,
                        6,
                        10,
                        12,
                        24,
                      ].map((value) {
                        return DropdownMenuItem<
                            int>(
                          value: value,
                          child: Text(
                            '$value개월',
                          ),
                        );
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (newValue) {
                        if (newValue ==
                            null) {
                          return;
                        }

                        setState(() {
                          _installmentMonths =
                              newValue;
                        });
                      },
                    ),
                  ],
                ),
              ),

            /// 정기결제 선택
            SwitchListTile(
              title: const Text(
                '매월 반복되는 정기결제/구독인가요?',
              ),
              subtitle: const Text(
                '다음 달부터 자동으로 내역이 생성됩니다.',
              ),
              value: _isRecurring,
              onChanged: _isSaving
                  ? null
                  : (value) {
                setState(() {
                  _isRecurring =
                      value;

                  if (value) {
                    _isInstallment =
                    false;
                  }
                });
              },
            ),

            /// 여행 지출 선택
            SwitchListTile(
              title: const Text(
                '현재 진행 중인 여행 지출인가요?',
              ),
              subtitle: _selectedNature ==
                  ExpenseNature.fixed
                  ? const Text(
                '고정비는 여행 지출로 태깅할 수 없습니다.',
                style: TextStyle(
                  color: Colors.red,
                ),
              )
                  : const Text(
                '진행 중인 여행 예산에 포함됩니다.',
              ),
              value: _isTravel,
              onChanged: _isSaving ||
                  _selectedNature ==
                      ExpenseNature.fixed
                  ? null
                  : (value) {
                setState(() {
                  _isTravel = value;
                });
              },
            ),

            const Divider(
              thickness: 2,
            ),

            const SizedBox(height: 16),

            /// 날짜 선택
            Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
              children: [
                Text(
                  '결제일: '
                      '${_selectedDate.toLocal().toString().split(' ')[0]}',
                ),
                OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                    final picked =
                    await showDatePicker(
                      context: context,
                      initialDate:
                      _selectedDate,
                      firstDate:
                      DateTime(2000),
                      lastDate:
                      DateTime(2100),
                    );

                    if (picked != null &&
                        mounted) {
                      setState(() {
                        _selectedDate =
                            picked;
                      });
                    }
                  },
                  child:
                  const Text('날짜 변경'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// 메모
            TextField(
              controller:
              _memoController,
              enabled: !_isSaving,
              decoration:
              const InputDecoration(
                labelText: '메모 (선택)',
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 32),

            /// 저장 버튼
            ElevatedButton(
              style:
              ElevatedButton.styleFrom(
                padding:
                const EdgeInsets.symmetric(
                  vertical: 16,
                ),
                backgroundColor:
                Colors.blueAccent,
                foregroundColor:
                Colors.white,
              ),
              onPressed:
              _isSaving
                  ? null
                  : _saveExpense,
              child: _isSaving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                '저장하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}