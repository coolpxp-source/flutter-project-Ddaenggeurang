import 'package:cloud_firestore/cloud_firestore.dart';

/// 기기에 실제로 띄운 로컬 알림 1건의 기록 — users/{uid}/notifications 서브컬렉션.
/// OS가 나중에 직접 울리는 예약 알림(구독 결제일 등)은 앱이 그 순간에 실행 중이란
/// 보장이 없어 여기 기록되지 않는다. 앱이 켜져 있을 때 즉시 발송하는 알림만 남긴다.
class NotificationEntry {
  final String id;
  final String title;
  final String body;
  final String type; // 'consult' | 'nagging'
  final DateTime date;
  final bool read;

  const NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.date,
    required this.read,
  });

  factory NotificationEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return NotificationEntry(
      id: doc.id,
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      type: d['type'] as String? ?? '',
      date: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: d['read'] as bool? ?? false,
    );
  }
}
