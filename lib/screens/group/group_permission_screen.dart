import 'package:flutter/material.dart';
import 'shared_expense_list_screen.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';

class GroupPermissionScreen extends StatefulWidget {
  const GroupPermissionScreen({
    super.key,
    required this.group,
  });

  final GroupModel group;

  @override
  State<GroupPermissionScreen> createState() =>
      _GroupPermissionScreenState();
}

class _GroupPermissionScreenState
    extends State<GroupPermissionScreen> {

  final GroupService _groupService =
      GroupService.instance;

  List<Map<String, dynamic>> _members = [];

  bool _isLoadingMembers = true;
  bool _isChangingRole = false;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  // 그룹 멤버 권한 목록 조회 메서드
  Future<void> _loadMembers() async {
    try {
      final members = await _groupService.getGroupMembers(
        groupId: widget.group.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _members = members;
        _isLoadingMembers = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingMembers = false;
      });

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // 그룹 멤버 권한 변경 메서드
  Future<void> _changeRole(
      Map<String, dynamic> member,
      String newRole,
      ) async {
    if (member['role'] == 'owner') {
      _showMessage('그룹장은 권한을 변경할 수 없습니다.');
      return;
    }

    if (_isChangingRole) {
      return;
    }

    setState(() {
      _isChangingRole = true;
    });

    try {
      await _groupService.updateMemberRole(
        groupId: widget.group.id,
        memberId: member['userId'] as String,
        newRole: newRole,
      );

      await _loadMembers();

      if (!mounted) {
        return;
      }

      _showMessage(
        '${member['nickname']}님의 권한을 변경했습니다.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChangingRole = false;
        });
      }
    }
  }

  // 안내 메시지 표시 메서드
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return '그룹장';
      case 'editor':
        return '편집 가능';
      case 'viewer':
      default:
        return '조회만 가능';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return const Color(0xFFE66A9F);
      case 'editor':
        return const Color(0xFF8566FF);
      case 'viewer':
      default:
        return const Color(0xFF36BFA0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '권한 설정',
          style: TextStyle(
            color: Color(0xFF252735),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            32,
          ),
          children: [
            _buildGroupHeader(),
            const SizedBox(height: 20),
            _buildPermissionGuide(),
            const SizedBox(height: 20),
            _buildMemberSection(),
            const SizedBox(height: 20),
            _buildSharedExpenseButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFDCE9),
            Color(0xFFE8E0FF),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFFE66A9F),
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  widget.group.name,
                  style: const TextStyle(
                    color: Color(0xFF332A30),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '멤버 ${_members.length}명',
                  style: const TextStyle(
                    color: Color(0xFF786C72),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGuide() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFFDFBC),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE89B24),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              '편집 가능 멤버는 공동지출을 추가·수정할 수 있고, 조회 전용 멤버는 내역 확인만 할 수 있어요.',
              style: TextStyle(
                color: Color(0xFF8C8074),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '멤버 권한',
            style: TextStyle(
              color: Color(0xFF252735),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingMembers)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('그룹 멤버가 없습니다.'),
              ),
            )
          else
            ..._members.map(
                  (member) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildMemberCard(member),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSharedExpenseButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  SharedExpenseListScreen(
                    group: widget.group,
                  ),
            ),
          );
        },
        icon: const Icon(
          Icons.receipt_long_rounded,
        ),
        label: const Text(
          '공동 지출 내역 보기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
          const Color(0xFFE66A9F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildMemberCard(
      Map<String, dynamic> member,
      ) {
    final role = member['role'] as String;
    final isOwner = role == 'owner';
    final roleColor = _getRoleColor(role);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFE9EAF0),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
            roleColor.withValues(alpha: 0.12),
            child: Icon(
              isOwner
                  ? Icons.workspace_premium_rounded
                  : Icons.person_rounded,
              color: roleColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  member['nickname'] as String,
                  style: const TextStyle(
                    color: Color(0xFF252735),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _getRoleLabel(role),
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '그룹장',
                style: TextStyle(
                  color: Color(0xFFE66A9F),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (value) {
                _changeRole(member, value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'editor',
                  child: Text('편집 가능'),
                ),
                PopupMenuItem(
                  value: 'viewer',
                  child: Text('조회만 가능'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: roleColor.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getRoleLabel(role),
                      style: TextStyle(
                        color: roleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: roleColor,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}