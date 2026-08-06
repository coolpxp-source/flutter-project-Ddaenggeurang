import 'package:flutter/material.dart';

import '../../models/travel_model.dart';
import '../../services/travel_member_service.dart';

/// 여행 화면 공통 색상
const Color _mainColor = Color(0xFF4F7DF3);
const Color _mainSoftColor = Color(0xFFE8EFFE);
const Color _backgroundColor = Color(0xFFF8F7FA);
const Color _errorColor = Color(0xFFE0483C);

class TravelInvitationScreen extends StatefulWidget {
  const TravelInvitationScreen({
    super.key,
  });

  @override
  State<TravelInvitationScreen> createState() {
    return _TravelInvitationScreenState();
  }
}

class _TravelInvitationScreenState
    extends State<TravelInvitationScreen> {
  final TravelMemberService _memberService =
  TravelMemberService();

  /// 현재 처리 중인 여행 ID
  ///
  /// 한 여행의 초대를 처리하는 동안 같은 버튼이
  /// 여러 번 눌리는 것을 방지한다.
  String? _processingTravelId;

  /// DateTime을 yyyy.MM.dd 형식으로 변환
  String _formatDate(DateTime date) {
    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  /// 예외 문구에서 개발용 접두어 제거
  String _cleanErrorMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }

  /// 성공 또는 실패 내용을 모달로 표시
  ///
  /// 수정 요구사항에 따라 SnackBar는 사용하지 않는다.
  Future<void> _showResultDialog({
    required String title,
    required String message,
    bool isError = false,
  }) async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? _errorColor : _mainColor,
            size: 40,
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          content: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF555555),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                isError ? _errorColor : _mainColor,
                minimumSize: const Size(110, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// 초대 수락 전 확인 모달
  Future<void> _confirmAcceptInvitation(
      TravelModel travel,
      ) async {
    final bool? shouldAccept =
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.group_add_rounded,
            color: _mainColor,
            size: 40,
          ),
          title: const Text(
            '여행 초대 수락',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          content: Text(
            '‘${travel.title}’ 여행에 참여할까요?\n\n'
                '참여하면 여행 지출을 입력하고 '
                '전체 정산 내용을 함께 볼 수 있습니다.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF555555),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              style: TextButton.styleFrom(
                foregroundColor:
                const Color(0xFF888888),
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
              child: const Text('수락'),
            ),
          ],
        );
      },
    );

    if (shouldAccept != true) {
      return;
    }

    await _acceptInvitation(travel);
  }

  /// 여행 초대 수락 처리
  Future<void> _acceptInvitation(
      TravelModel travel,
      ) async {
    setState(() {
      _processingTravelId = travel.travelId;
    });

    try {
      /*
       * 수락하면 TravelService에서:
       *
       * 1. pendingMemberIds에서 현재 UID 제거
       * 2. memberIds에 현재 UID 추가
       *
       * 작업을 트랜잭션으로 처리한다.
       */
      await _memberService.acceptInvitation(
        travel.travelId,
      );

      await _showResultDialog(
        title: '초대 수락 완료',
        message:
        '‘${travel.title}’ 여행에 참여했습니다.\n'
            '이제 여행 지출과 정산 내용을 확인할 수 있습니다.',
      );
    } catch (error) {
      await _showResultDialog(
        title: '초대 수락 실패',
        message: _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingTravelId = null;
        });
      }
    }
  }

  /// 초대 거절 전 확인 모달
  Future<void> _confirmRejectInvitation(
      TravelModel travel,
      ) async {
    final bool? shouldReject =
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.cancel_outlined,
            color: _errorColor,
            size: 40,
          ),
          title: const Text(
            '여행 초대 거절',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          content: Text(
            '‘${travel.title}’ 여행 초대를 거절할까요?',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF555555),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              style: TextButton.styleFrom(
                foregroundColor:
                const Color(0xFF888888),
              ),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _errorColor,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(12),
                ),
              ),
              child: const Text('거절'),
            ),
          ],
        );
      },
    );

    if (shouldReject != true) {
      return;
    }

    await _rejectInvitation(travel);
  }

  /// 여행 초대 거절 처리
  Future<void> _rejectInvitation(
      TravelModel travel,
      ) async {
    setState(() {
      _processingTravelId = travel.travelId;
    });

    try {
      /*
       * 거절하면 pendingMemberIds에서
       * 현재 로그인 회원의 UID만 제거한다.
       */
      await _memberService.rejectInvitation(
        travel.travelId,
      );

      await _showResultDialog(
        title: '초대 거절 완료',
        message: '여행 초대를 거절했습니다.',
      );
    } catch (error) {
      await _showResultDialog(
        title: '초대 거절 실패',
        message: _cleanErrorMessage(error),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingTravelId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: _backgroundColor,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text(
          '받은 여행 초대',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      /*
       * pendingMemberIds에 현재 로그인 회원 UID가
       * 포함된 여행을 실시간으로 조회한다.
       */
      body: StreamBuilder<List<TravelModel>>(
        stream: _memberService.watchMyInvitations(),
        builder: (
            BuildContext context,
            AsyncSnapshot<List<TravelModel>> snapshot,
            ) {
          if (snapshot.hasError) {
            return _InvitationErrorView(
              message: _cleanErrorMessage(
                snapshot.error!,
              ),
              onRetry: () {
                setState(() {});
              },
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: _mainColor,
              ),
            );
          }

          final List<TravelModel> invitations =
              snapshot.data ?? <TravelModel>[];

          if (invitations.isEmpty) {
            return const _EmptyInvitationView();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              30,
            ),
            itemCount: invitations.length,
            separatorBuilder: (
                BuildContext context,
                int index,
                ) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (
                BuildContext context,
                int index,
                ) {
              final TravelModel travel =
              invitations[index];

              final bool isProcessing =
                  _processingTravelId ==
                      travel.travelId;

              return _InvitationCard(
                travel: travel,
                periodText:
                '${_formatDate(travel.startDate)}'
                    ' ~ '
                    '${_formatDate(travel.endDate)}',
                isProcessing: isProcessing,
                onAccept: () {
                  _confirmAcceptInvitation(travel);
                },
                onReject: () {
                  _confirmRejectInvitation(travel);
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 여행 초대 한 건을 표시하는 카드
class _InvitationCard extends StatelessWidget {
  final TravelModel travel;
  final String periodText;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _InvitationCard({
    required this.travel,
    required this.periodText,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE6E3E7),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _mainSoftColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flight_takeoff_rounded,
                  color: _mainColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '여행 초대가 도착했습니다',
                      style: TextStyle(
                        color: _mainColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      travel.title.trim().isEmpty
                          ? '이름 없는 여행'
                          : travel.title.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF222222),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          _InvitationInfoRow(
            icon: Icons.calendar_month_outlined,
            label: '여행 기간',
            value: periodText,
          ),
          const SizedBox(height: 9),
          _InvitationInfoRow(
            icon: Icons.groups_outlined,
            label: '최대 인원',
            value: '${travel.maxMembers}명',
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed:
                  isProcessing ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _errorColor,
                    side: const BorderSide(
                      color: Color(0xFFFFC8C4),
                    ),
                    minimumSize:
                    const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                  ),
                  child: const Text(
                    '거절',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed:
                  isProcessing ? null : onAccept,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mainColor,
                    minimumSize:
                    const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(13),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '수락',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 초대 카드 내부의 여행 정보 한 줄
class _InvitationInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InvitationInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 17,
          color: const Color(0xFF7B8498),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF7B8498),
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF333333),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// 받은 초대가 없을 때 표시
class _EmptyInvitationView extends StatelessWidget {
  const _EmptyInvitationView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: _mainSoftColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: _mainColor,
                size: 34,
              ),
            ),
            const SizedBox(height: 19),
            const Text(
              '받은 여행 초대가 없습니다.',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '새로운 여행 초대를 받으면\n'
                  '이곳에서 수락하거나 거절할 수 있습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 초대 목록 조회 실패 화면
class _InvitationErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InvitationErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDEC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _errorColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 17),
            const Text(
              '여행 초대를 불러오지 못했습니다.',
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _mainColor,
                minimumSize: const Size(130, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 18,
              ),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}