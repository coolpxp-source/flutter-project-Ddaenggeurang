import 'package:flutter/material.dart';

import '../../models/travel_settlement_model.dart';
import '../../services/travel_settlement_service.dart';
import 'travel_member_screen.dart';

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

  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _calculateSettlement();
  }

  /// 최신 참여자와 경비를 기준으로 정산 계산
  Future<void> _calculateSettlement() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

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
        _errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 참여자 관리 화면 이동
  Future<void> _openMemberScreen() async {
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

  /// 정산 완료 또는 완료 취소
  Future<void> _toggleCompleted() async {
    final TravelSettlementModel? settlement =
        _settlement;

    if (settlement == null || _isProcessing) {
      return;
    }

    if (!settlement.isCompleted) {
      final bool? confirmed =
      await _showCompleteDialog();

      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (settlement.isCompleted) {
        await _settlementService.reopenSettlement(
          widget.travelId,
        );
      } else {
        await _settlementService.completeSettlement(
          widget.travelId,
        );
      }

      final TravelSettlementModel? updated =
      await _settlementService.getSettlement(
        widget.travelId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _settlement = updated;
      });

      _showMessage(
        settlement.isCompleted
            ? '정산 완료를 취소했습니다.'
            : '여행 정산을 완료했습니다.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool?> _showCompleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('정산 완료'),
          content: const Text(
            '모든 참여자가 송금을 완료했나요?\n\n'
                '완료 후에도 다시 정산을 계산하거나 '
                '완료 상태를 취소할 수 있습니다.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
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
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          '여행 정산',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            onPressed: _isProcessing
                ? null
                : _openMemberScreen,
            tooltip: '참여자 관리',
            icon: const Icon(
              Icons.groups_outlined,
            ),
          ),
          IconButton(
            onPressed: _isLoading || _isProcessing
                ? null
                : _calculateSettlement,
            tooltip: '다시 계산',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('정산 금액을 계산하고 있습니다.'),
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
      onRefresh: _calculateSettlement,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          40,
        ),
        children: <Widget>[
          _buildStatusCard(settlement),
          const SizedBox(height: 16),
          _buildTotalCard(settlement),
          const SizedBox(height: 24),
          _buildSectionTitle(
            icon: Icons.people_outline,
            title: '참여자별 정산',
          ),
          const SizedBox(height: 12),
          ...settlement.memberSummaries.map(
            _buildMemberSummaryCard,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(
            icon: Icons.swap_horiz,
            title: '송금할 금액',
          ),
          const SizedBox(height: 12),
          if (settlement.transfers.isEmpty)
            _buildNoTransferCard()
          else
            ...settlement.transfers.map(
              _buildTransferCard,
            ),
          const SizedBox(height: 28),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _isProcessing
                  ? null
                  : _toggleCompleted,
              style: FilledButton.styleFrom(
                backgroundColor: settlement.isCompleted
                    ? Colors.grey.shade700
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
              )
                  : Icon(
                settlement.isCompleted
                    ? Icons.restart_alt
                    : Icons.check_circle_outline,
              ),
              label: Text(
                settlement.isCompleted
                    ? '정산 완료 취소'
                    : '정산 완료',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      TravelSettlementModel settlement,
      ) {
    final Color color = settlement.isCompleted
        ? Colors.green
        : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            settlement.isCompleted
                ? Icons.check_circle
                : Icons.schedule,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              settlement.isCompleted
                  ? '정산이 완료되었습니다.'
                  : '아직 정산이 완료되지 않았습니다.',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
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
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            '전체 여행 경비',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '${_formatAmount(settlement.totalAmount)}원',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _buildTotalItem(
                  title: '참여 인원',
                  value: '${settlement.memberCount}명',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant,
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
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
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
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
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
        Icon(icon),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberSummaryCard(
      SettlementMemberSummary summary,
      ) {
    final Color statusColor = summary.shouldReceive
        ? Colors.green
        : summary.shouldSend
        ? Colors.red
        : Colors.grey;

    final String statusText = summary.shouldReceive
        ? '${_formatAmount(summary.balance)}원 받기'
        : summary.shouldSend
        ? '${_formatAmount(summary.balance.abs())}원 보내기'
        : '정산할 금액 없음';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAvatar(
                  child: Text(
                    summary.memberName.isEmpty
                        ? '?'
                        : summary.memberName[0],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    summary.memberName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
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
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_formatAmount(amount)}원',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTransferCard(
      SettlementTransferModel transfer,
      ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    transfer.fromMemberName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '보낼 사람',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
            Column(
              children: <Widget>[
                Text(
                  '${_formatAmount(transfer.amount)}원',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Icon(Icons.arrow_forward),
              ],
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    transfer.toMemberName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '받을 사람',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTransferCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.check_circle_outline,
              size: 42,
              color: Colors.green.shade600,
            ),
            const SizedBox(height: 10),
            const Text(
              '송금할 금액이 없습니다.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
            const SizedBox(height: 16),
            const Text(
              '정산 정보를 만들 수 없습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  '참여자와 경비 정보를 확인해 주세요.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openMemberScreen,
              icon: const Icon(
                Icons.groups_outlined,
              ),
              label: const Text('참여자 관리'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _calculateSettlement,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 계산'),
            ),
          ],
        ),
      ),
    );
  }
}