import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/travel_model.dart';
import '../../services/travel_service.dart';
import 'travel_expense_input_screen.dart';

class TravelModeStartScreen extends StatefulWidget {
  const TravelModeStartScreen({
    super.key,
  });

  @override
  State<TravelModeStartScreen> createState() =>
      _TravelModeStartScreenState();
}

class _TravelModeStartScreenState extends State<TravelModeStartScreen> {
  // 입력값 유효성 검사용 FormKey
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 여행 이름 입력 컨트롤러
  final TextEditingController _titleController =
  TextEditingController();

  // 여행 예산 입력 컨트롤러
  final TextEditingController _budgetController =
  TextEditingController();

  // 여행 정보 Firestore 저장 서비스
  final TravelService _travelService = TravelService();

  // 여행 시작일
  DateTime? _startDate;

  // 여행 종료일
  DateTime? _endDate;

  // 저장 버튼 중복 클릭 방지
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  /// 앱 블루 테마를 적용한 날짜 선택 다이얼로그 공통 호출
  Future<DateTime?> _pickDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    required String helpText,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
      cancelText: '취소',
      confirmText: '선택',
      builder: (BuildContext context, Widget? child) {
        // 기본 다이얼로그 레이아웃은 유지하되
        // 색상만 앱 메인 컬러(블루)로 테마 적용
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4F7DF3),
              onPrimary: Colors.white,
              onSurface: Color(0xFF222222),
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: const Color(0xFF4F7DF3),
              headerForegroundColor: Colors.white,
              // 선택된 날짜(오늘 포함)는 파란 배경 + 흰 글씨,
              // 선택되지 않은 오늘 날짜는 파란 글씨로 구분
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
                    return const Color(0xFF4F7DF3);
                  }
                  return null;
                },
              ),
              todayForegroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return const Color(0xFF4F7DF3);
                },
              ),
              todayBackgroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF4F7DF3);
                  }
                  return null;
                },
              ),
              todayBorder: const BorderSide(
                color: Color(0xFF4F7DF3),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4F7DF3),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  /// 여행 시작일 선택
  Future<void> _selectStartDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await _pickDate(
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '여행 시작일 선택',
    );

    // 날짜를 선택하지 않고 창을 닫은 경우
    if (selectedDate == null) {
      return;
    }

    setState(() {
      // 시간 정보를 제외한 날짜만 저장
      _startDate = _dateOnly(selectedDate);

      // 종료일이 새 시작일보다 빠르면 종료일 초기화
      if (_endDate != null &&
          _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
    });
  }

  /// 여행 종료일 선택
  Future<void> _selectEndDate() async {
    // 시작일을 먼저 선택해야 함
    if (_startDate == null) {
      _showMessage('여행 시작일을 먼저 선택해 주세요.');
      return;
    }

    final DateTime? selectedDate = await _pickDate(
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(_startDate!.year + 5),
      helpText: '여행 종료일 선택',
    );

    // 날짜를 선택하지 않고 창을 닫은 경우
    if (selectedDate == null) {
      return;
    }

    setState(() {
      _endDate = _dateOnly(selectedDate);
    });
  }

  /// 여행 정보를 Firestore에 저장
  Future<void> _saveTravel() async {
    // 키보드 닫기
    FocusScope.of(context).unfocus();

    // 이미 저장 중이라면 중복 실행 방지
    if (_isSaving) {
      return;
    }

    // 여행 이름과 예산 유효성 검사
    final bool isFormValid =
        _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      return;
    }

    // 시작일 확인
    if (_startDate == null) {
      _showMessage('여행 시작일을 선택해 주세요.');
      return;
    }

    // 종료일 확인
    if (_endDate == null) {
      _showMessage('여행 종료일을 선택해 주세요.');
      return;
    }

    // 날짜 순서 확인
    if (_endDate!.isBefore(_startDate!)) {
      _showMessage('종료일은 시작일보다 빠를 수 없습니다.');
      return;
    }

    // Firebase 로그인 사용자 확인
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    // 예산 문자열을 int로 변환
    final int? budgetAmount = _parseBudget(
      _budgetController.text,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      // 화면에서 입력받은 내용으로 여행 모델 생성
      final TravelModel travel = TravelModel(
        // 실제 문서 ID는 TravelService에서 생성
        travelId: '',

        // 현재 로그인 사용자의 Firebase UID
        userId: user.uid,

        title: _titleController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        budgetAmount: budgetAmount,
        isActive: true,
        isDeleted: false,
      );

      // Firestore에 저장한 뒤 생성된 여행 문서 ID 반환
      final String travelId =
      await _travelService.addTravel(travel);

      debugPrint('저장 완료된 여행 ID: $travelId');

      if (!mounted) {
        return;
      }

      // 여행 저장 성공 메시지
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('여행 모드가 시작되었습니다.'),
          ),
        );

      // 저장 상태를 먼저 해제
      setState(() {
        _isSaving = false;
      });

      // 현재 화면은 유지하고 경비 입력 화면을 위에 추가
      //
      // pushReplacement를 사용하지 않으므로
      // Navigator history가 비는 오류를 방지할 수 있음
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (BuildContext context) {
            return TravelExpenseInputScreen(
              travelId: travelId,
            );
          },
        ),
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Firebase 여행 생성 오류 코드: ${error.code}');
      debugPrint('Firebase 여행 생성 오류 내용: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ?? '여행 정보를 저장하지 못했습니다.',
      );
    } catch (error, stackTrace) {
      debugPrint('여행 생성 중 일반 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      _showMessage('여행 시작 중 오류가 발생했습니다.');
    } finally {
      // 오류가 발생했을 때도 저장 상태 해제
      if (mounted && _isSaving) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// DateTime에서 시간 정보를 제거하고 날짜만 반환
  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  /// 예산 입력값을 int로 변환
  ///
  /// 예산을 입력하지 않았다면 null 반환
  int? _parseBudget(String value) {
    final String normalized =
    value.replaceAll(',', '').trim();

    if (normalized.isEmpty) {
      return null;
    }

    return int.tryParse(normalized);
  }

  /// 날짜를 yyyy.MM.dd 형식으로 표시
  String _formatDate(DateTime? date) {
    if (date == null) {
      return '날짜 선택';
    }

    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  /// 금액을 천 단위 쉼표 형식으로 표시
  String _formatMoney(int amount) {
    final String value = amount.toString();
    final StringBuffer result = StringBuffer();

    for (int index = 0; index < value.length; index++) {
      if (index > 0 &&
          (value.length - index) % 3 == 0) {
        result.write(',');
      }

      result.write(value[index]);
    }

    return result.toString();
  }

  /// 시작일과 종료일을 포함한 총 여행 일수
  int get _travelDays {
    if (_startDate == null || _endDate == null) {
      return 0;
    }

    return _endDate!.difference(_startDate!).inDays + 1;
  }

  /// 하루 권장 예산 계산
  int? get _dailyBudget {
    final int? budget = _parseBudget(
      _budgetController.text,
    );

    if (budget == null ||
        budget <= 0 ||
        _travelDays <= 0) {
      return null;
    }

    return budget ~/ _travelDays;
  }

  /// SnackBar 메시지 표시
  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
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
          '여행 모드 시작',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
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
                '여행 이름',
                icon: Icons.flight_takeoff_rounded,
              ),
              const SizedBox(height: 10),
              _buildTitleField(),
              const SizedBox(height: 24),

              _buildSectionTitle(
                '여행 기간',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 10),
              _buildDateFields(),

              if (_travelDays > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '총 $_travelDays일 여행',
                  style: const TextStyle(
                    color: Color(0xFF4F7DF3),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],

              const SizedBox(height: 24),

              _buildSectionTitle(
                '여행 예산',
                icon: Icons.account_balance_wallet_rounded,
                description: '예산은 입력하지 않아도 됩니다.',
              ),
              const SizedBox(height: 10),
              _buildBudgetField(),
              const SizedBox(height: 20),

              _buildSummaryCard(),
              const SizedBox(height: 30),

              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// 화면 상단 안내 카드
  ///
  /// 여행 기간을 설정했는지 여부와 상관없이 항상 노출되는
  /// 큰 제목 문구는 제거하고, 색상 배경 + 설명 문구만 표시
  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFFE),
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
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Color(0xFF4F7DF3),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '설정한 기간에 등록되는 변동 지출은\n'
                  '여행 지출로 자동 분류됩니다.',
              style: TextStyle(
                color: Color(0xFF4C5B7A),
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 입력 영역 제목
  Widget _buildSectionTitle(
      String title, {
        required IconData icon,
        String? description,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF4F7DF3),
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
        if (description != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 여행 이름 입력창
  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      textInputAction: TextInputAction.next,
      maxLength: 30,
      decoration: _inputDecoration(
        hintText: '예: 제주도 여름 여행',
        prefixIcon: Icons.luggage_rounded,
      ).copyWith(
        counterText: '',
      ),
      validator: (String? value) {
        final String title = value?.trim() ?? '';

        if (title.isEmpty) {
          return '여행 이름을 입력해 주세요.';
        }

        if (title.length > 30) {
          return '여행 이름은 30자 이하로 입력해 주세요.';
        }

        return null;
      },
    );
  }

  /// 시작일과 종료일 선택 영역
  Widget _buildDateFields() {
    return Row(
      children: [
        Expanded(
          child: _buildDateButton(
            label: '시작일',
            selectedDate: _startDate,
            onTap: _selectStartDate,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0xFFAAAAAA),
          ),
        ),
        Expanded(
          child: _buildDateButton(
            label: '종료일',
            selectedDate: _endDate,
            onTap: _selectEndDate,
          ),
        ),
      ],
    );
  }

  /// 날짜 선택 버튼
  Widget _buildDateButton({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE6E3E7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Color(0xFF4F7DF3),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _formatDate(selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedDate == null
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF333333),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 여행 예산 입력창
  Widget _buildBudgetField() {
    return TextFormField(
      controller: _budgetController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) {
        // 예산이 변경되면 요약 카드 갱신
        setState(() {});
      },
      onFieldSubmitted: (_) {
        _saveTravel();
      },
      decoration: _inputDecoration(
        hintText: '예: 500000',
        prefixIcon: Icons.account_balance_wallet_rounded,
        suffixText: '원',
      ),
      validator: (String? value) {
        final String input = value?.trim() ?? '';

        // 예산은 선택 사항
        if (input.isEmpty) {
          return null;
        }

        final int? budget = _parseBudget(input);

        if (budget == null || budget <= 0) {
          return '예산은 1원 이상 입력해 주세요.';
        }

        return null;
      },
    );
  }

  /// 여행 정보 요약 카드
  Widget _buildSummaryCard() {
    final int? budget = _parseBudget(
      _budgetController.text,
    );

    final int? dailyBudget = _dailyBudget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            title: '여행 기간',
            value: _travelDays > 0
                ? '$_travelDays일'
                : '미설정',
          ),
          const SizedBox(height: 14),
          _buildSummaryRow(
            title: '전체 예산',
            value: budget != null && budget > 0
                ? '${_formatMoney(budget)}원'
                : '예산 없음',
          ),
          const Divider(
            height: 28,
            color: Color(0xFFF0EDF0),
          ),
          _buildSummaryRow(
            title: '하루 권장 예산',
            value: dailyBudget != null
                ? '${_formatMoney(dailyBudget)}원'
                : '계산 전',
            valueColor: const Color(0xFF4F7DF3),
          ),
        ],
      ),
    );
  }

  /// 요약 카드 내부 한 줄
  Widget _buildSummaryRow({
    required String title,
    required String value,
    Color valueColor = const Color(0xFF333333),
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  /// 여행 모드 시작 버튼
  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving
            ? null
            : _saveTravel,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF4F7DF3),
          disabledBackgroundColor:
          const Color(0xFFAEC5F7),
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
            : const Text(
          '여행 모드 시작하기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  /// 공통 입력창 디자인
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
        color: const Color(0xFF4F7DF3),
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
          color: Color(0xFF4F7DF3),
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
}