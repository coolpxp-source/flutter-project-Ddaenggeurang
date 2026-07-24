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
  /// 회원 이름은 이제 users 컬렉션에서 가져오기 때문에
  /// 화면 안에서는 직접 사용하지 않는다.
  final String currentUserName;

  const TravelMemberScreen({
    super.key,
    required this.travelId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<TravelMemberScreen> createState() {
    return _TravelMemberScreenState();
  }
}

class _TravelMemberScreenState extends State<TravelMemberScreen> {
  final TravelMemberService _memberService = TravelMemberService();

  /// 중복 작업을 방지하기 위한 로딩 상태
  bool _isProcessing = false;

  /// 이메일 입력창 공통 디자인
  InputDecoration _emailDecoration() {
    return InputDecoration(
      labelText: '회원 이메일',
      hintText: 'example@email.com',
      helperText: '앱에 가입된 회원만 초대할 수 있습니다.',
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
    );
  }

  /// 서비스에서 발생한 예외 문구를 화면용 문구로 정리
  String _cleanErrorMessage(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }

  /// 공통 안내 모달
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

  /// 회원 이메일 입력 후 여행 초대
  Future<void> _showInviteMemberDialog() async {
    final TextEditingController emailController =
    TextEditingController();

    bool isInviting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            Future<void> inviteMember() async {
              final String email = emailController.text.trim();

              if (email.isEmpty) {
                await _showResultDialog(
                  title: '이메일 확인',
                  message: '초대할 회원의 이메일을 입력해주세요.',
                  isError: true,
                );
                return;
              }

              setDialogState(() {
                isInviting = true;
              });

              try {
                final TravelUserSearchResult result =
                await _memberService.inviteMemberByEmail(
                  travelId: widget.travelId,
                  email: email,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                await _showResultDialog(
                  title: '초대 완료',
                  message:
                  '${result.displayName}님에게\n'
                      '여행 초대를 보냈습니다.\n\n'
                      '상대방이 수락하면 참여자 목록에 표시됩니다.',
                );
              } catch (error) {
                if (!dialogContext.mounted) {
                  return;
                }

                setDialogState(() {
                  isInviting = false;
                });

                await _showResultDialog(
                  title: '초대 실패',
                  message: _cleanErrorMessage(error),
                  isError: true,
                );
              }
            }

            return AlertDialog(
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
                      controller: emailController,
                      autofocus: true,
                      enabled: !isInviting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      decoration: _emailDecoration(),
                      onSubmitted: (_) {
                        if (!isInviting) {
                          inviteMember();
                        }
                      },
                    ),
                  ],
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
                  onPressed: isInviting
                      ? null
                      : () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF999999),
                  ),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: isInviting ? null : inviteMember,
                  style: FilledButton.styleFrom(
                    backgroundColor: _mainColor,
                    minimumSize: const Size(90, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isInviting
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
            );
          },
        );
      },
    );

    emailController.dispose();
  }

  /// 여행 생성자가 참여 회원을 내보냄
  Future<void> _confirmRemoveMember(
      TravelMemberModel member,
      ) async {
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

    if (shouldRemove != true) {
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

  /// 일반 참여자가 여행에서 직접 나감
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

    if (shouldLeave != true) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await _memberService.leaveTravel(
        widget.travelId,
      );

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
      stream: _memberService.watchMembers(
        widget.travelId,
      ),
      builder: (
          BuildContext context,
          AsyncSnapshot<List<TravelMemberModel>> snapshot,
          ) {
        final List<TravelMemberModel> members =
            snapshot.data ?? <TravelMemberModel>[];

        final bool isCurrentUserOwner = members.any(
              (TravelMemberModel member) {
            return member.userId == widget.currentUserId &&
                member.isOwner;
          },
        );

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
            onPressed: _isProcessing
                ? null
                : _showInviteMemberDialog,
            backgroundColor: _mainColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
            ),
            label: const Text(
              '회원 초대',
              style: TextStyle(
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
        message: _cleanErrorMessage(
          snapshot.error!,
        ),
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
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  110,
                ),
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
                  final TravelMemberModel member =
                  members[index];

                  final bool isCurrentUser =
                      member.userId == widget.currentUserId;

                  return _MemberCard(
                    member: member,
                    isCurrentUser: isCurrentUser,
                    canRemove:
                    isCurrentUserOwner && !member.isOwner,
                    canLeave:
                    isCurrentUser && !member.isOwner,
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
      margin: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        6,
      ),
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
              color: member.isOwner
                  ? _mainColor
                  : const Color(0xFF888888),
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
                  member.email.trim().isEmpty
                      ? '가입 회원'
                      : member.email,
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
              itemBuilder: (
                  BuildContext context,
                  ) {
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
                            style: TextStyle(
                              fontSize: 13,
                            ),
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
                            style: TextStyle(
                              fontSize: 13,
                            ),
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