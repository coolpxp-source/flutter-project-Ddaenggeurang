import 'package:flutter/material.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_history_model.dart';
import '../../services/card_point_service.dart';

const Color _mainColor = Color(0xFF6C63FF);
const Color _mainSoftColor = Color(0xFFEDECFF);
const Color _mainBorderSoftColor = Color(0xFFDAD7FF);

class CardPointHistoryAddScreen extends StatefulWidget {
  final String userId;
  final String cardId;
  final CardPointHistoryModel? existing;

  const CardPointHistoryAddScreen({
    super.key,
    required this.userId,
    required this.cardId,
    this.existing,
  });

  @override
  State<CardPointHistoryAddScreen> createState() => _CardPointHistoryAddScreenState();
}

class _CardPointHistoryAddScreenState extends State<CardPointHistoryAddScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final _merchantController = TextEditingController(text: widget.existing?.merchant);
  late final _pointController = TextEditingController(
    text: widget.existing != null ? CurrencyFormatter.format(widget.existing!.point) : null,
  );
  final _service = CardPointService();

  late String _type = widget.existing?.type ?? 'earn';
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  bool _isSaving = false;

  bool get _isEditMode => widget.existing != null;

  @override
  void dispose() {
    _merchantController.dispose();
    _pointController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final newHistory = CardPointHistoryModel(
        historyId: widget.existing?.historyId ?? '',
        date: _date,
        merchant: _merchantController.text.trim(),
        point: parseAmount(_pointController.text),
        type: _type,
      );

      if (_isEditMode) {
        await _service.updateHistory(
          userId: widget.userId,
          cardId: widget.cardId,
          oldHistory: widget.existing!,
          newHistory: newHistory,
        );
      } else {
        await _service.addHistory(userId: widget.userId, cardId: widget.cardId, history: newHistory);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(_isEditMode ? '내역을 수정했어요.' : '내역을 추가했어요.'),
              ],
            ),
            backgroundColor: const Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('저장 중 오류가 발생했습니다.\n${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: const Color(0xFFE0483C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.all(16),
          ),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditMode) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE8E5E8), borderRadius: BorderRadius.circular(999)),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 58, height: 58,
                  decoration: const BoxDecoration(color: Color(0xFFFFECEA), shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE0483C), size: 29),
                ),
                const SizedBox(height: 16),
                const Text('내역을 삭제할까요?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                const SizedBox(height: 8),
                const Text('이 포인트 내역이 목록에서 삭제됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF777777))),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: const Color(0xFF666666),
                          side: const BorderSide(color: Color(0xFFE5E2E5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFFE0483C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('삭제하기', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      await _service.deleteHistory(userId: widget.userId, cardId: widget.cardId, history: widget.existing!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('삭제 중 오류가 발생했습니다.\n${e.toString().replaceFirst('Exception: ', '')}'),
              backgroundColor: const Color(0xFFE0483C),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              margin: const EdgeInsets.all(16),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: _mainColor),
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      suffixStyle: const TextStyle(color: Color(0xFF555555), fontSize: 13, fontWeight: FontWeight.w700),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border(const Color(0xFFE6E3E7)),
      enabledBorder: border(const Color(0xFFE6E3E7)),
      focusedBorder: border(_mainColor, width: 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, width: 1.5),
    );
  }

  Widget _sectionTitle(String title, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _mainColor),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(color: Color(0xFF333333), fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ko', 'KR'),
      helpText: '날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _mainColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF222222),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: _mainColor,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _date = picked);
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
        title: Text(_isEditMode ? '포인트 내역 수정' : '포인트 내역 추가',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE0483C)),
              onPressed: _isSaving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('적립'),
                      selected: _type == 'earn',
                      onSelected: _isSaving ? null : (_) => setState(() => _type = 'earn'),
                      selectedColor: _mainColor,
                      backgroundColor: Colors.white,
                      side: BorderSide(color: _mainBorderSoftColor),
                      labelStyle: TextStyle(
                        color: _type == 'earn' ? Colors.white : const Color(0xFF333333),
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('사용'),
                      selected: _type == 'use',
                      onSelected: _isSaving ? null : (_) => setState(() => _type = 'use'),
                      selectedColor: Colors.redAccent,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFF3D9D9)),
                      labelStyle: TextStyle(
                        color: _type == 'use' ? Colors.white : const Color(0xFF333333),
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle('상호명', icon: Icons.storefront_rounded),
              const SizedBox(height: 10),
              TextFormField(
                controller: _merchantController,
                enabled: !_isSaving,
                decoration: _inputDecoration(hintText: '예: 스타벅스', prefixIcon: Icons.storefront_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? '상호명을 입력하세요.' : null,
              ),
              const SizedBox(height: 24),
              _sectionTitle('포인트', icon: Icons.stars_rounded),
              const SizedBox(height: 10),
              TextFormField(
                controller: _pointController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyFormatter()],
                decoration: _inputDecoration(hintText: '0', suffixText: 'P', prefixIcon: Icons.stars_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? '포인트를 입력하세요.' : null,
              ),
              const SizedBox(height: 24),
              _sectionTitle('날짜', icon: Icons.calendar_month_rounded),
              const SizedBox(height: 10),
              InkWell(
                onTap: _isSaving ? null : _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: _inputDecoration(
                    hintText: '날짜 선택',
                    prefixIcon: Icons.calendar_month_rounded,
                    suffixIcon: const Icon(Icons.chevron_right_rounded, color: _mainColor),
                  ),
                  child: Text(
                    '${_date.year}.${_date.month.toString().padLeft(2, '0')}.${_date.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _mainColor,
                    disabledBackgroundColor: const Color(0xFFC9C5FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 23, height: 23,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                      : Text(_isEditMode ? '수정 저장' : '저장',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}