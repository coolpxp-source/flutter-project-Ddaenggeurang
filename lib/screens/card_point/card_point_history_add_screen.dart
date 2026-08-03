import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_history_model.dart';
import '../../services/card_point_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

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
    if (_merchantController.text.trim().isEmpty || _pointController.text.trim().isEmpty) return;

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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        await DdaengModal.alert(context,
            title: '저장에 실패했어요', message: e.toString().replaceFirst('Exception: ', ''), type: ModalType.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditMode) return;
    final confirmed = await DdaengModal.confirm(
      context,
      title: '내역 삭제',
      message: '이 포인트 내역을 삭제할까요?',
      type: ModalType.danger,
      confirmText: '삭제',
    );
    if (confirmed) {
      setState(() => _isSaving = true);
      try {
        await _service.deleteHistory(userId: widget.userId, cardId: widget.cardId, history: widget.existing!);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          await DdaengModal.alert(context,
              title: '삭제에 실패했어요', message: e.toString().replaceFirst('Exception: ', ''), type: ModalType.danger);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
  );

  InputDecoration _deco(String hint) => InputDecoration(
    filled: true,
    fillColor: AppColors.bg,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.inkSub),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(_isEditMode ? '포인트 내역 수정' : '포인트 내역 추가',
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          if (_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _isSaving ? null : _delete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('적립'),
                    selected: _type == 'earn',
                    onSelected: (_) => setState(() => _type = 'earn'),
                    selectedColor: AppColors.income,
                    backgroundColor: AppColors.bg,
                    labelStyle: TextStyle(
                      color: _type == 'earn' ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('사용'),
                    selected: _type == 'use',
                    onSelected: (_) => setState(() => _type = 'use'),
                    selectedColor: Colors.redAccent,
                    backgroundColor: AppColors.bg,
                    labelStyle: TextStyle(
                      color: _type == 'use' ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _label('상호명'),
            TextField(controller: _merchantController, decoration: _deco('예: 스타벅스')),
            const SizedBox(height: 18),
            _label('포인트'),
            TextField(
              controller: _pointController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('0'),
            ),
            const SizedBox(height: 18),
            _label('날짜'),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.inkSub),
                    const SizedBox(width: 10),
                    Text('${_date.year}.${_date.month.toString().padLeft(2, '0')}.${_date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  disabledBackgroundColor: const Color(0xFFE5E8EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Text(_isEditMode ? '수정 저장' : '저장',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}