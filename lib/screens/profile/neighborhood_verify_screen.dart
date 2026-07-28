import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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

  /// 위치 서비스/권한 상태를 확인해서, 문제가 있으면 사용자에게 보여줄
  /// 안내 문구를 반환한다. 문제없으면 null.
  Future<String?> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return '기기의 위치 서비스(GPS)가 꺼져 있어요.\n설정에서 위치 서비스를 켜주세요.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return '위치정보 권한을 허용해주세요.\n권한을 허용해야 내 동네를 인증할 수 있어요.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return '위치정보 권한이 거부되어 있어요.\n기기 설정 > 앱 권한에서 위치 접근을 직접 허용해주세요.';
    }

    return null;
  }

  Future<void> _detectLocation() async {
    setState(() => _loading = true);
    try {
      // 1) 권한/위치 서비스 상태 먼저 확인 — 실기기에서 가장 흔한 실패 원인
      final permissionMessage = await _checkLocationPermission();
      if (permissionMessage != null) {
        if (mounted) {
          await DdaengModal.alert(
            context,
            title: '위치정보 권한이 필요해요',
            message: permissionMessage,
            type: ModalType.warning,
          );
        }
        return;
      }

      final position = await _locationService.getCurrentPosition();

      // 2) 에뮬레이터에서 위치를 따로 설정 안 하면 흔히 (0.0, 0.0)이 잡힘 —
      // 실제 GPS 좌표가 정확히 0,0일 가능성은 거의 없으므로 이걸로 구분
      if (position.latitude == 0.0 && position.longitude == 0.0) {
        if (mounted) {
          await DdaengModal.alert(
            context,
            title: '위치를 확인할 수 없어요',
            message: '에뮬레이터를 사용 중이라면, 확장 컨트롤(⋮) 메뉴의 '
                'Location 탭에서 위도/경도를 설정해주세요.',
            type: ModalType.warning,
          );
        }
        return;
      }

      final dong = await _locationService.reverseGeocodeToDong(
        position.latitude,
        position.longitude,
      );
      setState(() => _detectedDong = dong);
    } catch (e) {
      if (mounted) {
        await DdaengModal.alert(
          context,
          title: '위치를 확인할 수 없어요',
          message: '잠시 후 다시 시도해 주세요.\n계속 안 되면 위치 서비스 상태를 확인해 주세요.',
          type: ModalType.danger,
        );
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