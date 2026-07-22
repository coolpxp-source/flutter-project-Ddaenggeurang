import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/travel_member_model.dart';
import '../../services/travel_expense_service.dart';
import '../../services/travel_member_service.dart';
import 'travel_member_screen.dart';

class TravelExpenseInputScreen extends StatefulWidget {
  const TravelExpenseInputScreen({
    super.key,
    required this.travelId,
  });

  final String travelId;

  @override
  State<TravelExpenseInputScreen> createState() =>
      _TravelExpenseInputScreenState();
}

class _TravelExpenseInputScreenState
    extends State<TravelExpenseInputScreen> {
  final GlobalKey<FormState> _formKey =
  GlobalKey<FormState>();

  final TextEditingController _amountController =
  TextEditingController();

  final TextEditingController _placeController =
  TextEditingController();

  final TextEditingController _memoController =
  TextEditingController();

  final TravelExpenseService _expenseService =
  TravelExpenseService();

  final TravelMemberService _memberService =
  TravelMemberService();

  final List<String> _categories = const <String>[
    '식비',
    '카페',
    '교통',
    '숙박',
    '쇼핑',
    '관광',
    '문화',
    '기타',
  ];

  String _selectedCategory = '식비';
  String? _selectedPayerId;
  String _selectedPayerName = '';

  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _placeController.dispose();
    _memoController.dispose();

    super.dispose();
  }

  /// 현재 로그인 사용자 이름
  String _getCurrentUserName() {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return '나';
    }

    final String displayName =
        user.displayName?.trim() ?? '';

    if (displayName.isNotEmpty) {
      return displayName;
    }

    final String email = user.email?.trim() ?? '';

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return '나';
  }

  /// 참여자 관리 화면 이동
  Future<void> _openMemberScreen() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인 정보가 없습니다.');
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TravelMemberScreen(
          travelId: widget.travelId,
          currentUserId: user.uid,
          currentUserName: _getCurrentUserName(),
        ),
      ),
    );
  }

  Future<void> _selectExpenseDate() async {
    final DateTime? selectedDate =
    await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: '지출 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
    });
  }

  Future<void> _saveExpense() async {
    if (_isSaving) {
      return;
    }

    final bool isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    if (_selectedPayerId == null ||
        _selectedPayerId!.trim().isEmpty) {
      _showMessage('결제자를 선택해 주세요.');
      return;
    }

    final String amountText = _amountController.text
        .replaceAll(',', '')
        .trim();

    final int? amount = int.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage('올바른 금액을 입력해 주세요.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      await _expenseService.createExpense(
        travelId: widget.travelId,
        payerId: _selectedPayerId!,
        payerName: _selectedPayerName,
        amount: amount,
        category: _selectedCategory,
        place: _placeController.text.trim(),
        memo: _memoController.text.trim(),
        expenseDate: _selectedDate,
      );

      if (!mounted) {
        return;
      }

      _showMessage('여행 지출이 저장되었습니다.');

      _resetForm();
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message?.toString() ??
            '입력값을 확인해 주세요.',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();

    _amountController.clear();
    _placeController.clear();
    _memoController.clear();

    setState(() {
      _selectedCategory = '식비';
      _selectedDate = DateTime.now();

      // 결제자는 다음 지출 입력을 위해 유지한다.
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDate(DateTime date) {
    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}년 $month월 $day일';
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildPayerField() {
    return StreamBuilder<List<TravelMemberModel>>(
      stream: _memberService.watchMembers(
        widget.travelId,
      ),
      builder: (
          BuildContext context,
          AsyncSnapshot<List<TravelMemberModel>> snapshot,
          ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 58,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildMemberError();
        }

        final List<TravelMemberModel> members =
            snapshot.data ?? <TravelMemberModel>[];

        if (members.isEmpty) {
          return _buildEmptyMemberCard();
        }

        final bool selectedMemberExists =
        members.any(
              (TravelMemberModel member) =>
          member.memberId == _selectedPayerId,
        );

        final String? dropdownValue =
        selectedMemberExists
            ? _selectedPayerId
            : null;

        return DropdownButtonFormField<String>(
          value: dropdownValue,
          isExpanded: true,
          decoration: _inputDecoration(
            label: '결제자',
            hintText: '결제한 참여자를 선택해 주세요.',
            icon: Icons.person_outline,
          ),
          items: members.map(
                (TravelMemberModel member) {
              return DropdownMenuItem<String>(
                value: member.memberId,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (member.isOwner)
                      Container(
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '여행 생성자',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              );
            },
          ).toList(),
          validator: (String? value) {
            if (value == null || value.isEmpty) {
              return '결제자를 선택해 주세요.';
            }

            return null;
          },
          onChanged: _isSaving
              ? null
              : (String? memberId) {
            if (memberId == null) {
              return;
            }

            final TravelMemberModel member =
            members.firstWhere(
                  (TravelMemberModel member) =>
              member.memberId == memberId,
            );

            setState(() {
              _selectedPayerId = member.memberId;
              _selectedPayerName =
                  member.displayName;
            });
          },
        );
      },
    );
  }

  Widget _buildEmptyMemberCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(
          color: Colors.orange.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.group_off_outlined,
                color: Colors.orange.shade800,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '결제자를 선택하려면 여행 참여자를 '
                      '먼저 등록해야 합니다.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
              _isSaving ? null : _openMemberScreen,
              icon: const Icon(
                Icons.person_add_outlined,
              ),
              label: const Text('참여자 등록하기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(
          color: Colors.red.shade200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: <Widget>[
          Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '참여자 목록을 불러오지 못했습니다.',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          '여행 지출 입력',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed:
            _isSaving ? null : _openMemberScreen,
            tooltip: '여행 참여자 관리',
            icon: const Icon(
              Icons.groups_outlined,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                        colorScheme.primary,
                        child: Icon(
                          Icons.flight_takeoff_rounded,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '여행 모드 진행 중',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight:
                                FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '사용한 여행 경비를 기록해 주세요.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '지출 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                _buildPayerField(),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters:
                  <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: _inputDecoration(
                    label: '지출 금액',
                    hintText: '예: 15000',
                    suffixText: '원',
                    icon: Icons.payments_outlined,
                  ),
                  validator: (String? value) {
                    final String amountText =
                        value?.trim() ?? '';

                    if (amountText.isEmpty) {
                      return '지출 금액을 입력해 주세요.';
                    }

                    final int? amount =
                    int.tryParse(amountText);

                    if (amount == null || amount <= 0) {
                      return '0원보다 큰 금액을 입력해 주세요.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _inputDecoration(
                    label: '카테고리',
                    icon: Icons.category_outlined,
                  ),
                  items: _categories.map(
                        (String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    },
                  ).toList(),
                  onChanged: _isSaving
                      ? null
                      : (String? value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _placeController,
                  textInputAction: TextInputAction.next,
                  maxLength: 50,
                  decoration: _inputDecoration(
                    label: '사용사용처',
                    hintText: '예: 식당, 카페, 관광지',
                    icon: Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(height: 4),

                TextFormField(
                  controller: _memoController,
                  keyboardType: TextInputType.multiline,
                  textInputAction:
                  TextInputAction.newline,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 200,
                  decoration: _inputDecoration(
                    label: '메모',
                    hintText:
                    '지출 내용을 간단히 입력해 주세요.',
                    icon: Icons.edit_note_outlined,
                  ),
                ),
                const SizedBox(height: 4),

                InkWell(
                  onTap: _isSaving
                      ? null
                      : _selectExpenseDate,
                  borderRadius:
                  BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      label: '지출 날짜',
                      icon:
                      Icons.calendar_month_outlined,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _formatDate(_selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSaving
                        ? null
                        : _saveExpense,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    )
                        : const Icon(
                      Icons.save_outlined,
                    ),
                    label: Text(
                      _isSaving
                          ? '저장 중...'
                          : '지출 저장',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}