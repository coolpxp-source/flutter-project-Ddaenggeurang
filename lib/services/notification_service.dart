import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/subscription_model.dart';

/// 로컬(기기 내) 알림 — 서버 발송 없이 기기에서 바로 띄운다.
/// 1) "오늘 상담 남은 횟수" 즉시 알림
/// 2) 구독 결제일 매달 반복 알림
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    } catch (_) {
      // 기기에 해당 타임존 데이터가 없으면 UTC 등 기본 로케이션으로 동작 — 치명적이지 않음.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// 오늘 남은 AI상담 횟수를 알려주는 즉시 알림.
  Future<void> showConsultReminder(int remaining) async {
    if (remaining <= 0) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'ai_consult_reminder',
        'AI 상담 알림',
        channelDescription: '오늘 남은 AI 상담 횟수를 알려드려요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      id: 0,
      title: '땡쥐가 기다리고 있어요 🐭',
      body: '오늘 상담 $remaining회 남았어요. 궁금한 소비가 있다면 물어보세요!',
      notificationDetails: details,
    );
  }

  /// 오늘의 코치 잔소리(AiService.generateNagging 결과)를 알려주는 즉시 알림.
  Future<void> showDailyNagging(String message, {required String title}) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_nagging',
        '오늘의 잔소리',
        channelDescription: '코치가 오늘 소비에 대해 한마디 해줘요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(id: 1, title: title, body: message, notificationDetails: details);
  }

  /// 구독 문서 id(String)를 알림 id(양의 32bit int)로 안정적으로 변환.
  int _subscriptionNotificationId(String subscriptionId) =>
      subscriptionId.hashCode & 0x7fffffff;

  /// 구독 하나에 대해 매달 결제일 오전 9시 반복 알림을 건다.
  /// (이미 같은 id로 걸려 있으면 덮어써서 최신 이름/금액/결제일을 반영)
  Future<void> scheduleSubscriptionReminder(SubscriptionModel sub) async {
    await init();
    final id = _subscriptionNotificationId(sub.id);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, sub.paymentDay, 9);
    if (scheduled.isBefore(now)) {
      scheduled = tz.TZDateTime(tz.local, now.year, now.month + 1, sub.paymentDay, 9);
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'subscription_reminder',
        '구독 결제 알림',
        channelDescription: '구독 결제일에 맞춰 알려드려요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      title: '오늘 구독 결제일이에요 💳',
      body: '${sub.name} ${_comma(sub.amount)}원이 오늘 결제될 예정이에요',
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );
  }

  Future<void> cancelSubscriptionReminder(String subscriptionId) =>
      _plugin.cancel(id: _subscriptionNotificationId(subscriptionId));

  /// 알림 설정 on/off와 현재 활성 구독 목록에 맞춰 예약을 통째로 재조정한다.
  /// 해지/삭제된 구독은 굳이 추적하지 않고, 매번 활성 구독 기준으로 다시 걸어주는
  /// 방식이라 별도 무효화 로직 없이 항상 최신 상태로 수렴한다.
  Future<void> syncSubscriptionReminders({
    required bool enabled,
    required List<SubscriptionModel> activeSubscriptions,
  }) async {
    for (final sub in activeSubscriptions) {
      if (enabled) {
        await scheduleSubscriptionReminder(sub);
      } else {
        await cancelSubscriptionReminder(sub.id);
      }
    }
  }

  /// 예약된 모든 로컬 알림을 취소한다 — 회원탈퇴 등 계정 자체가 없어질 때 호출.
  Future<void> cancelAll() => _plugin.cancelAll();

  static String _comma(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
}
