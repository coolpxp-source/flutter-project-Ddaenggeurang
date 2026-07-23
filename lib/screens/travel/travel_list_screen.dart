import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/travel_model.dart';
import '../../services/travel_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'travel_mode_start_screen.dart';
import 'travel_report_screen.dart';
import 'travel_expense_input_screen.dart';
import 'travel_member_screen.dart';

/// 홈/지출 입력 화면과 통일한 팔레트. (DdaengModal의 success 색과 동일한 초록)
class _C {
  static const ink = Color(0xFF221A20);
  static const inkSub = Color(0xFF8A8798);

  static const blue = Color(0xFF4F7DF3);
  static const blueSoft = Color(0xFFE8EFFE);
  static const greenDeep = Color(0xFF0E9660);

  static const pink = Color(0xFFFF6F91);
  static const pinkSoft = Color(0xFFFFE3EC);

  static const expense = Color(0xFFF04438);

  static const cardBorder = Color(0xFFD9F1D8);
  static const pageBg = Colors.white; // 티켓 노치 색 = 페이지 배경색과 동일해야 구멍처럼 보임

  static List<BoxShadow> cardShadow = [
    BoxShadow(color: ink.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 8)),
  ];
}

/// 여행 관리 진입점.
/// 홈/드로어에서 "여행 관리"를 누르면 바로 여행 생성 화면으로 가지 않고,
/// 이 화면에서 기존 여행 목록을 먼저 보여준 뒤, 여기서 "새 여행 시작"을
/// 눌러야 TravelModeStartScreen으로 이동한다.
class TravelListScreen extends StatelessWidget {
  const TravelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _C.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _C.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('내 여행',
            style: TextStyle(fontWeight: FontWeight.w800, color: _C.ink)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const TravelModeStartScreen(),
            ),
          );
        },
        backgroundColor: _C.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.add_rounded),
        label: const Text('새 여행 시작',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<TravelModel>>(
        stream: TravelService().getTravelsByUserId(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorView(message: '${snapshot.error}');
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: _C.blue));
          }

          final travels = snapshot.data ?? [];

          if (travels.isEmpty) {
            return const _EmptyTravelView();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: travels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final travel = travels[index];
              return _TravelTicketCard(
                travel: travel,
                onTap: () => _showTravelActions(context, travel),
                onDelete: () => _confirmDelete(context, travel),
              );
            },
          );
        },
      ),
    );
  }

  /// 여행 카드를 탭하면 어느 하위 화면으로 갈지 선택하는 바텀시트.
  void _showTravelActions(BuildContext context, TravelModel travel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E3E7),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    travel.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _C.ink,
                    ),
                  ),
                ),
              ),
              _ActionTile(
                icon: Icons.summarize_outlined,
                iconColor: _C.blue,
                iconBg: _C.blueSoft,
                label: '여행 리포트 보기',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TravelReportScreen(travelId: travel.travelId),
                    ),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.edit_note_outlined,
                iconColor: _C.pink,
                iconBg: _C.pinkSoft,
                label: '지출 입력',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TravelExpenseInputScreen(travelId: travel.travelId),
                    ),
                  );
                },
              ),
              _ActionTile(
                icon: Icons.group_outlined,
                iconColor: _C.blue,
                iconBg: _C.blueSoft,
                label: '참여자 관리',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  final user = FirebaseAuth.instance.currentUser;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TravelMemberScreen(
                        travelId: travel.travelId,
                        currentUserId: user?.uid ?? '',
                        currentUserName: user?.displayName ?? '나',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, TravelModel travel) async {
    final bool confirmed = await DdaengModal.confirm(
      context,
      title: '여행 삭제',
      message: '"${travel.title}" 여행을 삭제하시겠습니까?\n삭제된 여행은 복구할 수 없습니다.',
      type: ModalType.danger,
      confirmText: '삭제',
      cancelText: '취소',
    );

    if (!confirmed) return;

    try {
      await TravelService().deleteTravel(travel.travelId);
      if (context.mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제되었습니다',
          message: '"${travel.title}" 여행이 삭제되었어요.',
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제 실패',
          message: '$e',
          type: ModalType.danger,
        );
      }
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(icon, size: 19, color: iconColor),
      ),
      title: Text(
        label,
        style: const TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w700, color: _C.ink),
      ),
    );
  }
}

