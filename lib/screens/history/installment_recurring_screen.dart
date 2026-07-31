import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

import '../../models/transaction_item.dart';
import '../../services/transaction_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/ddaeng_modal.dart';

/// 할부/정기결제/정기수입/반복저축을 한눈에 모아보는 리포트 화면.
///
/// 디자인 톤은 구독관리 화면(subscription_list_screen.dart)의
/// _SectionCard / _SubscriptionTile 스타일을 그대로 가져왔다.
///
/// ⚠️ 여기서 계산하는 "할부 회차"는 이 화면 전용 표시용이다.
/// 홈/카테고리 집계(총지출 등)는 여전히 구매 시점에 전액을 한 번에
/// 잡는 방식 그대로라, 이 화면의 월별 분할과는 별개로 동작한다.
///
/// 할부 회차 계산 규칙(단순화 버전, 이자 없이 원금만):
///  - 월 납입액 = 총 구매금액 ÷ 총개월수 (반올림)
///  - 1회차 청구월 = 구매한 달의 "다음 달"
class InstallmentRecurringScreen extends StatefulWidget {
  const InstallmentRecurringScreen({super.key});

  @override
  State<InstallmentRecurringScreen> createState() =>
      _InstallmentRecurringScreenState();
}

// 할부/정기결제 카드에서 로컬로 필요한 옅은 배경색.
// (AppColors엔 expenseSoft가 없어서 expense.withValues(alpha: 0.15)로 대체해 쓴다.)
// 아래는 그 외 순수 레이아웃용 중성색만 남김.
const Color _progressTrackColor = Color(0xFFEDEAF2);

