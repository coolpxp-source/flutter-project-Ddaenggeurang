import 'package:flutter/material.dart';

import '../../models/travel_member_model.dart';
import '../../services/travel_member_service.dart';

/// 여행 최대 참여 인원
const int _maxMemberCount = 10;

/// 여행 화면에서 사용하는 공통 색상
const Color _mainColor = Color(0xFF4F7DF3);
const Color _mainSoftColor = Color(0xFFE8EFFE);
const Color _backgroundColor = Color(0xFFF8F7FA);
const Color _errorColor = Color(0xFFE0483C);

class TravelMemberScreen extends StatefulWidget {
  /// 현재 보고 있는 여행 ID
  final String travelId;

  /// 현재 로그인한 Firebase UID
  final String currentUserId;

  /// 기존 화면과의 호환을 위해 유지한다.
  ///
  /// 회원 이름은 users 컬렉션에서 가져오기 때문에
  /// 이 화면에서는 직접 사용하지 않는다.
  final String currentUserName;

  const TravelMemberScreen({
    super.key,
    required this.travelId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<TravelMemberScreen> createState() => _TravelMemberScreenState();
}

class _TravelMemberScreenState extends State<TravelMemberScreen> {
  final TravelMemberService _memberService = TravelMemberService();

  /// 내보내기나 여행 나가기 작업의 중복 실행을 방지한다.
  bool _isProcessing = false;

  /// 서비스 예외 앞에 붙는 개발용 문구를 제거한다.
  String _cleanErrorMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }

  /// 완료 또는 오류 메시지를 표시하는 공통 안내 모달
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
            size: 38,
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
                backgroundColor: isError ? _errorColor : _mainColor,
                minimumSize: const Size(100, 44),
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

  /// 여행 회원 초대 모달을 표시한다.
  ///
  /// TextEditingController를 이 메서드에서 만들고 즉시 dispose하면
  /// 모달 종료 애니메이션 도중 TextField가 해제된 컨트롤러를 참조할 수 있다.
  /// 수정본에서는 별도 StatefulWidget인 [_InviteMemberDialog]가
  /// 컨트롤러의 생성과 해제를 직접 담당한다.
  Future<void> _showInviteMemberDialog() async {
    if (!mounted) {
      return;
    }

    final TravelUserSearchResult? result =
    await showDialog<TravelUserSearchResult>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _InviteMemberDialog(
          onInvite: (String email) {
            return _memberService.inviteMemberByEmail(
              travelId: widget.travelId,
              email: email,
            );
          },
          cleanErrorMessage: _cleanErrorMessage,
        );
      },
    );

    /// 사용자가 취소했거나 화면이 이미 닫혔으면 더 진행하지 않는다.
    if (!mounted || result == null) {
      return;
    }

