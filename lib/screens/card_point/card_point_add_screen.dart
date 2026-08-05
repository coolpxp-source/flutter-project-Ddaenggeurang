import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_model.dart';
import '../../services/card_point_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

const Color _mainColor = Color(0xFF6C63FF);
const Color _mainSoftColor = Color(0xFFEDECFF);
const Color _mainBorderSoftColor = Color(0xFFDAD7FF);

class CardPointAddScreen extends StatefulWidget {
  const CardPointAddScreen({super.key});

  @override
  State<CardPointAddScreen> createState() => _CardPointAddScreenState();
}

class _CardPointAddScreenState extends State<CardPointAddScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
    if (!_formKey.currentState!.validate()) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

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
    } catch (e) {
      if (mounted) {
        await DdaengModal.alert(
          context,
          title: '저장할 수 없어요',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: ModalType.danger,
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
        title: const Text('카드 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: _mainSoftColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _mainBorderSoftColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.credit_card_rounded, color: _mainColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text('보유 중인 카드의 포인트 정보를\n등록해 주세요.',
                          style: TextStyle(color: Color(0xFF4B4770), fontSize: 12, fontWeight: FontWeight.w600, height: 1.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _sectionTitle('카드사', icon: Icons.apartment_rounded),
              const SizedBox(height: 10),
              TextFormField(
                controller: _companyController,
                enabled: !_isSaving,
                decoration: _inputDecoration(hintText: '예: 신한카드', prefixIcon: Icons.apartment_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? '카드사를 입력하세요.' : null,
              ),
              const SizedBox(height: 24),
              _sectionTitle('카드 이름', icon: Icons.credit_card_rounded),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cardNameController,
                enabled: !_isSaving,
                decoration: _inputDecoration(hintText: '예: 딥드림 카드', prefixIcon: Icons.credit_card_rounded),
                validator: (v) => (v == null || v.trim().isEmpty) ? '카드 이름을 입력하세요.' : null,
              ),
              const SizedBox(height: 24),
              _sectionTitle('보유 포인트', icon: Icons.stars_rounded),
              const SizedBox(height: 10),
              TextFormField(
                controller: _totalPointController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyFormatter()],
                decoration: _inputDecoration(hintText: '0', suffixText: 'P', prefixIcon: Icons.stars_rounded),
              ),
              const SizedBox(height: 24),
              _sectionTitle('소멸예정 포인트', icon: Icons.timer_outlined),
              const SizedBox(height: 10),
              TextFormField(
                controller: _expiringPointController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyFormatter()],
                decoration: _inputDecoration(hintText: '0', suffixText: 'P', prefixIcon: Icons.timer_outlined),
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
                      : const Text('저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}