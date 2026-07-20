import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/location_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

class NeighborhoodVerifyScreen extends StatefulWidget {
  const NeighborhoodVerifyScreen({super.key});

  @override
  State<NeighborhoodVerifyScreen> createState() => _NeighborhoodVerifyScreenState();
}

class _NeighborhoodVerifyScreenState extends State<NeighborhoodVerifyScreen> {
  static const _green = Color(0xFFFF9166);
  final _locationService = LocationService();
  bool _loading = false;
  String? _detectedDong;

  Future<void> _detectLocation() async {
    setState(() => _loading = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final dong = await _locationService.reverseGeocodeToDong(
        position.latitude,
        position.longitude,
      );
      setState(() => _detectedDong = dong);
    } catch (e) {
      if (mounted) {
        await DdaengModal.alert(context, title: '위치를 확인할 수 없어요', message: '$e', type: ModalType.danger);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmVerify() async {
    if (_detectedDong == null) return;

    final confirmed = await DdaengModal.confirm(
      context,
      title: '$_detectedDong(으)로 인증할까요?',
      message: '인증한 동네는 상품 등록 시 자동으로 표시돼요.',
      type: ModalType.success,
    );
    if (!confirmed) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'verifiedDong': _detectedDong,
      'verifiedAt': Timestamp.now(),
    });

    if (mounted) {
      await DdaengModal.alert(context, title: '동네 인증 완료', type: ModalType.success);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('동네 인증')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('현재 위치로 내 동네를 인증해주세요.\n인증된 동네는 직거래 신뢰도를 높여줘요.',
                style: TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            if (_detectedDong != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: _green),
                    const SizedBox(width: 8),
                    Text(_detectedDong!, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _detectLocation,
              style: ElevatedButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_loading ? '위치 확인 중...' : '현재 위치 확인하기',
                  style: const TextStyle(color: Colors.white)),
            ),
            if (_detectedDong != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _confirmVerify,
                child: const Text('이 동네로 인증하기'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}