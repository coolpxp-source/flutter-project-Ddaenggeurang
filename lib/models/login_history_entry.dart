import 'package:cloud_firestore/cloud_firestore.dart';

/// 로그인 성공 1건의 기록 — users/{uid}/loginHistory 서브컬렉션.
/// 실제로 연동돼 있는 로그인 수단(구글/이메일)만 기록한다.
class LoginHistoryEntry {
  final String id;
  final String method; // 'google' | 'email'
  final DateTime date;

  const LoginHistoryEntry({
    required this.id,
    required this.method,
    required this.date,
  });

  factory LoginHistoryEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LoginHistoryEntry(
      id: doc.id,
      method: d['method'] as String? ?? '',
      date: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