class _InstallmentRecurringScreenState
    extends State<InstallmentRecurringScreen> {
  final TransactionService _transactionService = TransactionService();

  bool _isLoading = true;
  String? _errorMessage;

  List<TransactionItem> _installments = [];
  List<TransactionItem> _recurringExpenses = [];
  List<TransactionItem> _recurringIncomes = [];
  List<TransactionItem> _recurringSavings = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '로그인이 필요해요.';
      });
      if (mounted) {
        await DdaengModal.alert(
          context,
          title: '로그인이 필요해요',
          message: '로그인 후 다시 시도해 주세요.',
          type: ModalType.warning,
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<TransactionItem> all =
      await _transactionService.getAllTransactions(userId: userId);

      final List<TransactionItem> installments = <TransactionItem>[];
      final List<TransactionItem> recurringExpenses = <TransactionItem>[];
      final List<TransactionItem> recurringIncomes = <TransactionItem>[];
      final List<TransactionItem> recurringSavings = <TransactionItem>[];

      for (final TransactionItem item in all) {
        if (item.type == 'expense' && item.isInstallment) {
          installments.add(item);
        } else if (item.type == 'expense' && item.isRecurring) {
          recurringExpenses.add(item);
        } else if (item.type == 'income' && item.isRecurring) {
          recurringIncomes.add(item);
        } else if (item.type == 'saving' && item.isRecurring) {
          recurringSavings.add(item);
        }
      }

      installments.sort((a, b) => b.date.compareTo(a.date));
      recurringExpenses.sort((a, b) => b.date.compareTo(a.date));
      recurringIncomes.sort((a, b) => b.date.compareTo(a.date));
      recurringSavings.sort((a, b) => b.date.compareTo(a.date));

      if (!mounted) return;
      setState(() {
        _installments = installments;
        _recurringExpenses = recurringExpenses;
        _recurringIncomes = recurringIncomes;
        _recurringSavings = recurringSavings;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '불러오지 못했어요';
      });
      await DdaengModal.alert(
        context,
        title: '불러오지 못했어요',
        message: '$error',
        type: ModalType.danger,
      );
    }
  }

  /// 구매 다음 달을 1회차로 보고, 오늘 기준 몇 회차인지 계산한다.
  /// 1~totalMonths → 진행 중, 0 이하 → 아직 시작 전, totalMonths 초과 → 완료
  int _currentInstallmentNo(DateTime purchaseDate) {
    final DateTime firstBillingMonth =
    DateTime(purchaseDate.year, purchaseDate.month + 1);
    final DateTime now = DateTime.now();
    final DateTime currentMonth = DateTime(now.year, now.month);

    final int diffMonths =
        (currentMonth.year - firstBillingMonth.year) * 12 +
            (currentMonth.month - firstBillingMonth.month);

    return diffMonths + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        title: const Text(
          '정기결제 · 할부 관리',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.expenseDeep))
          : _errorMessage != null
          ? _ErrorView(onRetry: _load)
          : RefreshIndicator(
        onRefresh: _load,
        color: AppColors.expenseDeep,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SectionCard(
              child: _ReportSection(
                title: '할부 진행 중',
                icon: Icons.credit_card_rounded,
                color: AppColors.expenseDeep,
                emptyText: '진행 중인 할부가 없어요',
                children: _installments
                    .map((item) => _InstallmentTile(
                  item: item,
                  currentNo: _currentInstallmentNo(item.date),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: _ReportSection(
                title: '정기결제',
                icon: Icons.repeat_rounded,
                color: AppColors.expenseDeep,
                emptyText: '등록된 정기결제가 없어요',
                children: _recurringExpenses
                    .map((item) => _RecurringTile(
                  item: item,
                  color: AppColors.expenseBox,
                  background: AppColors.expense.withValues(alpha: 0.15),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: _ReportSection(
                title: '정기수입',
                icon: Icons.repeat_rounded,
                color: AppColors.income,
                emptyText: '등록된 정기수입이 없어요',
                children: _recurringIncomes
                    .map((item) => _RecurringTile(
                  item: item,
                  color: AppColors.income,
                  background: AppColors.incomeSoft,
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: _ReportSection(
                title: '반복저축',
                icon: Icons.repeat_rounded,
                color: AppColors.saving,
                emptyText: '등록된 반복저축이 없어요',
                children: _recurringSavings
                    .map((item) => _RecurringTile(
                  item: item,
                  color: AppColors.saving,
                  background: AppColors.savingSoft,
                ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독관리 화면의 _SectionCard와 동일한 스타일의 흰색 카드 프레임.
class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<Widget> children;

  const _ReportSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (children.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                emptyText,
                style: const TextStyle(color: AppColors.inkSub, fontSize: 13),
              ),
            ),
          )
        else
          ...children.map(
                (child) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: child,
            ),
          ),
      ],
    );
  }
}

/// 구독관리 _SubscriptionTile과 동일한 톤: 컬러 아이콘 박스 + 이름/보조텍스트 + 금액
class _RecurringTile extends StatelessWidget {
  final TransactionItem item;
  final Color color;
  final Color background;

  const _RecurringTile({
    required this.item,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.repeat_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item.recurringPayDay != null ? '매달 ${item.recurringPayDay}일' : '매달 반복',
                  style: const TextStyle(color: AppColors.inkSub, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${CurrencyFormatter.format(item.amount)}원',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

/// 할부 전용 타일: 위 _RecurringTile 톤에 진행률바를 추가한 버전
class _InstallmentTile extends StatelessWidget {
  final TransactionItem item;
  final int currentNo;

  const _InstallmentTile({required this.item, required this.currentNo});

  @override
  Widget build(BuildContext context) {
    final int totalMonths = item.installmentTotalMonths ?? 1;
    final int monthlyAmount = (item.amount / totalMonths).round();

    String statusText;
    double progress;
    Color statusColor;

    if (currentNo <= 0) {
      statusText = '다음 달부터 청구 시작';
      progress = 0;
      statusColor = AppColors.inkSub;
    } else if (currentNo > totalMonths) {
      statusText = '할부 완료';
      progress = 1;
      statusColor = AppColors.inkSub;
    } else {
      final int remaining = totalMonths - currentNo;
      statusText = remaining == 0 ? '이번 달이 마지막 회차예요' : '$remaining개월 남음';
      progress = currentNo / totalMonths;
      statusColor = AppColors.expenseDeep;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.expense.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: AppColors.expense.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.credit_card_rounded, color: AppColors.expenseDeep, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '월 ${CurrencyFormatter.format(monthlyAmount)}원 × $totalMonths개월',
                      style: const TextStyle(color: AppColors.inkSub, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                '${CurrencyFormatter.format(item.amount)}원',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: _progressTrackColor,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentNo <= 0 ? '시작 전' : '${currentNo.clamp(1, totalMonths)}/$totalMonths회차',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: statusColor),
              ),
              Text(
                statusText,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFF9A9DA5)),
            const SizedBox(height: 10),
            const Text(
              '불러오지 못했어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF555555), fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.expenseDeep),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}