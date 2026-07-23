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
  // 앱 공통 블루 테마 컬러
  static const Color _mainColor = Color(0xFF4F7DF3);
  static const Color _mainSoftColor = Color(0xFFE8EFFE);

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

  /// 앱 블루 테마를 적용한 날짜 선택 다이얼로그
  ///
  /// travel_mode_start_screen과 동일한 테마 규칙을 사용
  Future<void> _selectExpenseDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: '지출 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _mainColor,
              onPrimary: Colors.white,
              onSurface: Color(0xFF222222),
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: _mainColor,
              headerForegroundColor: Colors.white,
              dayForegroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  if (states.contains(WidgetState.disabled)) {
                    return const Color(0xFFCCCCCC);
                  }
                  return const Color(0xFF222222);
                },
              ),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return _mainColor;
                  }
                  return null;
                },
              ),
              todayForegroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return _mainColor;
                },
              ),
              todayBackgroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return _mainColor;
                  }
                  return null;
                },
              ),
              todayBorder: const BorderSide(color: _mainColor),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _mainColor,
              ),
            ),
          ),
          child: child!,
        );
      },
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

  /// 공통 입력창 디자인 (travel_mode_start_screen과 동일한 톤)
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: _mainColor,
      ),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE6E3E7),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE6E3E7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _mainColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  /// 입력 영역 제목 (아이콘 + 텍스트)
  Widget _buildSectionTitle(
      String title, {
        required IconData icon,
      }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: _mainColor,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// 화면 상단 안내 카드
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: _mainSoftColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.flight_takeoff_rounded,
              color: _mainColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '여행 모드 진행 중',
                  style: TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '사용한 여행 경비를 기록해 주세요.',
                  style: TextStyle(
                    color: Color(0xFF4C5B7A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              child: CircularProgressIndicator(
                color: _mainColor,
              ),
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

        if (!selectedMemberExists) {
          _selectedPayerId = null;
        }

        return FormField<String>(
          initialValue: _selectedPayerId,
          validator: (String? value) {
            if (_selectedPayerId == null ||
                _selectedPayerId!.isEmpty) {
              return '결제자를 선택해 주세요.';
            }

            return null;
          },
          builder: (FormFieldState<String> field) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectorCard(
                  icon: Icons.person_outline_rounded,
                  label: _selectedPayerName.isEmpty
                      ? '결제한 참여자를 선택해 주세요.'
                      : _selectedPayerName,
                  isPlaceholder: _selectedPayerName.isEmpty,
                  hasError: field.hasError,
                  onTap: _isSaving
                      ? null
                      : () => _openPayerSheet(members),
                ),
                if (field.hasError) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      field.errorText ?? '',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  /// 결제자 선택 바텀시트 (화이트 배경, 필드와 같은 너비)
  Future<void> _openPayerSheet(
      List<TravelMemberModel> members,
      ) async {
    final String? selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(context).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding:
                    EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Text(
                      '결제자 선택',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: members.map(
                            (TravelMemberModel member) {
                          final bool isSelected =
                              member.memberId ==
                                  _selectedPayerId;

                          return ListTile(
                            onTap: () => Navigator.pop(
                              context,
                              member.memberId,
                            ),
                            title: Text(
                              member.displayName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? _mainColor
                                    : const Color(
                                  0xFF333333,
                                ),
                              ),
                            ),
                            trailing: member.isOwner
                                ? Container(
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _mainSoftColor,
                                borderRadius:
                                BorderRadius.circular(
                                  12,
                                ),
                              ),
                              child: const Text(
                                '여행 생성자',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                  FontWeight.w700,
                                  color: _mainColor,
                                ),
                              ),
                            )
                                : (isSelected
                                ? const Icon(
                              Icons.check_rounded,
                              color: _mainColor,
                            )
                                : null),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selectedId == null) {
      return;
    }

    final TravelMemberModel member = members.firstWhere(
          (TravelMemberModel member) =>
      member.memberId == selectedId,
    );

    setState(() {
      _selectedPayerId = member.memberId;
      _selectedPayerName = member.displayName;
    });
  }

  /// 결제자/카테고리 등 선택형 필드 공통 카드 (드롭다운 대신 사용)
  Widget _buildSelectorCard({
    required IconData icon,
    required String label,
    required bool isPlaceholder,
    required VoidCallback? onTap,
    bool hasError = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? Colors.redAccent
                  : const Color(0xFFE6E3E7),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: _mainColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isPlaceholder
                        ? const Color(0xFFAAAAAA)
                        : const Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: isPlaceholder
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 카테고리 선택 바텀시트 (화이트 배경, 필드와 같은 너비)
  Future<void> _openCategorySheet() async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
              MediaQuery.of(context).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding:
                    EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Text(
                      '카테고리 선택',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222222),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: _categories.map(
                            (String category) {
                          final bool isSelected =
                              category == _selectedCategory;

                          return ListTile(
                            onTap: () => Navigator.pop(
                              context,
                              category,
                            ),
                            title: Text(
                              category,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? _mainColor
                                    : const Color(
                                  0xFF333333,
                                ),
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                              Icons.check_rounded,
                              color: _mainColor,
                            )
                                : null,
                          );
                        },
                      ).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _selectedCategory = selected;
    });
  }

  Widget _buildEmptyMemberCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6E3E7),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3DE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_off_rounded,
                  color: Color(0xFFC98A00),
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '결제자를 선택하려면 여행 참여자를 '
                      '먼저 등록해야 합니다.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF555555),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed:
              _isSaving ? null : _openMemberScreen,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 18,
                color: _mainColor,
              ),
              label: const Text(
                '참여자 등록하기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _mainColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(
                  color: _mainColor,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
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
        color: const Color(0xFFFFEDEC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFE0483C),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '참여자 목록을 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8A2E26),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 지출 날짜 선택 버튼 (travel_mode_start_screen의 날짜 버튼과 동일한 톤)
  Widget _buildDateField() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isSaving ? null : _selectExpenseDate,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE6E3E7),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: _mainColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 지출 저장 버튼 (travel_mode_start_screen의 시작 버튼과 동일한 톤)
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveExpense,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _mainColor,
          disabledBackgroundColor: const Color(0xFFAEC5F7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
          width: 23,
          height: 23,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white,
          ),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_rounded, size: 18),
            SizedBox(width: 8),
            Text(
              '지출 저장',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 앱바 우측 참여자 등록/관리 알약 버튼 (마켓 바로가기 칩과 동일한 톤)
  ///
  /// 참여자가 아직 없으면 "참여자 등록하기", 있으면 "참여자 관리"로 문구 전환
  Widget _buildMemberShortcutChip() {
    return StreamBuilder<List<TravelMemberModel>>(
      stream: _memberService.watchMembers(widget.travelId),
      builder: (
          BuildContext context,
          AsyncSnapshot<List<TravelMemberModel>> snapshot,
          ) {
        final List<TravelMemberModel> members =
            snapshot.data ?? <TravelMemberModel>[];

        final bool hasMembers = members.isNotEmpty;

        final String label =
        hasMembers ? '참여자 관리' : '참여자 등록하기';

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSaving ? null : _openMemberScreen,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: _mainColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasMembers
                        ? Icons.groups_rounded
                        : Icons.person_add_alt_1_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text(
          '여행 지출 입력',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: <Widget>[
          _buildMemberShortcutChip(),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 26),

              _buildSectionTitle(
                '결제자',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 10),
              _buildPayerField(),
              const SizedBox(height: 24),

              _buildSectionTitle(
                '지출 금액',
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: _inputDecoration(
                  hintText: '예: 15000',
                  suffixText: '원',
                  prefixIcon: Icons.payments_rounded,
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
              const SizedBox(height: 24),

              _buildSectionTitle(
                '카테고리',
                icon: Icons.category_rounded,
              ),
              const SizedBox(height: 10),
              _buildSelectorCard(
                icon: Icons.category_rounded,
                label: _selectedCategory,
                isPlaceholder: false,
                onTap: _isSaving ? null : _openCategorySheet,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(
                '사용처',
                icon: Icons.storefront_rounded,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _placeController,
                textInputAction: TextInputAction.next,
                maxLength: 50,
                decoration: _inputDecoration(
                  hintText: '예: 식당, 카페, 관광지',
                  prefixIcon: Icons.storefront_rounded,
                ).copyWith(
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(
                '메모',
                icon: Icons.edit_note_rounded,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _memoController,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                minLines: 3,
                maxLines: 5,
                maxLength: 200,
                decoration: _inputDecoration(
                  hintText: '지출 내용을 간단히 입력해 주세요.',
                  prefixIcon: Icons.edit_note_rounded,
                ).copyWith(
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(
                '지출 날짜',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 10),
              _buildDateField(),
              const SizedBox(height: 30),

              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }
}