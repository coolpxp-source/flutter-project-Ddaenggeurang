import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/travel_model.dart';
import '../../services/travel_service.dart';

/// 홈에서 표시하는 여행 초대 팝업의 처리 결과.
enum TravelInvitationPopupResult {
  accepted,
  rejected,
  later,
}

class TravelInvitationPopupOutcome {
  const TravelInvitationPopupOutcome({
    required this.result,
    required this.travelId,
  });

  final TravelInvitationPopupResult result;
  final String travelId;
}

/// 아직 홈 팝업으로 보여주지 않은 여행 초대 중 최신 한 건을 표시한다.
///
/// 표시 여부는 사용자 UID와 여행 ID별로 SharedPreferences에 저장한다.
/// 따라서 `나중에`를 선택해도 동일 기기의 홈에서는 같은 초대 팝업이
/// 다시 뜨지 않으며, 기존 헤더 알림과 여행 초대 목록은 그대로 유지된다.
Future<TravelInvitationPopupOutcome?> showNextTravelInvitationPopup(
    BuildContext context, {
      required String uid,
    }) async {
  if (uid.trim().isEmpty || !context.mounted) return null;

  try {
    final preferences = await SharedPreferences.getInstance();

    final invitations = await TravelService()
        .getPendingInvitations(uid)
        .first
        .timeout(
      const Duration(seconds: 10),
      onTimeout: () => <TravelModel>[],
    );

    if (!context.mounted || invitations.isEmpty) return null;

    TravelModel? invitationToShow;

    for (final invitation in invitations) {
      final popupKey = _popupKey(
        uid: uid,
        travelId: invitation.travelId,
      );

      final alreadyShown = preferences.getBool(popupKey) ?? false;

      if (!alreadyShown) {
        invitationToShow = invitation;
        break;
      }
    }

    if (invitationToShow == null || !context.mounted) return null;

    final selectedInvitation = invitationToShow;

    final result = await showDialog<TravelInvitationPopupResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TravelInvitationDialog(
        travel: selectedInvitation,
        uid: uid,
      ),
    );

    // 수락, 거절, 나중에 중 어떤 버튼을 눌렀더라도 홈 팝업은 한 번만 표시한다.
    await preferences.setBool(
      _popupKey(
        uid: uid,
        travelId: selectedInvitation.travelId,
      ),
      true,
    );

    if (result == null) return null;

    return TravelInvitationPopupOutcome(
      result: result,
      travelId: selectedInvitation.travelId,
    );
  } on TimeoutException {
    // 네트워크가 느릴 때 홈 진입 자체를 막지 않는다.
    return null;
  } catch (error, stackTrace) {
    debugPrint('여행 초대 팝업 조회 실패: $error');
    debugPrintStack(stackTrace: stackTrace);
    return null;
  }
}

String _popupKey({
  required String uid,
  required String travelId,
}) {
  return 'travel_invitation_popup_shown_${uid}_$travelId';
}

class TravelInvitationDialog extends StatefulWidget {
  const TravelInvitationDialog({
    super.key,
    required this.travel,
    required this.uid,
  });

  final TravelModel travel;
  final String uid;

  @override
  State<TravelInvitationDialog> createState() =>
      _TravelInvitationDialogState();
}

class _TravelInvitationDialogState extends State<TravelInvitationDialog> {
  final TravelService _travelService = TravelService();

  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _acceptInvitation() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await _travelService.acceptInvitation(
        travelId: widget.travel.travelId,
        userId: widget.uid,
      );

      if (!mounted) return;

      Navigator.of(context).pop(
        TravelInvitationPopupResult.accepted,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  Future<void> _rejectInvitation() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      await _travelService.rejectInvitation(
        travelId: widget.travel.travelId,
        userId: widget.uid,
      );

      if (!mounted) return;

      Navigator.of(context).pop(
        TravelInvitationPopupResult.rejected,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _errorMessage = _friendlyErrorMessage(error);
      });
    }
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();

    if (message.contains('permission-denied') ||
        message.contains('PERMISSION_DENIED')) {
      return '여행 초대 권한을 확인해주세요.';
    }

    if (message.contains('유효한 여행 초대가 없습니다')) {
      return '이미 처리했거나 만료된 여행 초대입니다.';
    }

    if (message.contains('여행 인원이 이미')) {
      return '여행 인원이 가득 차서 초대를 수락할 수 없습니다.';
    }

    return message
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final travel = widget.travel;

    return PopScope(
      canPop: !_isProcessing,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3DE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.luggage_rounded,
                  size: 34,
                  color: Color(0xFFFFA733),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '여행 초대가 도착했어요!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF221A20),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                travel.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 21,
                      color: Color(0xFF8A8798),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_formatDate(travel.startDate)}'
                            ' ~ ${_formatDate(travel.endDate)}',
                        style: const TextStyle(
                          color: Color(0xFF514B58),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE8E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isProcessing
                          ? null
                          : () => Navigator.of(context).pop(
                        TravelInvitationPopupResult.later,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8A8798),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '나중에',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _rejectInvitation,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFF04438),
                        side: const BorderSide(
                          color: Color(0xFFFFC9C6),
                        ),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '거절',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _isProcessing ? null : _acceptInvitation,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFA733),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        '수락',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
