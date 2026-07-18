import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/login_history_entry.dart';
import '../../services/login_history_service.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _blue = Color(0xFF4F7DF3);
const _blueSoft = Color(0xFFE8EFFE);
const _ok = Color(0xFF12B76A);
const _warn = Color(0xFFF5A623);

/// 최근 로그인 기록(최대 30건, 최신순)을 코드로 훑어서 눈에 띄는 패턴만
/// 짚어주는 간단한 보안 점검. AI 판단이 아니라 규칙 기반이라 즉시 계산된다.
class _SecuritySummary {
  final String? primaryMethod;
  final bool methodChanged;
  final bool rapidLogins;
  const _SecuritySummary({
    required this.primaryMethod,
    required this.methodChanged,
    required this.rapidLogins,
  });

  bool get isSafe => !methodChanged && !rapidLogins;
}

_SecuritySummary _analyzeSecurity(List<LoginHistoryEntry> items) {
  if (items.isEmpty) {
    return const _SecuritySummary(primaryMethod: null, methodChanged: false, rapidLogins: false);
  }
  final counts = <String, int>{};
  for (final e in items) {
    counts[e.method] = (counts[e.method] ?? 0) + 1;
  }
  final primary = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  // 기록이 몇 건 안 되면 "평소와 다르다"는 판단 자체가 의미 없으므로 3건 이상일 때만 본다.
  final methodChanged = items.length >= 3 && items.first.method != primary;
  final recentWindow = items.first.date.subtract(const Duration(minutes: 10));
  final rapidCount = items.where((e) => e.date.isAfter(recentWindow)).length;
  final rapidLogins = rapidCount >= 3;
  return _SecuritySummary(primaryMethod: primary, methodChanged: methodChanged, rapidLogins: rapidLogins);
}

/// 설정 > 로그인 활동 — 언제/어떤 방법으로 로그인했는지 최근 기록을 보여준다.
/// 알림함(notification_history_screen.dart)과 동일한 리스트 톤을 따른다.
class LoginHistoryScreen extends StatelessWidget {
  const LoginHistoryScreen({super.key});

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'google':
        return 'Google 로그인';
      case 'email':
        return '이메일 로그인';
      default:
        return method;
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'google':
        return Icons.g_mobiledata_rounded;
      case 'email':
        return Icons.mail_outline_rounded;
      default:
        return Icons.login_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('로그인 활동', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<LoginHistoryEntry>>(
              stream: LoginHistoryService().watchHistory(uid),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _accent, strokeWidth: 2.4));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const _EmptyHistory();
                }
                final security = _analyzeSecurity(items);
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _SecurityReportCard(
                          summary: security,
                          primaryMethodLabel:
                              security.primaryMethod == null ? null : _methodLabel(security.primaryMethod!),
                        ),
                      );
                    }
                    final entry = items[i - 1];
                    return _LoginHistoryCard(
                      label: _methodLabel(entry.method),
                      icon: _methodIcon(entry.method),
                      relativeTime: _relativeTime(entry.date),
                      isLatest: i - 1 == 0,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SecurityReportCard extends StatelessWidget {
  final _SecuritySummary summary;
  final String? primaryMethodLabel;
  const _SecurityReportCard({required this.summary, required this.primaryMethodLabel});

  @override
  Widget build(BuildContext context) {
    final color = summary.isSafe ? _ok : _warn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(summary.isSafe ? Icons.shield_rounded : Icons.shield_moon_rounded,
                  size: 18, color: color),
              const SizedBox(width: 8),
              Text(summary.isSafe ? '보안 상태: 안전해요' : '눈에 띄는 로그인 패턴이 있어요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          if (primaryMethodLabel != null) ...[
            const SizedBox(height: 8),
            Text('평소 로그인 방법: $primaryMethodLabel',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSub)),
          ],
          if (summary.methodChanged) ...[
            const SizedBox(height: 6),
            const _WarningLine('최근 로그인이 평소와 다른 방법이에요. 본인이 아니라면 비밀번호를 바꿔주세요'),
          ],
          if (summary.rapidLogins) ...[
            const SizedBox(height: 6),
            const _WarningLine('짧은 시간 안에 로그인이 여러 번 있었어요'),
          ],
        ],
      ),
    );
  }
}

class _WarningLine extends StatelessWidget {
  final String text;
  const _WarningLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, size: 14, color: _warn),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _ink, height: 1.4)),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 44, color: _inkSub),
            const SizedBox(height: 14),
            const Text('아직 로그인 기록이 없어요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 6),
            const Text('로그인할 때마다 여기에 기록이 쌓여요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _inkSub, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _LoginHistoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String relativeTime;
  final bool isLatest;

  const _LoginHistoryCard({
    required this.label,
    required this.icon,
    required this.relativeTime,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blueSoft, Color.lerp(_blueSoft, Colors.white, 0.15)!],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _blue.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                if (isLatest) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('최근',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _blue)),
                  ),
                ],
              ],
            ),
          ),
          Text(relativeTime,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSub)),
        ],
      ),
    );
  }
}
