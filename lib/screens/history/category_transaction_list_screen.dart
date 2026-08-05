import 'package:flutter/material.dart';

import '../../models/transaction_item.dart';
import '../../services/transaction_service.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../widgets/report/report_tiles.dart';
import 'transaction_detail_screen.dart';

/// 정기결제·할부 리포트의 "전체보기"에서 들어오는 카테고리별 전체 목록 화면.
/// (할부 진행 중 / 정기결제 / 정기수입 / 반복저축 4곳에서 공용으로 사용)
/// 스냅샷 리스트라 항목이 지역 상태(_items)로 관리되고, 삭제 시 즉시 목록에서
/// 빠진 뒤 상위(리포트 메인) 화면에도 true를 돌려줘 재조회를 유도한다.
class CategoryTransactionListScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final List<TransactionItem> items;
  final String emptyText;

  /// 할부 목록일 때만 true → InstallmentTile(진행률바)로 렌더링
  final bool isInstallment;

  /// 할부일 때 회차 계산용 콜백
  final int Function(DateTime purchaseDate)? currentInstallmentNoBuilder;

  const CategoryTransactionListScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.items,
    required this.emptyText,
    this.isInstallment = false,
    this.currentInstallmentNoBuilder,
  }) : assert(
  !isInstallment || currentInstallmentNoBuilder != null,
  '할부 목록에는 currentInstallmentNoBuilder가 필요해요',
  );

  @override
  State<CategoryTransactionListScreen> createState() =>
      _CategoryTransactionListScreenState();
}

class _CategoryTransactionListScreenState
    extends State<CategoryTransactionListScreen> {
  late List<TransactionItem> _items = List.of(widget.items);
  bool _changed = false;

  Future<void> _openDetail(TransactionItem item) async {
    final bool? changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TransactionDetailScreen(item: item)),
    );
    if (changed == true) {
      _changed = true;
      // 상세에서 수정/삭제가 있었으면 이 화면의 스냅샷은 갱신할 방법이 없어서
      // (원본 리스트 재조회는 상위 화면 몫) 안전하게 그 항목만 목록에서 뺀다.
      if (mounted) {
        setState(() => _items.removeWhere((i) => i.id == item.id));
      }
    }
  }

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
      setState(() => _items.removeWhere((i) => i.id == item.id));
      _changed = true;
      await DdaengModal.alert(
        context,
        title: '삭제 완료',
        message: '내역을 삭제했어요.',
        type: ModalType.success,
      );
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F7FA),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xFFF8F7FA),
          surfaceTintColor: Colors.transparent,
          foregroundColor: AppColors.ink,
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        body: _items.isEmpty
            ? Center(
          child: Text(
            widget.emptyText,
            style: const TextStyle(color: AppColors.inkSub, fontSize: 13),
          ),
        )
            : ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    if (widget.isInstallment)
                      InstallmentTile(
                        item: _items[i],
                        currentNo: widget.currentInstallmentNoBuilder!(_items[i].date),
                        onTap: () => _openDetail(_items[i]),
                        onLongPress: () => _confirmDelete(_items[i]),
                      )
                    else
                      RecurringTile(
                        item: _items[i],
                        color: widget.color,
                        background: widget.background,
                        onTap: () => _openDetail(_items[i]),
                        onLongPress: () => _confirmDelete(_items[i]),
                      ),
                    if (i != _items.length - 1) const SizedBox(height: 9),
                  ],
                  ReportLongPressHint(color: widget.color, background: widget.background),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}