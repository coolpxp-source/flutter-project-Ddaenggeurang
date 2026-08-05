import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

import '../../models/transaction_item.dart';
import '../../services/transaction_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../widgets/report/report_tiles.dart';
import 'transaction_detail_screen.dart';
import 'category_transaction_list_screen.dart';

/// 할부/정기결제/정기수입/반복저축을 한눈에 모아보는 리포트 화면.
/// 카드포인트·구독관리 화면과 톤을 맞췄다: 상단 그라데이션 요약 카드 +
/// 테두리 있는 화이트 섹션 카드 + 중립색 타일. 각 섹션은 최대 3개만
/// 보여주고, "전체보기"를 누르면 카테고리별 전체 목록으로 이동한다.
/// 타일을 꾹 누르면 공용 모달(DdaengModal)로 삭제 확인을 받는다.
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

/// 메인 화면(리포트)에서 각 섹션당 보여줄 최대 개수
const int _kSectionPreviewCount = 3;

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

  /// 타일 탭 → 상세화면 이동. 수정/삭제로 변경이 있었으면 리포트를 새로고침.
  Future<void> _openDetail(TransactionItem item) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(item: item)),
    );
    if (changed == true) {
      _load();
    }
  }

  /// 타일 꾹 누르기 → 공용 모달로 삭제 확인 후 삭제.
  Future<void> _confirmDelete(TransactionItem item) async {
    final confirmed = await DdaengModal.confirm(
      context,
      title: '내역 삭제',
      message: '${item.title}을(를) 삭제할까요?',
      type: ModalType.danger,
      cancelText: '취소',
      confirmText: '삭제',
    );
    if (!confirmed) return;

    try {
      await TransactionService().deleteTransaction(item.type, item.id);
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '삭제 완료',
        message: '내역을 삭제했어요.',
        type: ModalType.success,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '삭제할 수 없어요',
        message: '$e',
        type: ModalType.danger,
      );
    }
  }

  /// "전체보기" 탭 → 카테고리 전체 목록 화면 이동. 거기서 변경이 있었으면 새로고침.
  Future<void> _openCategoryList({
    required String title,
    required IconData icon,
    required Color color,
    required Color background,
    required List<TransactionItem> items,
    required String emptyText,
    bool isInstallment = false,
  }) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryTransactionListScreen(
          title: title,
          icon: icon,
          color: color,
          background: background,
          items: items,
          emptyText: emptyText,
          isInstallment: isInstallment,
          currentInstallmentNoBuilder:
          isInstallment ? _currentInstallmentNo : null,
        ),
      ),
    );
    if (changed == true) {
      _load();
    }
  }

  int _sumAmount(List<TransactionItem> items) =>
      items.fold<int>(0, (sum, item) => sum + item.amount);

  /// 이번 달 실제로 청구 중인 할부 건만 골라 월 납입액을 합산한다.
  int _sumActiveInstallmentMonthly() {
    int total = 0;
    for (final item in _installments) {
      final int totalMonths = item.installmentTotalMonths ?? 1;
      final int currentNo = _currentInstallmentNo(item.date);
      if (currentNo >= 1 && currentNo <= totalMonths) {
        total += (item.amount / totalMonths).round();
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _SummaryCard(
              recurringExpenseTotal: _sumAmount(_recurringExpenses),
              installmentMonthlyTotal: _sumActiveInstallmentMonthly(),
              recurringIncomeTotal: _sumAmount(_recurringIncomes),
              recurringSavingTotal: _sumAmount(_recurringSavings),
              installmentActiveCount: _installments
                  .where((item) {
                final total = item.installmentTotalMonths ?? 1;
                final no = _currentInstallmentNo(item.date);
                return no >= 1 && no <= total;
              }).length,
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: ReportSection(
                title: '할부 진행 중',
                icon: Icons.credit_card_rounded,
                color: AppColors.expenseDeep,
                emptyText: '진행 중인 할부가 없어요',
                totalCount: _installments.length,
                onSeeAll: () => _openCategoryList(
                  title: '할부 진행 중',
                  icon: Icons.credit_card_rounded,
                  color: AppColors.expenseDeep,
                  background: AppColors.expense.withValues(alpha: 0.15),
                  items: _installments,
                  emptyText: '진행 중인 할부가 없어요',
                  isInstallment: true,
                ),
                children: _installments
                    .take(_kSectionPreviewCount)
                    .map((item) => InstallmentTile(
                  item: item,
                  currentNo: _currentInstallmentNo(item.date),
                  onTap: () => _openDetail(item),
                  onLongPress: () => _confirmDelete(item),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: ReportSection(
                title: '정기결제',
                icon: Icons.repeat_rounded,
                color: AppColors.expenseDeep,
                emptyText: '등록된 정기결제가 없어요',
                totalCount: _recurringExpenses.length,
                onSeeAll: () => _openCategoryList(
                  title: '정기결제',
                  icon: Icons.repeat_rounded,
                  color: AppColors.expenseDeep,
                  background: AppColors.expense.withValues(alpha: 0.15),
                  items: _recurringExpenses,
                  emptyText: '등록된 정기결제가 없어요',
                ),
                children: _recurringExpenses
                    .take(_kSectionPreviewCount)
                    .map((item) => RecurringTile(
                  item: item,
                  color: AppColors.expenseDeep,
                  background: AppColors.expense.withValues(alpha: 0.15),
                  onTap: () => _openDetail(item),
                  onLongPress: () => _confirmDelete(item),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: ReportSection(
                title: '정기수입',
                icon: Icons.repeat_rounded,
                color: AppColors.income,
                emptyText: '등록된 정기수입이 없어요',
                totalCount: _recurringIncomes.length,
                onSeeAll: () => _openCategoryList(
                  title: '정기수입',
                  icon: Icons.repeat_rounded,
                  color: AppColors.income,
                  background: AppColors.incomeSoft,
                  items: _recurringIncomes,
                  emptyText: '등록된 정기수입이 없어요',
                ),
                children: _recurringIncomes
                    .take(_kSectionPreviewCount)
                    .map((item) => RecurringTile(
                  item: item,
                  color: AppColors.income,
                  background: AppColors.incomeSoft,
                  onTap: () => _openDetail(item),
                  onLongPress: () => _confirmDelete(item),
                ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              child: ReportSection(
                title: '반복저축',
                icon: Icons.repeat_rounded,
                color: AppColors.saving,
                emptyText: '등록된 반복저축이 없어요',
                totalCount: _recurringSavings.length,
                onSeeAll: () => _openCategoryList(
                  title: '반복저축',
                  icon: Icons.repeat_rounded,
                  color: AppColors.saving,
                  background: AppColors.savingSoft,
                  items: _recurringSavings,
                  emptyText: '등록된 반복저축이 없어요',
                ),
                children: _recurringSavings
                    .take(_kSectionPreviewCount)
                    .map((item) => RecurringTile(
                  item: item,
                  color: AppColors.saving,
                  background: AppColors.savingSoft,
                  onTap: () => _openDetail(item),
                  onLongPress: () => _confirmDelete(item),
                ))
                    .toList(),
              ),
            ),
            const ReportLongPressHint(),
          ],
        ),
      ),
    );
  }
}

/// 카드포인트/구독관리 화면 상단 요약 카드와 동일한 톤의 그라데이션 카드.
class _SummaryCard extends StatelessWidget {
  final int recurringExpenseTotal;
  final int installmentMonthlyTotal;
  final int recurringIncomeTotal;
  final int recurringSavingTotal;
  final int installmentActiveCount;

  const _SummaryCard({
    required this.recurringExpenseTotal,
    required this.installmentMonthlyTotal,
    required this.recurringIncomeTotal,
    required this.recurringSavingTotal,
    required this.installmentActiveCount,
  });

  @override
  Widget build(BuildContext context) {
    final int monthlyOutflow = recurringExpenseTotal + installmentMonthlyTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFA35C), Color(0xFFFF7A45)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 정기 지출',
            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${reportFormatAmount(monthlyOutflow)}원',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '정기결제 ${reportFormatAmount(recurringExpenseTotal)}원 · 할부 납입 ${reportFormatAmount(installmentMonthlyTotal)}원',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryItem(label: '할부 진행', value: '$installmentActiveCount건'),
              const SizedBox(width: 8),
              _SummaryItem(label: '정기수입', value: '${reportFormatAmount(recurringIncomeTotal)}원'),
              const SizedBox(width: 8),
              _SummaryItem(label: '반복저축', value: '${reportFormatAmount(recurringSavingTotal)}원'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
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