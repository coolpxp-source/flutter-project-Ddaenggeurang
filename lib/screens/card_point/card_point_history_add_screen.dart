import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_history_model.dart';
import '../../services/card_point_service.dart';

class CardPointHistoryAddScreen extends StatefulWidget {
  final String userId;
  final String cardId;

  const CardPointHistoryAddScreen({
    super.key,
    required this.userId,
    required this.cardId,
  });

  @override
  State<CardPointHistoryAddScreen> createState() => _CardPointHistoryAddScreenState();
}

class _CardPointHistoryAddScreenState extends State<CardPointHistoryAddScreen> {
  final _merchantController = TextEditingController();
  final _pointController = TextEditingController();
  final _service = CardPointService();

  String _type = 'earn'; // 'earn' | 'use'
  DateTime _date = DateTime.now();
  bool _isSaving = false;

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
      await _service.addHistory(
        userId: widget.userId,
        cardId: widget.cardId,
        history: CardPointHistoryModel(
          historyId: '',
          date: _date,
          merchant: _merchantController.text.trim(),
          point: parseAmount(_pointController.text),
          type: _type,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: hint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  // 날짜선택
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('포인트 내역 추가',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                    labelStyle: TextStyle(
                      color: _type == 'earn' ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
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
                    labelStyle: TextStyle(
                      color: _type == 'use' ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                    showCheckmark: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(controller: _merchantController, decoration: _deco('상호명 (예: 스타벅스)')),
            const SizedBox(height: 12),
            TextField(
              controller: _pointController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('포인트'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.inkSub),
                    const SizedBox(width: 10),
                    Text('${_date.year}.${_date.month}.${_date.day}',
                        style: const TextStyle(color: AppColors.ink)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}