    await _showResultDialog(
      title: '초대 완료',
      message:
      '${result.displayName}님에게\n'
          '여행 초대를 보냈습니다.\n\n'
          '상대방이 수락하면 참여자 목록에 표시됩니다.',
    );
  }

  /// 여행 생성자가 참여 회원을 내보낸다.
  Future<void> _confirmRemoveMember(TravelMemberModel member) async {
    if (member.isOwner) {
      await _showResultDialog(
        title: '내보낼 수 없음',
        message: '여행 생성자는 내보낼 수 없습니다.',
        isError: true,
      );
      return;
    }

    final bool? shouldRemove = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.person_remove_outlined,
            color: _errorColor,
            size: 38,
          ),
          title: const Text(
            '참여자 내보내기',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            '${member.displayName}님을 여행에서 내보낼까요?\n\n'
                '해당 회원은 더 이상 여행 지출을 입력하거나 '
                '정산 내용을 확인할 수 없습니다.',
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
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _errorColor,
              ),
              child: const Text('내보내기'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldRemove != true) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _memberService.removeMember(
        travelId: widget.travelId,
        memberUserId: member.userId,
      );

      await _showResultDialog(
        title: '내보내기 완료',
        message: '${member.displayName}님을 여행에서 내보냈습니다.',
      );
    } catch (error) {
      await _showResultDialog(
        title: '내보내기 실패',
        message: _cleanErrorMessage(error),
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

  /// 일반 참여자가 여행에서 직접 나간다.
  Future<void> _confirmLeaveTravel() async {
    final bool? shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: const Icon(
            Icons.logout_rounded,
            color: _errorColor,
            size: 38,
          ),
          title: const Text(
            '여행 나가기',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            '이 여행에서 나갈까요?\n\n'
                '여행에서 나가면 지출 입력과 '
                '정산 내용 확인이 제한됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: _errorColor,
              ),
              child: const Text('나가기'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldLeave != true) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _memberService.leaveTravel(widget.travelId);

      if (!mounted) {
        return;
      }

      await _showResultDialog(
        title: '여행 나가기 완료',
        message: '여행에서 나갔습니다.',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      await _showResultDialog(
        title: '여행 나가기 실패',
        message: _cleanErrorMessage(error),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TravelMemberModel>>(
      stream: _memberService.watchMembers(widget.travelId),
      builder: (
          BuildContext context,
          AsyncSnapshot<List<TravelMemberModel>> snapshot,
          ) {
        final List<TravelMemberModel> members =
            snapshot.data ?? <TravelMemberModel>[];

        final bool isCurrentUserOwner = members.any(
              (TravelMemberModel member) {
            return member.userId == widget.currentUserId && member.isOwner;
          },
        );

        final bool isMemberLimitReached =
            members.length >= _maxMemberCount;

        return Scaffold(
          backgroundColor: _backgroundColor,
          appBar: AppBar(
            elevation: 0,
            centerTitle: true,
            backgroundColor: _backgroundColor,
            surfaceTintColor: Colors.transparent,
            foregroundColor: const Color(0xFF222222),
            title: const Text(
              '여행 참여자',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          floatingActionButton: isCurrentUserOwner
              ? FloatingActionButton.extended(
            onPressed: _isProcessing || isMemberLimitReached
                ? null
                : _showInviteMemberDialog,
            backgroundColor: isMemberLimitReached
                ? const Color(0xFFB8C3DF)
                : _mainColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
            ),
            label: Text(
              isMemberLimitReached ? '인원 마감' : '회원 초대',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
              : null,
          body: _buildBody(
            snapshot: snapshot,
            members: members,
            isCurrentUserOwner: isCurrentUserOwner,
          ),
        );
      },
    );
  }

  Widget _buildBody({
    required AsyncSnapshot<List<TravelMemberModel>> snapshot,
    required List<TravelMemberModel> members,
    required bool isCurrentUserOwner,
  }) {
    if (snapshot.hasError) {
      return _ErrorView(
        message: _cleanErrorMessage(snapshot.error!),
        onRetry: () {
          setState(() {});
        },
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(
          color: _mainColor,
        ),
      );
    }

    if (members.isEmpty) {
      return const _EmptyMemberView();
    }

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            _MemberSummary(
              memberCount: members.length,
              maxMemberCount: _maxMemberCount,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                itemCount: members.length,
                separatorBuilder: (
                    BuildContext context,
                    int index,
                    ) {
                  return const SizedBox(height: 10);
                },
                itemBuilder: (
                    BuildContext context,
                    int index,
                    ) {
                  final TravelMemberModel member = members[index];

                  final bool isCurrentUser =
                      member.userId == widget.currentUserId;

                  return _MemberCard(
                    member: member,
                    isCurrentUser: isCurrentUser,
                    canRemove: isCurrentUserOwner && !member.isOwner,
                    canLeave: isCurrentUser && !member.isOwner,
                    onRemove: () {
                      _confirmRemoveMember(member);
                    },
                    onLeave: _confirmLeaveTravel,
                  );
                },
              ),
            ),
          ],
        ),
        if (_isProcessing)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33000000),
              child: Center(
                child: CircularProgressIndicator(
                  color: _mainColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 회원 이메일 입력과 초대 요청을 담당하는 독립 모달
///
/// 이 위젯이 TextEditingController를 직접 소유하기 때문에
/// 모달의 닫힘 애니메이션과 실제 위젯 해제가 모두 끝나는 시점에
/// dispose가 실행된다. 따라서 취소 시 _dependents assertion이 발생하는
/// 기존 컨트롤러 생명주기 문제를 방지한다.
class _InviteMemberDialog extends StatefulWidget {
  final Future<TravelUserSearchResult> Function(String email) onInvite;
  final String Function(Object error) cleanErrorMessage;

  const _InviteMemberDialog({
    required this.onInvite,
    required this.cleanErrorMessage,
  });

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final TextEditingController _emailController = TextEditingController();

  bool _isInviting = false;
  String? _errorMessage;

  @override
  void dispose() {
    /// 컨트롤러는 모달 위젯이 실제로 제거될 때만 해제한다.
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember() async {
    if (_isInviting) {
      return;
    }

    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _errorMessage = '초대할 회원의 이메일을 입력해주세요.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isInviting = true;
      _errorMessage = null;
    });

    try {
      final TravelUserSearchResult result = await widget.onInvite(email);

      if (!mounted) {
        return;
      }

      /// 성공 결과를 부모 화면으로 돌려준 뒤 모달을 닫는다.
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isInviting = false;
        _errorMessage = widget.cleanErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      /// 초대 요청 중에는 시스템 뒤로 가기로 중복 종료하지 못하게 한다.
      canPop: !_isInviting,
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '여행 회원 초대',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF222222),
          ),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                '앱에 가입한 회원의 이메일을 입력해주세요. '
                    '초대를 수락한 회원만 여행 지출을 입력하고 '
                    '정산 내용을 확인할 수 있습니다.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF666666),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _emailController,
                autofocus: true,
                enabled: !_isInviting,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                decoration: _emailDecoration(
                  errorText: _errorMessage,
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                onSubmitted: (_) {
                  _inviteMember();
                },
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: <Widget>[
          TextButton(
            onPressed: _isInviting
                ? null
                : () {
              FocusScope.of(context).unfocus();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF999999),
            ),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: _isInviting ? null : _inviteMember,
            style: FilledButton.styleFrom(
              backgroundColor: _mainColor,
              minimumSize: const Size(90, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isInviting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Text('초대'),
          ),
        ],
      ),
    );
  }

  /// 이메일 입력창 디자인
  InputDecoration _emailDecoration({
    required String? errorText,
  }) {
    return InputDecoration(
      labelText: '회원 이메일',
      hintText: 'example@email.com',
      helperText:
      errorText == null ? '앱에 가입된 회원만 초대할 수 있습니다.' : null,
      errorText: errorText,
      errorMaxLines: 3,
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: _mainColor,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE6E3E7),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE6E3E7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _mainColor,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _errorColor,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _errorColor,
          width: 1.5,
        ),
      ),
    );
  }
}

/// 상단 여행 참여 인원 요약
class _MemberSummary extends StatelessWidget {
  final int memberCount;
  final int maxMemberCount;

  const _MemberSummary({
    required this.memberCount,
    required this.maxMemberCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFull = memberCount >= maxMemberCount;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: _mainSoftColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: _mainColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '현재 여행 참여자',
                  style: TextStyle(
                    color: Color(0xFF4C5B7A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$memberCount명 / 최대 $maxMemberCount명',
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isFull) ...<Widget>[
                  const SizedBox(height: 4),
                  const Text(
                    '더 이상 회원을 초대할 수 없습니다.',
                    style: TextStyle(
                      color: _errorColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 참여자 한 명을 표시하는 카드
class _MemberCard extends StatelessWidget {
  final TravelMemberModel member;
  final bool isCurrentUser;
  final bool canRemove;
  final bool canLeave;
  final VoidCallback onRemove;
  final VoidCallback onLeave;

  const _MemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.canRemove,
    required this.canLeave,
    required this.onRemove,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE6E3E7),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: member.isOwner
                  ? _mainSoftColor
                  : const Color(0xFFF1F1F4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              member.isOwner
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              color:
              member.isOwner ? _mainColor : const Color(0xFF888888),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        member.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                    ),
                    if (isCurrentUser) ...<Widget>[
                      const SizedBox(width: 6),
                      const Text(
                        '(나)',
                        style: TextStyle(
                          color: _mainColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (member.isOwner) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _mainSoftColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '생성자',
                          style: TextStyle(
                            color: _mainColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member.email.trim().isEmpty ? '가입 회원' : member.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (canRemove || canLeave)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Color(0xFF999999),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              color: Colors.white,
              onSelected: (String value) {
                if (value == 'remove') {
                  onRemove();
                } else if (value == 'leave') {
                  onLeave();
                }
              },
              itemBuilder: (BuildContext context) {
                return <PopupMenuEntry<String>>[
                  if (canRemove)
                    const PopupMenuItem<String>(
                      value: 'remove',
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.person_remove_outlined,
                            size: 18,
                            color: _errorColor,
                          ),
                          SizedBox(width: 10),
                          Text(
                            '참여자 내보내기',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  if (canLeave)
                    const PopupMenuItem<String>(
                      value: 'leave',
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.logout_rounded,
                            size: 18,
                            color: _errorColor,
                          ),
                          SizedBox(width: 10),
                          Text(
                            '여행 나가기',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                ];
              },
            ),
        ],
      ),
    );
  }
}

/// 참여자 목록이 비어 있을 때 표시
class _EmptyMemberView extends StatelessWidget {
  const _EmptyMemberView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _mainSoftColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_off_rounded,
                size: 32,
                color: _mainColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '여행 참여자 정보를 불러올 수 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 참여자 목록 조회 실패 화면
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
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
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEDEC),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: _errorColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '참여자 목록을 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF999999),
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
