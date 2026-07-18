import 'package:app_badge_plus/app_badge_plus.dart';

/// 홈 화면 앱 아이콘의 알림 배지(읽지 않은 알림 개수) — 런처가 지원하지 않으면
/// (Pixel 런처 등은 숫자 대신 점만 표시하거나 아예 미지원) 조용히 무시한다.
class AppBadgeService {
  AppBadgeService._();
  static final AppBadgeService instance = AppBadgeService._();

  bool? _supported;

  Future<void> setCount(int count) async {
    _supported ??= await AppBadgePlus.isSupported();
    if (_supported != true) return;
    try {
      await AppBadgePlus.updateBadge(count);
    } catch (_) {
      // 일부 기기/런처에서 배지 갱신이 실패해도 앱 동작에 영향 없게 무시한다.
    }
  }

  Future<void> clear() => setCount(0);
}
