import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/budget_model.dart';
import '../../models/category_summary_model.dart';
import '../../models/emotion_summary_model.dart';
import '../../models/user_model.dart';
import '../../services/ai_service.dart';
import '../../services/budget_service.dart';
import '../../services/category_summary_service.dart';
import '../../services/emotion_summary_service.dart';
import '../../services/psychology_test_service.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);

TextStyle _bigNumber({required double fontSize, required Color color}) {
  return GoogleFonts.jua(fontSize: fontSize, color: color, height: 1, letterSpacing: -0.5);
}

/// resultType → 한글 유형명. psychology_test_result_screen.dart의 _getResultData,
/// home_screen.dart의 _spendingTypeLabel과 같은 매핑을 유지해야 한다.
String _spendingTypeLabel(String? resultType) {
  switch (resultType) {
    case 'impulsive_spender':
      return '충동 소비형';
    case 'emotion_spender':
      return '감정 소비형';
    case 'balanced_spender':
      return '균형 소비형';
    case 'planned_spender':
      return '계획 소비형';
    default:
      return '테스트 전';
  }
}

class _MonthlyReportData {
  final UserModel user;
  final int totalSpent;
  final int monthOverMonthPercent;
  final List<CategorySummaryModel> categories;
  final List<EmotionSummaryModel> emotions;
  final String spendingType;
  final int stressTagPercent;
  final int budgetAchieved;
  final int budgetTotal;
  final int savingRate;
  final String aiMessage;

  const _MonthlyReportData({
    required this.user,
    required this.totalSpent,
    required this.monthOverMonthPercent,
    required this.categories,
    required this.emotions,
    required this.spendingType,
    required this.stressTagPercent,
    required this.budgetAchieved,
    required this.budgetTotal,
    required this.savingRate,
    required this.aiMessage,
  });
}

