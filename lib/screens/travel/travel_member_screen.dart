import 'package:flutter/material.dart';

import '../../models/travel_member_model.dart';
import '../../services/travel_member_service.dart';

// 앱 공통 블루 테마 컬러
const Color _mainColor = Color(0xFF4F7DF3);
const Color _mainSoftColor = Color(0xFFE8EFFE);
const Color _bgColor = Color(0xFFF8F7FA);
const Color _errorColor = Color(0xFFE0483C);

class TravelMemberScreen extends StatefulWidget {
  final String travelId;
  final String currentUserId;
  final String currentUserName;

  const TravelMemberScreen({
    super.key,
    required this.travelId,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<TravelMemberScreen> createState() =>
      _TravelMemberScreenState();
}

class _TravelMemberScreenState
    extends State<TravelMemberScreen> {
  final TravelMemberService _memberService =
  TravelMemberService();

  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();

    _initializeOwner();
  }

  /// 여행 생성자를 최초 참여자로 자동 등록
  Future<void> _initializeOwner() async {
    try {
      final List<TravelMemberModel> members =
      await _memberService.getMembers(
        widget.travelId,
      );

      final bool hasOwner = members.any(
            (TravelMemberModel member) => member.isOwner,
      );

      if (!hasOwner) {
        await _memberService.addOwner(
          travelId: widget.travelId,
          userId: widget.currentUserId,
          name: widget.currentUserName.trim().isEmpty
              ? '나'
              : widget.currentUserName.trim(),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '여행 생성자 등록에 실패했습니다: $error',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// 공통 입력창 디자인 (다른 여행 화면들과 동일한 톤)
  InputDecoration _fieldDecoration({
    required String hintText,
    String? labelText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 13,
      ),
      prefixIcon: const Icon(
        Icons.person_outline_rounded,
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
    );
  }

  /// 다이얼로그 취소/확정 버튼 공통 스타일
  Widget _dialogPrimaryButton({
    required String label,
    required bool isSaving,
    required VoidCallback? onPressed,
    Color color = _mainColor,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: isSaving
          ? const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      )
          : Text(label),
    );
  }

  /// 참여자 추가 창
  Future<void> _showAddMemberDialog() async {
    final TextEditingController nameController =
    TextEditingController();

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            Future<void> saveMember() async {
              final String name =
              nameController.text.trim();

              if (name.isEmpty) {
                _showMessage(
                  '참여자 이름을 입력해주세요.',
                  isError: true,
                );
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await _memberService.addGuest(
                  travelId: widget.travelId,
                  name: name,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _showMessage('$name 님을 추가했습니다.');
              } catch (error) {
                if (!mounted) {
                  return;
                }

                _showMessage(
                  '참여자 추가에 실패했습니다: $error',
                  isError: true,
                );

                setDialogState(() {
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '여행 참여자 추가',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
              content: TextField(
                controller: nameController,
                autofocus: true,
                enabled: !isSaving,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                decoration: _fieldDecoration(
                  labelText: '참여자 이름',
                  hintText: '예: 민수',
                ),
                onSubmitted: (_) {
                  if (!isSaving) {
                    saveMember();
                  }
                },
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                14,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                    const Color(0xFF999999),
                  ),
                  child: const Text('취소'),
                ),
                _dialogPrimaryButton(
                  label: '추가',
                  isSaving: isSaving,
                  onPressed:
                  isSaving ? null : saveMember,
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  /// 참여자 이름 수정 창
  Future<void> _showEditMemberDialog(
      TravelMemberModel member,
      ) async {
    final TextEditingController nameController =
    TextEditingController(
      text: member.name,
    );

    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
              BuildContext context,
              StateSetter setDialogState,
              ) {
            Future<void> updateMember() async {
              final String name =
              nameController.text.trim();

              if (name.isEmpty) {
                _showMessage(
                  '참여자 이름을 입력해주세요.',
                  isError: true,
                );
                return;
              }

              if (name == member.name.trim()) {
                Navigator.of(dialogContext).pop();
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                await _memberService.updateMemberName(
                  memberId: member.memberId,
                  name: name,
                );

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _showMessage('참여자 이름을 수정했습니다.');
              } catch (error) {
                if (!mounted) {
                  return;
                }

                _showMessage(
                  '참여자 수정에 실패했습니다: $error',
                  isError: true,
                );

                setDialogState(() {
                  isSaving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                '참여자 이름 수정',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
              content: TextField(
                controller: nameController,
                autofocus: true,
                enabled: !isSaving,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                decoration: _fieldDecoration(
                  hintText: '참여자 이름',
                ),
                onSubmitted: (_) {
                  if (!isSaving) {
                    updateMember();
                  }
                },
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                14,
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () {
                    Navigator.of(
                      dialogContext,
                    ).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor:
                    const Color(0xFF999999),
                  ),
                  child: const Text('취소'),
                ),
                _dialogPrimaryButton(
                  label: '수정',
                  isSaving: isSaving,
                  onPressed:
                  isSaving ? null : updateMember,
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
  }

  /// 참여자 삭제 확인
  Future<void> _confirmDeleteMember(
      TravelMemberModel member,
      ) async {
    if (member.isOwner) {
      _showMessage(
        '여행 생성자는 삭제할 수 없습니다.',
        isError: true,
      );
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '참여자 삭제',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          content: Text(
            '${member.displayName} 님을 '
                '여행 참여자에서 삭제할까요?\n\n'
                '이 참여자가 결제한 경비가 있다면 '
                '정산 전에 결제자를 변경해야 합니다.',
            style: const TextStyle(
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
                foregroundColor: const Color(0xFF999999),
              ),
              child: const Text('취소'),
            ),
            _dialogPrimaryButton(
              label: '삭제',
              isSaving: false,
              color: _errorColor,
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _memberService.deleteMember(
        member.memberId,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        '${member.displayName} 님을 삭제했습니다.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        '참여자 삭제에 실패했습니다: $error',
        isError: true,
      );
    }
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
          backgroundColor: isError ? _errorColor : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: _bgColor,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
        _isInitializing ? null : _showAddMemberDialog,
        backgroundColor: _mainColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          '참여자 추가',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isInitializing
          ? const Center(
        child: CircularProgressIndicator(
          color: _mainColor,
        ),
      )
          : StreamBuilder<List<TravelMemberModel>>(
        stream: _memberService.watchMembers(
          widget.travelId,
        ),
        builder: (
            BuildContext context,
            AsyncSnapshot<List<TravelMemberModel>>
            snapshot,
            ) {
          if (snapshot.hasError) {
            return _ErrorView(
              message: snapshot.error.toString(),
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

          final List<TravelMemberModel> members =
              snapshot.data ??
                  <TravelMemberModel>[];

          if (members.isEmpty) {
            return const _EmptyMemberView();
          }

          return Column(
            children: <Widget>[
              _MemberSummary(
                memberCount: members.length,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    8,
                    20,
                    100,
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

                    return _MemberCard(
                      member: member,
                      onEdit: () {
                        _showEditMemberDialog(
                          member,
                        );
                      },
                      onDelete: member.isOwner
                          ? null
                          : () {
                        _confirmDeleteMember(
                          member,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 상단 참여자 인원 수 요약 카드
class _MemberSummary extends StatelessWidget {
  final int memberCount;

  const _MemberSummary({
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
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
                  '$memberCount명',
                  style: const TextStyle(
                    color: Color(0xFF222222),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 개별 참여자 카드
class _MemberCard extends StatelessWidget {
  final TravelMemberModel member;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _MemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
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
            width: 40,
            height: 40,
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
                  : const Color(0xFF999999),
              size: 20,
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
                    if (member.isOwner) ...<Widget>[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _mainSoftColor,
                          borderRadius:
                          BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '여행 생성자',
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
                const SizedBox(height: 3),
                Text(
                  member.userId.trim().isEmpty
                      ? '비회원 참여자'
                      : '회원 참여자',
                  style: const TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
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
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete?.call();
              }
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: _mainColor,
                      ),
                      SizedBox(width: 10),
                      Text(
                        '이름 수정',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                if (!member.isOwner)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: _errorColor,
                        ),
                        SizedBox(width: 10),
                        Text(
                          '삭제',
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

/// 참여자가 없을 때 화면
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
              '등록된 여행 참여자가 없습니다.',
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

/// 참여자 목록 로딩 실패 화면
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
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: _mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                ),
                label: const Text(
                  '다시 시도',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}