import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_stat_model.dart';

class SavingShareScreen extends StatefulWidget {
  const SavingShareScreen({super.key});

  @override
  State<SavingShareScreen> createState() => _SavingShareScreenState();
}

class _SavingShareScreenState extends State<SavingShareScreen> {
  final _service = CommunityService();
  final _nicknameController = TextEditingController();
  final _amountController = TextEditingController();
  double _savingRate = 30;
  String _ageGroup = '20대';
  String _job = '학생';
  bool _saving = false;

  // TODO: 실제 로그인 유저 ID로 교체
  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _submit() async {
    if (_nicknameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final stat = CommunityStat(
      userId: _myId,
      nicknameMasked: _nicknameController.text.trim(),
      savingRate: _savingRate,
      savingAmount: num.tryParse(_amountController.text) ?? 0,
      ageGroup: _ageGroup,
      job: _job,
      updatedAt: DateTime.now(),
    );

    await _service.updateMyStat(_myId, stat);

    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('저축 비율 공유')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '닉네임 (마스킹 표시용)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('저축 비율: ${_savingRate.round()}%'),
            Slider(
              value: _savingRate,
              min: 0,
              max: 100,
              divisions: 100,
              activeColor: const Color(0xFFEE5586),
              onChanged: (v) => setState(() => _savingRate = v),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '이번 달 저축 금액 (원)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _ageGroup,
              decoration: const InputDecoration(labelText: '연령대', border: OutlineInputBorder()),
              items: ['10대', '20대', '30대', '40대', '50대 이상']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _ageGroup = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _job,
              decoration: const InputDecoration(labelText: '직군', border: OutlineInputBorder()),
              items: ['학생', '직장인', '자영업', '기타']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _job = v!),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEE5586),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('공유하기', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}