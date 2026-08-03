import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_model.dart';
import '../../services/card_point_service.dart';

class CardPointAddScreen extends StatefulWidget {
  const CardPointAddScreen({super.key});

  @override
  State<CardPointAddScreen> createState() => _CardPointAddScreenState();
}

class _CardPointAddScreenState extends State<CardPointAddScreen> {
  final _companyController = TextEditingController();
  final _cardNameController = TextEditingController();
  final _totalPointController = TextEditingController();
  final _expiringPointController = TextEditingController();
  final _service = CardPointService();
  bool _isSaving = false;

  @override
  void dispose() {
    _companyController.dispose();
    _cardNameController.dispose();
    _totalPointController.dispose();
    _expiringPointController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    if (_companyController.text.trim().isEmpty || _cardNameController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _service.addCard(
        userId: userId,
        card: CardPointModel(
          cardId: '',
          userId: userId,
          cardName: _cardNameController.text.trim(),
          companyName: _companyController.text.trim(),
          totalPoint: parseAmount(_totalPointController.text),
          expiringPoint: parseAmount(_expiringPointController.text),
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('카드 추가',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label('카드사'),
            TextField(controller: _companyController, decoration: _deco('예: 신한카드')),
            const SizedBox(height: 18),
            _label('카드 이름'),
            TextField(controller: _cardNameController, decoration: _deco('예: 딥드림 카드')),
            const SizedBox(height: 18),
            _label('보유 포인트'),
            TextField(
              controller: _totalPointController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('0'),
            ),
            const SizedBox(height: 18),
            _label('소멸예정 포인트'),
            TextField(
              controller: _expiringPointController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('0'),
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
                    : const Text('저장', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}