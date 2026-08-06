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
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  final _locationService = LocationService();
  bool _loading = false;
  String? _detectedDong;

  @override
  void initState() {
    super.initState();
    _loadExistingDong();
  }

  Future<void> _loadExistingDong() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final verifiedDong = doc.data()?['verifiedDong'] as String?;
    if (mounted && verifiedDong != null) {
      setState(() => _detectedDong = verifiedDong);
    }
  }

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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          '동네 인증',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: false,
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 상단 그라데이션 히어로 카드
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_gradientStart, _gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  top: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.14),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 14),
                    const Text('내 동네를 인증해주세요',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text('인증된 동네는 직거래 신뢰도를 높여줘요',
                        style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 인증 결과 카드 (인증 전/후 상태에 따라 다르게)
          if (_detectedDong != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _green.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
                    child: const Icon(Icons.check_circle_rounded, color: _green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('감지된 동네', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        const SizedBox(height: 2),
                        Text(_detectedDong!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.my_location_rounded, size: 30, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text('아직 위치를 확인하지 않았어요',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
              ),
            ),
          const SizedBox(height: 20),

          // 버튼 영역
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _detectLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA733),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('현재 위치 확인하기',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          if (_detectedDong != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _confirmVerify,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: _green),
                ),
                child: Text('이 동네로 인증하기',
                    style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}