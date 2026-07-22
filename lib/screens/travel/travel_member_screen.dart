import 'package:flutter/material.dart';

import '../../models/travel_member_model.dart';
import '../../services/travel_member_service.dart';

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
              title: const Text('여행 참여자 추가'),
              content: TextField(
                controller: nameController,
                autofocus: true,
                enabled: !isSaving,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '참여자 이름',
                  hintText: '예: 민수',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(
                    Icons.person_outline,
                  ),
                ),
                onSubmitted: (_) {
                  if (!isSaving) {
                    saveMember();
                  }
                },
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
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed:
                  isSaving ? null : saveMember,
                  child: isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('추가'),
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
              title: const Text('참여자 이름 수정'),
              content: TextField(
                controller: nameController,
                autofocus: true,
                enabled: !isSaving,
                maxLength: 20,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '참여자 이름',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (!isSaving) {
                    updateMember();
                  }
                },
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
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed:
                  isSaving ? null : updateMember,
                  child: isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('수정'),
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

    final bool? shouldDelete =
    await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('참여자 삭제'),
          content: Text(
            '${member.displayName} 님을 '
                '여행 참여자에서 삭제할까요?\n\n'
                '이 참여자가 결제한 경비가 있다면 '
                '정산 전에 결제자를 변경해야 합니다.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('삭제'),
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
          backgroundColor: isError
              ? Theme.of(context).colorScheme.error
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 참여자'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
        _isInitializing ? null : _showAddMemberDialog,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('참여자 추가'),
      ),
      body: _isInitializing
          ? const Center(
        child: CircularProgressIndicator(),
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
              child: CircularProgressIndicator(),
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
                    16,
                    8,
                    16,
                    100,
                  ),
                  itemCount: members.length,
                  separatorBuilder: (
                      BuildContext context,
                      int index,
                      ) {
                    return const SizedBox(height: 8);
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

class _MemberSummary extends StatelessWidget {
  final int memberCount;

  const _MemberSummary({
    required this.memberCount,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            backgroundColor:
            colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(
              Icons.groups_outlined,
              color: colorScheme.primary,
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
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$memberCount명',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
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
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: member.isOwner
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            member.isOwner
                ? Icons.person
                : Icons.person_outline,
            color: member.isOwner
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                member.displayName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '여행 생성자',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          member.userId.trim().isEmpty
              ? '비회원 참여자'
              : '회원 참여자',
        ),
        trailing: PopupMenuButton<String>(
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
                    Icon(Icons.edit_outlined),
                    SizedBox(width: 12),
                    Text('이름 수정'),
                  ],
                ),
              ),
              if (!member.isOwner)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.delete_outline),
                      SizedBox(width: 12),
                      Text('삭제'),
                    ],
                  ),
                ),
            ];
          },
        ),
      ),
    );
  }
}

class _EmptyMemberView extends StatelessWidget {
  const _EmptyMemberView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.group_off_outlined,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              '등록된 여행 참여자가 없습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              '참여자 목록을 불러오지 못했습니다.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}