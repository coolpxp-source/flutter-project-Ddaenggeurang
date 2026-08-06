import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 자체를 생체인증(지문/얼굴) 또는 기기 PIN/패턴/비밀번호로 잠그는 기능.
///
/// 자체 PIN을 만들어 저장하지 않는다 — 기기 잠금 화면 인증을 그대로 위임
/// (LocalAuthentication의 device credential fallback)하는 편이 훨씬 안전하고,
/// 우리가 비밀번호 보관/검증 로직을 직접 만들 필요도 없다.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();

  static const _prefKey = 'appLockEnabled';
  final _auth = LocalAuthentication();

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  /// 이 기기에서 생체인증/기기 잠금 중 하나라도 쓸 수 있는지 확인.
  /// 아무 것도 설정 안 된 기기(잠금 없음)에서는 앱 잠금을 켤 수 없다.
  Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// 생체인증 또는 기기 PIN/패턴/비밀번호로 인증한다.
  /// 사용자가 취소하거나 인증에 실패하면 false.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: '땡그랑을 열려면 인증해주세요',
        biometricOnly: false, // 생체인증이 없으면 기기 PIN/패턴/비밀번호로 대체
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
