import 'package:flutter/material.dart';

import '../../models/travel_settlement_model.dart';
import '../../services/travel_settlement_service.dart';
import 'travel_member_screen.dart';

const Color _mainColor = Color(0xFF4F7DF3);
const Color _mainSoftColor = Color(0xFFE8EFFE);
const Color _bgColor = Color(0xFFF8F7FA);
const Color _receiveColor = Color(0xFF12B76A);
const Color _sendColor = Color(0xFFE0483C);

class TravelSettlementScreen extends StatefulWidget {
  final String travelId;
  final String currentUserId;
  final String currentUserName;

  const TravelSettlementScreen({
    super.key,
    required this.travelId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<TravelSettlementScreen> createState() =>
      _TravelSettlementScreenState();
}

class _TravelSettlementScreenState
    extends State<TravelSettlementScreen> {
  final TravelSettlementService _settlementService =
  TravelSettlementService();

  TravelSettlementModel? _settlement;

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isClosing = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettlement();
  }

  /// 정산 화면 최초 실행
  ///
  /// 1. 완료된 정산이 없는 경우: 일반 정산
  /// 2. 완료된 정산이 있고 변경 없음: 안내 후 화면 종료
  /// 3. 완료 후 추가 지출이나 참여자 변경이 있음: 다시 정산
  Future<void> _loadSettlement() async {
    if (_isProcessing || _isClosing) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final TravelSettlementModel? savedSettlement =
      await _settlementService.getSettlement(
        widget.travelId,
      );

      // 기존 정산이 없거나 아직 완료되지 않은 경우
      if (savedSettlement?.isCompleted != true) {
        await _calculateSettlement();
        return;
      }

      // 현재 참여자와 지출을 기준으로 계산만 수행한다.
      final TravelSettlementModel currentSettlement =
      await _settlementService
          .calculateFromFirestore(
        widget.travelId,
      );

      if (!mounted) {
        return;
      }

      final bool hasChanged = _hasSettlementChanged(
        savedSettlement!,
        currentSettlement,
      );

      // 완료 후 추가 지출이나 참여자 변경이 없는 경우
      if (!hasChanged) {
        setState(() {
          _isLoading = false;
        });

        await _showNoSettlementDialog();

        if (!mounted) {
          return;
        }

        _isClosing = true;
        Navigator.of(context).pop(false);
        return;
      }

      // 완료 이후 변경 사항이 있으면 다시 정산할 수 있게 한다.
      await _settlementService.reopenSettlement(
        widget.travelId,
      );

      final TravelSettlementModel updatedSettlement =
      await _settlementService.calculateAndSave(
        widget.travelId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _settlement = updatedSettlement;
        _isLoading = false;
      });

      _showMessage(
        '추가된 지출을 반영해 정산 금액을 다시 계산했습니다.',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            error.message?.toString() ??
                '정산 정보를 확인해 주세요.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(error);
      });
    }
  }

  /// 저장된 정산과 현재 정산 결과가 달라졌는지 확인
  bool _hasSettlementChanged(
      TravelSettlementModel saved,
      TravelSettlementModel current,
      ) {
    if (saved.totalAmount != current.totalAmount) {
      return true;
    }

    if (saved.memberCount != current.memberCount) {
      return true;
    }

    if (saved.memberSummaries.length !=
        current.memberSummaries.length) {
      return true;
    }

    final Map<String, SettlementMemberSummary>
    savedSummaryMap =
    <String, SettlementMemberSummary>{
      for (final SettlementMemberSummary summary
      in saved.memberSummaries)
        summary.memberId: summary,
    };

    for (final SettlementMemberSummary currentSummary
    in current.memberSummaries) {
      final SettlementMemberSummary? savedSummary =
      savedSummaryMap[currentSummary.memberId];

      if (savedSummary == null) {
        return true;
      }

      if (savedSummary.paidAmount !=
          currentSummary.paidAmount) {
        return true;
      }

      if (savedSummary.shareAmount !=
          currentSummary.shareAmount) {
        return true;
      }

      if (savedSummary.balance !=
          currentSummary.balance) {
        return true;
      }
    }

    return false;
  }

  /// 최신 참여자와 경비 기준으로 정산
  Future<void> _calculateSettlement() async {
    if (_isProcessing || _isClosing) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final TravelSettlementModel settlement =
      await _settlementService.calculateAndSave(
        widget.travelId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _settlement = settlement;
      });
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.message;
      });
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            error.message?.toString() ??
                '정산 정보를 확인해 주세요.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _cleanError(error);
      });
    } finally {
      if (mounted && !_isClosing) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 참여자 관리 화면 이동
  Future<void> _openMemberScreen() async {
    if (_isProcessing || _isClosing) {
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TravelMemberScreen(
          travelId: widget.travelId,
          currentUserId: widget.currentUserId,
          currentUserName: widget.currentUserName,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    await _calculateSettlement();
  }

  /// 정산 완료
  Future<void> _completeSettlement() async {
    final TravelSettlementModel? settlement =
        _settlement;

    if (settlement == null ||
        settlement.isCompleted ||
        _isProcessing ||
        _isClosing) {
      return;
    }

    final bool? confirmed =
    await _showCompleteDialog();

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _settlementService.completeSettlement(
        widget.travelId,
      );

      if (!mounted) {
        return;
      }

      _isClosing = true;

      // true를 반환해 이전 화면도 새로고침할 수 있게 한다.
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        _cleanError(error),
        isError: true,
      );
    } finally {
      if (mounted && !_isClosing) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// 정산할 새로운 내역이 없을 때 표시
  Future<void> _showNoSettlementDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '정산 내역 없음',
            style: TextStyle(
              color: Color(0xFF222222),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            '현재 새로 정산할 내역이 없습니다.\n'
                '추가 지출이 생기면 다시 정산할 수 있습니다.',
            style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            14,
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _mainColor,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showCompleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '정산 완료',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          content: const Text(
            '모든 참여자가 송금을 완료했나요?\n\n'
                '추가 지출이 생기면 다시 정산할 수 있습니다.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF555555),
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            14,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              style: TextButton.styleFrom(
                foregroundColor:
                const Color(0xFF999999),
              ),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _mainColor,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: const Text('정산 완료'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor:
          isError ? _sendColor : null,
        ),
      );
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '');
  }

  String _formatAmount(int amount) {
    final String value = amount.abs().toString();

    final String formatted = value.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match match) => '${match[1]},',
    );

    return amount < 0 ? '-$formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: _bgColor,
          surfaceTintColor: Colors.transparent,
          foregroundColor:
          const Color(0xFF222222),
          title: const Text(
            '여행 정산',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: <Widget>[
            IconButton(
              onPressed:
              _isLoading || _isProcessing
                  ? null
                  : _openMemberScreen,
              tooltip: '참여자 관리',
              icon: const Icon(
                Icons.groups_rounded,
                color: _mainColor,
              ),
            ),
            IconButton(
              onPressed:
              _isLoading || _isProcessing
                  ? null
                  : _calculateSettlement,
              tooltip: '다시 계산',
              icon: const Icon(
                Icons.refresh_rounded,
                color: _mainColor,
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(
              color: _mainColor,
            ),
            SizedBox(height: 16),
            Text(
              '정산 정보를 확인하고 있습니다.',
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    final TravelSettlementModel? settlement =
        _settlement;

    if (settlement == null) {
      return _buildErrorView();
    }

    return RefreshIndicator(
      color: _mainColor,
      onRefresh: _calculateSettlement,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          16,
          20,
          40,
        ),
        children: <Widget>[
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildTotalCard(settlement),
          const SizedBox(height: 26),
          _buildSectionTitle(
            icon: Icons.people_alt_rounded,
            title: '참여자별 정산',
          ),
          const SizedBox(height: 12),
          ...settlement.memberSummaries.map(
            _buildMemberSummaryCard,
          ),
          const SizedBox(height: 26),
          _buildSectionTitle(
            icon: Icons.swap_horiz_rounded,
            title: '송금할 금액',
          ),
          const SizedBox(height: 12),
          if (settlement.transfers.isEmpty)
            _buildNoTransferCard()
          else
            ...settlement.transfers.map(
              _buildTransferCard,
            ),
          const SizedBox(height: 30),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _isProcessing
                  ? null
                  : _completeSettlement,
              style: FilledButton.styleFrom(
                backgroundColor: _mainColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(17),
                ),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                width: 22,
                height: 22,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons
                    .check_circle_outline_rounded,
              ),
              label: const Text(
                '정산 완료',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            color: Color(0xFFC98A00),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '아직 정산이 완료되지 않았습니다.',
              style: TextStyle(
                color: Color(0xFFC98A00),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
      TravelSettlementModel settlement,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _mainSoftColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            '전체 여행 경비',
            style: TextStyle(
              color: Color(0xFF4C5B7A),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatAmount(settlement.totalAmount)}원',
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(
            color: Color(0xFFD5E1FB),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildTotalItem(
                  title: '참여 인원',
                  value:
                  '${settlement.memberCount}명',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color:
                const Color(0xFFD5E1FB),
              ),
              Expanded(
                child: _buildTotalItem(
                  title: '1인당 기본 금액',
                  value:
                  '${_formatAmount(settlement.perPersonAmount)}원',
                ),
              ),
            ],
          ),
          if (settlement.remainderAmount > 0) ...[
            const SizedBox(height: 14),
            Text(
              '나머지 ${settlement.remainderAmount}원은 '
                  '참여자 순서대로 1원씩 포함되었습니다.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4C5B7A),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTotalItem({
    required String title,
    required String value,
  }) {
    return Column(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF4C5B7A),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF222222),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 18,
          color: _mainColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSummaryCard(
      SettlementMemberSummary summary,
      ) {
    final Color statusColor = summary.shouldReceive
        ? _receiveColor
        : summary.shouldSend
        ? _sendColor
        : const Color(0xFF999999);

    final String statusText = summary.shouldReceive
        ? '${_formatAmount(summary.balance)}원 받기'
        : summary.shouldSend
        ? '${_formatAmount(summary.balance.abs())}원 보내기'
        : '정산할 금액 없음';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: _mainSoftColor,
                foregroundColor: _mainColor,
                child: Text(
                  summary.memberName.isEmpty
                      ? '?'
                      : summary.memberName[0],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary.memberName,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(
            height: 1,
            color: Color(0xFFF0EDF0),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildAmountItem(
                  title: '실제 결제',
                  amount: summary.paidAmount,
                ),
              ),
              Expanded(
                child: _buildAmountItem(
                  title: '부담 금액',
                  amount: summary.shareAmount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountItem({
    required String title,
    required int amount,
  }) {
    return Column(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF999999),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatAmount(amount)}원',
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTransferCard(
      SettlementTransferModel transfer,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  transfer.fromMemberName,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '보낼 사람',
                  style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: <Widget>[
              Text(
                '${_formatAmount(transfer.amount)}원',
                style: const TextStyle(
                  color: _mainColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _mainColor,
              ),
            ],
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  transfer.toMemberName,
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '받을 사람',
                  style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTransferCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
      ),
      child: const Column(
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            size: 42,
            color: _receiveColor,
          ),
          SizedBox(height: 10),
          Text(
            '송금할 금액이 없습니다.',
            style: TextStyle(
              color: Color(0xFF333333),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: _mainSoftColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 38,
                color: _mainColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '정산 정보를 만들 수 없습니다.',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  '참여자와 경비 정보를 확인해 주세요.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _openMemberScreen,
                style: FilledButton.styleFrom(
                  backgroundColor: _mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(
                  Icons.groups_rounded,
                  size: 18,
                ),
                label: const Text(
                  '참여자 관리',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _calculateSettlement,
              style: TextButton.styleFrom(
                foregroundColor: _mainColor,
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),
              label: const Text('다시 계산'),
            ),
          ],
        ),
      ),
    );
  }
}