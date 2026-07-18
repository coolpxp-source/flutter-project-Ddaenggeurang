import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../models/subscription_model.dart';
import '../models/recurring_payment_model.dart';

/// 로컬(기기 내) 알림 — 서버 발송 없이 기기에서 바로 띄운다.
/// 1) "오늘 상담 남은 횟수" 즉시 알림
/// 2) 구독 결제일 매달 반복 알림
/// 3) 고정비(월세·공과금 등) 다음 결제일 알림
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 방해금지 시간대(설정 화면에서 지정, 기본 꺼짐)에 해당하면 true.
  /// 결제일처럼 시점이 중요한 예약 알림(구독/고정비)에는 적용하지 않고,
  /// "오늘의 다짐"·잔소리·상담 리마인더·스트릭 축하처럼 미뤄도 되는
  /// 즉시 알림에만 적용한다.
  Future<bool> _isQuietHours() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('dndEnabled') != true) return false;
    final startMin = prefs.getInt('dndStartMinutes') ?? 22 * 60;
    final endMin = prefs.getInt('dndEndMinutes') ?? 7 * 60;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    if (startMin == endMin) return false;
    if (startMin < endMin) {
      return nowMin >= startMin && nowMin < endMin;
    }
    // 자정을 넘기는 구간 (예: 22:00 ~ 07:00)
    return nowMin >= startMin || nowMin < endMin;
  }

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
  /// 실제로 띄운 제목/본문을 반환한다(호출부가 알림함에 그대로 기록할 수 있도록 —
  /// 문구를 main.dart 쪽에 중복 하드코딩하지 않기 위함). 안 띄웠으면 null.
  Future<({String title, String body})?> showConsultReminder(int remaining) async {
    if (remaining <= 0) return null;
    if (await _isQuietHours()) return null;
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
    const title = '땡쥐가 기다리고 있어요 🐭';
    final body = '오늘 상담 $remaining회 남았어요. 궁금한 소비가 있다면 물어보세요!';
    await _plugin.show(id: 0, title: title, body: body, notificationDetails: details);
    return (title: title, body: body);
  }

  /// 오늘의 코치 잔소리(AiService.generateNagging 결과)를 알려주는 즉시 알림.
  Future<void> showDailyNagging(String message, {required String title}) async {
    if (await _isQuietHours()) return;
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

  /// 아침에 뜨는 짧은 "오늘의 다짐" — 잔소리(지출 집계 기반 분석)와 달리
  /// AI/데이터 연동 없이 고정 문구 목록을 하루 하나씩 순서대로 보여준다.
  Future<void> showDailyResolution(String message) async {
    if (await _isQuietHours()) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_resolution',
        '오늘의 다짐',
        channelDescription: '아침마다 짧은 소비 습관 다짐을 보여드려요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.show(
      id: 2,
      title: '오늘의 다짐 ☀️',
      body: message,
      notificationDetails: details,
    );
  }

  /// 연속 접속 마일스톤(7/30/100일) 달성 축하 알림.
  Future<void> showStreakMilestone({required String title, required String body}) async {
    if (await _isQuietHours()) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'streak_milestone',
        '연속 접속 달성',
        channelDescription: '연속 접속 마일스톤을 달성하면 축하해드려요',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id: 3, title: title, body: body, notificationDetails: details);
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

  /// 고정비 문서 id(String)를 알림 id로 변환 — 구독과 네임스페이스가 겹치지 않도록
  /// 접두사를 붙여서 해시한다(같은 문서 id라도 구독/고정비가 다른 알림 id를 갖게).
  int _fixedExpenseNotificationId(String recurringPaymentId) =>
      'fixed_$recurringPaymentId'.hashCode & 0x7fffffff;

  /// 고정비 하나에 대해 다음 결제일(nextBillingDate) 오전 9시 알림을 건다.
  /// 구독과 달리 결제 주기가 매달/매년 다를 수 있어 "매달 같은 날" 반복이 아니라,
  /// RecurringPaymentService가 결제 처리할 때마다 갱신하는 nextBillingDate를
  /// 그대로 한 번 예약한다 — 매일 재동기화되므로 값이 바뀌면 자동으로 다시 걸린다.
  Future<void> scheduleFixedExpenseReminder(RecurringPaymentModel payment) async {
    await init();
    final id = _fixedExpenseNotificationId(payment.recurringPaymentId);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      payment.nextBillingDate.year,
      payment.nextBillingDate.month,
      payment.nextBillingDate.day,
      9,
    );
    if (scheduled.isBefore(now)) {
      // 동기화 지연 등으로 이미 지난 날짜면, 바로 다음 순간으로 대체해 알려준다.
      scheduled = now.add(const Duration(minutes: 1));
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fixed_expense_reminder',
        '고정비 결제 알림',
        channelDescription: '월세·공과금 등 고정비 결제일에 맞춰 알려드려요',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: scheduled,
      title: '오늘 고정비 결제일이에요 🏠',
      body: '${payment.name} ${_comma(payment.amount)}원이 오늘 결제될 예정이에요',
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelFixedExpenseReminder(String recurringPaymentId) =>
      _plugin.cancel(id: _fixedExpenseNotificationId(recurringPaymentId));

  /// 알림 설정 on/off와 현재 활성 고정비 목록에 맞춰 예약을 통째로 재조정한다.
  /// syncSubscriptionReminders와 동일한 방식 — 항상 최신 상태로 수렴.
  Future<void> syncFixedExpenseReminders({
    required bool enabled,
    required List<RecurringPaymentModel> activePayments,
  }) async {
    for (final payment in activePayments) {
      if (enabled) {
        await scheduleFixedExpenseReminder(payment);
      } else {
        await cancelFixedExpenseReminder(payment.recurringPaymentId);
      }
    }
  }

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
