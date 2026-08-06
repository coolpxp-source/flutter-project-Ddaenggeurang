import 'package:flutter/material.dart';

import '../../models/transaction_item.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';

/// 정기결제/할부 리포트 화면들에서 공통으로 쓰는 카드/타일 위젯 모음.
/// 카드포인트(card_point_list_screen)·구독관리(subscription_list_screen) 화면과
/// 톤을 맞췄다: 테두리 있는 화이트 카드 + 중립색 타일 + 컬러 아이콘 박스 + chevron.

const Color kReportProgressTrackColor = Color(0xFFEDEAF2);
const Color kReportTileBg = Color(0xFFF7F8FB);

/// 흰색 섹션 카드 프레임 (테두리 + 옅은 그림자)
class SectionCard extends StatelessWidget {
  final Widget child;

  const SectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

/// 섹션 헤더(아이콘+타이틀+전체보기 필) + children 렌더링.
/// totalCount > children.length 일 때만 "전체보기" 필이 보인다.
class ReportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String emptyText;
  final List<Widget> children;
  final int totalCount;
  final VoidCallback? onSeeAll;

  const ReportSection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.emptyText,
    required this.children,
    required this.totalCount,
    this.onSeeAll,
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
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
            ),
            if (totalCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$totalCount건',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            if (onSeeAll != null && totalCount > children.length)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSeeAll,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '전체보기',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSub),
                        ),
                        Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.inkSub),
                      ],
                    ),
                  ),
                ),
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

/// 구독관리/카드포인트 톤 타일: 중립 배경 + 컬러 아이콘 박스 + 이름/보조텍스트 + 금액 + chevron
/// (탭 → 상세 이동, 꾹 누르면 → 삭제 확인)
class RecurringTile extends StatelessWidget {
  final TransactionItem item;
  final Color color;
  final Color background;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RecurringTile({
    super.key,
    required this.item,
    required this.color,
    required this.background,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kReportTileBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
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
                      style: const TextStyle(color: Color(0xFF25272C), fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.recurringPayDay != null ? '매달 ${item.recurringPayDay}일' : '매달 반복',
                      style: const TextStyle(color: Color(0xFF9A9DA5), fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                '${CurrencyFormatter.format(item.amount)}원',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 할부 전용 타일: 진행률바 포함, 중립 배경 톤으로 통일 (탭 → 상세, 꾹 누르면 → 삭제)
class InstallmentTile extends StatelessWidget {
  final TransactionItem item;
  final int currentNo;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const InstallmentTile({
    super.key,
    required this.item,
    required this.currentNo,
    this.onTap,
    this.onLongPress,
  });

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

    return Material(
      color: kReportTileBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.expense.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(13),
                    ),
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
                          style: const TextStyle(color: Color(0xFF25272C), fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '월 ${CurrencyFormatter.format(monthlyAmount)}원 × $totalMonths개월',
                          style: const TextStyle(color: Color(0xFF9A9DA5), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${CurrencyFormatter.format(item.amount)}원',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                      const Text(
                        '총액',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.inkSub),
                      ),
                    ],
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFAAAAAA)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: kReportProgressTrackColor,
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
        ),
      ),
    );
  }
}

/// 카드포인트 화면의 "꾹 눌러서 삭제" 안내 배너와 동일한 톤.
class ReportLongPressHint extends StatelessWidget {
  final Color color;
  final Color background;

  const ReportLongPressHint({
    super.key,
    this.color = AppColors.expenseDeep,
    this.background = const Color(0xFFFFF4E5),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '항목을 꾹 눌러서 삭제할 수 있어요',
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String reportFormatAmount(int amount) => CurrencyFormatter.format(amount);