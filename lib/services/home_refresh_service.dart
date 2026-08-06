import 'package:flutter/foundation.dart';

/// 홈 대시보드(예산 히어로/카테고리별 지출/최근 내역 등)는 화면을 열 때
/// FutureBuilder로 한 번만 데이터를 읽어오기 때문에, 지출 입력처럼 다른
/// 화면에서 데이터를 바꾸고 홈으로 돌아와도 저절로 새로고침되지 않는다.
/// 이 신호값이 바뀌면 홈 화면이 대시보드 위젯을 통째로 다시 만들어서
/// 모든 FutureBuilder가 새로 데이터를 읽어오게 한다.
class HomeRefreshService {
  HomeRefreshService._();
  static final ValueNotifier<int> signal = ValueNotifier(0);

  static void requestRefresh() => signal.value++;
}