// ═══════════════════════ 가로형 항공권 티켓 카드 ═══════════════════════
//
// 좌측(넓은 메인 구역): 뱃지 + 제목 + 기간 + 예산
// 우측(좁은 스텁 구역): 비행기 아이콘 + "상세보기"
// 그 사이 경계선: 세로 점선 + 위/아래 끝 반원 노치
//
// 실제 항공권처럼 메인 구역과 스텁 구역의 배경색을 다르게 줘서
// (스텁을 진한 색으로) 구분감을 확실히 준다.

class _TravelTicketCard extends StatelessWidget {
  final TravelModel travel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TravelTicketCard({
    required this.travel,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }

  String _formatMoney(int? amount) {
    if (amount == null || amount <= 0) return '예산 없음';
    final value = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < value.length; i++) {
      if (i > 0 && (value.length - i) % 3 == 0) buffer.write(',');
      buffer.write(value[i]);
    }
    return '${buffer.toString()}원';
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = travel.isActive;
    final Color stubBg = isActive ? _C.blue : const Color(0xFFBFC3CC);
    final Color mainBg = isActive ? _C.blueSoft : const Color(0xFFF4F4F6);
    const double stubWidth = 78;

    return Container(
      height: 128,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: _C.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double seamX = constraints.maxWidth - stubWidth;
                return Stack(
                  children: [
                    // ── 메인 + 스텁 (여백 없이 바로 붙임) ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            color: mainBg,
                            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 7,
                                        runSpacing: 4,
                                        children: [
                                          if (isActive)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Text(
                                                '진행 중',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _C.blue,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            travel.title,
                                            style: const TextStyle(
                                              fontSize: 16.5,
                                              fontWeight: FontWeight.w800,
                                              color: _C.ink,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: onDelete,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded,
                                            size: 16, color: _C.expense),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_month_outlined,
                                        size: 14,
                                        color: _C.blue.withValues(alpha: 0.75)),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_formatDate(travel.startDate)} ~ ${_formatDate(travel.endDate)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _C.inkSub),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined,
                                        size: 14,
                                        color: _C.blue.withValues(alpha: 0.75)),
                                    const SizedBox(width: 5),
                                    Text(
                                      _formatMoney(travel.budgetAmount),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _C.inkSub),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          width: stubWidth,
                          color: stubBg,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 26),
                              SizedBox(height: 10),
                              Icon(Icons.visibility_outlined, color: Colors.white, size: 15),
                              SizedBox(height: 3),
                              Text(
                                '상세\n보기',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── 경계선 위에 겹쳐 그리는 점선 + 상하 노치 ──
                    Positioned(
                      left: seamX - 1,
                      top: 0,
                      bottom: 0,
                      width: 2,
                      child: CustomPaint(
                        painter: const _TicketSeamPainter(),
                        size: const Size(2, double.infinity),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 경계선 위에 겹쳐 그리는 점선 + 위/아래 반원 노치.
/// 노치는 페이지 배경색(_C.pageBg)으로, 위/아래 모서리에만 작게 그린다.
class _TicketSeamPainter extends CustomPainter {
  const _TicketSeamPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;

    final Paint notchPaint = Paint()
      ..color = _C.pageBg
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, 0), 9, notchPaint);
    canvas.drawCircle(Offset(centerX, size.height), 9, notchPaint);

    final Paint dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const double dashHeight = 5;
    const double dashSpace = 5;
    double startY = 20;
    final double endY = size.height - 20;
    while (startY < endY) {
      canvas.drawLine(
        Offset(centerX, startY),
        Offset(centerX, (startY + dashHeight).clamp(0, endY)),
        dashPaint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyTravelView extends StatelessWidget {
  const _EmptyTravelView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('✈️', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text(
              '등록된 여행이 없어요',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _C.ink),
            ),
            SizedBox(height: 8),
            Text(
              '우측 하단 버튼으로 새 여행을 시작해보세요',
              style: TextStyle(fontSize: 12.5, color: _C.inkSub),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '여행 목록을 불러오지 못했습니다.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _C.inkSub),
        ),
      ),
    );
  }
}