/// 114_월간소비통계 — mypage_home_screen.dart 메뉴의 "월간 소비 통계"에서 진입.
/// 이번 달 소비를 한 장의 카드로 요약해서 이미지로 공유할 수 있다.
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _cardKey = GlobalKey();
  late final Future<_MonthlyReportData?> _future = _load();
  bool _sharing = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<_MonthlyReportData?> _load() async {
    final now = DateTime.now();
    final lastMonthDate = DateTime(now.year, now.month - 1, 1);
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      UserService().getUser(_uid),
      CategorySummaryService().getCategorySummary(userId: _uid, year: now.year, month: now.month),
      CategorySummaryService()
          .getCategorySummary(userId: _uid, year: lastMonthDate.year, month: lastMonthDate.month),
      EmotionSummaryService().getEmotionSummary(userId: _uid, year: now.year, month: now.month),
      PsychologyTestService().getLatestTestResult(),
      BudgetService().getBudget(userId: _uid, month: monthStr),
    ]);

    final user = results[0] as UserModel?;
    if (user == null) return null;
    final categories = results[1] as List<CategorySummaryModel>;
    final lastMonthCategories = results[2] as List<CategorySummaryModel>;
    final emotions = results[3] as List<EmotionSummaryModel>;
    final testResult = results[4] as Map<String, dynamic>?;
    final budget = results[5] as BudgetModel?;

    final totalSpent = categories.fold<int>(0, (sum, c) => sum + c.totalAmount);
    final lastMonthTotal = lastMonthCategories.fold<int>(0, (sum, c) => sum + c.totalAmount);
    final momPercent =
        lastMonthTotal == 0 ? 0 : (((totalSpent - lastMonthTotal) / lastMonthTotal) * 100).round();

    final stress = emotions.where((e) => e.emotionKey == 'stress');
    final stressPercent = stress.isEmpty ? 0 : stress.first.percentage.round();

    var budgetAchieved = 0;
    var budgetTotal = 0;
    final categoryBudgets = budget?.categoryBudgets ?? const <String, int>{};
    for (final entry in categoryBudgets.entries) {
      if (entry.value <= 0) continue;
      budgetTotal++;
      final spent = categories
          .where((c) => c.categoryKey == entry.key)
          .fold<int>(0, (sum, c) => sum + c.totalAmount);
      if (spent <= entry.value) budgetAchieved++;
    }

    final income = user.salary;
    final savingRate =
        income <= 0 ? 0 : (((income - totalSpent) / income) * 100).round().clamp(0, 100);

    final topCategory = categories.isEmpty ? null : categories.first;

    String aiMessage;
    try {
      aiMessage = await AiService().generateMonthly(
        user.coachTone,
        totalSpent: totalSpent,
        monthOverMonthPercent: momPercent,
        income: income,
        savingRate: savingRate,
        topCategory: topCategory?.categoryName ?? '없음',
        topCategoryPercent: topCategory == null ? 0 : topCategory.percentage.round(),
        stressTagPercent: stressPercent,
        budgetAchieved: budgetAchieved,
        budgetTotal: budgetTotal,
      );
    } catch (_) {
      aiMessage = '이번 달도 수고 많으셨어요!';
    }

    return _MonthlyReportData(
      user: user,
      totalSpent: totalSpent,
      monthOverMonthPercent: momPercent,
      categories: categories,
      emotions: emotions,
      spendingType: _spendingTypeLabel(testResult?['resultType'] as String?),
      stressTagPercent: stressPercent,
      budgetAchieved: budgetAchieved,
      budgetTotal: budgetTotal,
      savingRate: savingRate,
      aiMessage: aiMessage,
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/ddaeng_report_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: '땡그랑 — 이번 달 소비 리포트'),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유에 실패했어요. 잠시 후 다시 시도해주세요')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('월간 소비 통계', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<_MonthlyReportData?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final data = snap.data;
          if (data == null || data.categories.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('이번 달 지출 기록이 아직 없어요.\n기록이 쌓이면 리포트를 만들어드릴게요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _inkSub)),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              children: [
                RepaintBoundary(
                  key: _cardKey,
                  child: _ReportCard(data: data, month: now),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _share,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _sharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                        : const Icon(Icons.ios_share_rounded, size: 19),
                    label: const Text('이미지로 공유하기',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _MonthlyReportData data;
  final DateTime month;
  const _ReportCard({required this.data, required this.month});

  @override
  Widget build(BuildContext context) {
    final top3 = data.categories.take(3).toList();
    final maxAmount = top3.isEmpty ? 1 : top3.first.totalAmount;
    final mom = data.monthOverMonthPercent;
    final momText = mom == 0 ? '전월과 비슷해요' : (mom > 0 ? '전월 대비 +$mom%' : '전월 대비 $mom%');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC168), Color(0xFFFF7A45), Color(0xFFFF5C7A)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF6A66).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12)),
        ],
      ),
      // ClipRRect로 감싸지 않는다 — home_screen.dart에서 확인된 렌더링 버그
      // (ClipRRect가 그 안의 텍스트 첫 글자를 깨뜨림)를 피하기 위해, 장식 원은
      // 클리핑 없이 살짝 넘치게 둔다.
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${data.user.nickname}님의 ${month.month}월 리포트',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  const Text('땡그랑',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
                ],
              ),
              const SizedBox(height: 18),
              const Text('이번 달 총지출',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white70)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(comma(data.totalSpent), style: _bigNumber(fontSize: 36, color: Colors.white)),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 4),
                    child: Text('원', style: TextStyle(fontSize: 15, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(momText,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 20),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 18),
              const Text('카테고리 TOP 3',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white70)),
              const SizedBox(height: 10),
              for (final c in top3) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.categoryName,
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text('${comma(c.totalAmount)}원',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6)),
                          ),
                          FractionallySizedBox(
                            widthFactor: maxAmount == 0 ? 0 : c.totalAmount / maxAmount,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                  color: Colors.white, borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: _stat('소비 유형', data.spendingType)),
                  Expanded(child: _stat('저축률', '${data.savingRate}%')),
                  Expanded(
                      child: _stat('예산 달성',
                          data.budgetTotal == 0 ? '-' : '${data.budgetAchieved}/${data.budgetTotal}')),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(data.aiMessage,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white70)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      );
}
