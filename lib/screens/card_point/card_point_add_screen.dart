import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
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
          totalPoint: int.tryParse(_totalPointController.text) ?? 0,
          expiringPoint: int.tryParse(_expiringPointController.text) ?? 0,
        ),
      );
      if (mounted) Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('카드 추가', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _companyController, decoration: _deco('카드사 (예: 신한카드)')),
            const SizedBox(height: 12),
            TextField(controller: _cardNameController, decoration: _deco('카드 이름 (예: 딥드림 카드)')),
            const SizedBox(height: 12),
            TextField(
              controller: _totalPointController,
              keyboardType: TextInputType.number,
              decoration: _deco('보유 포인트'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expiringPointController,
              keyboardType: TextInputType.number,
              decoration: _deco('소멸예정 포인트'),
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