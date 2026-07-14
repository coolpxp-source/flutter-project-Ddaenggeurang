import 'package:flutter/material.dart';

import '../../models/group_model.dart';
import '../../services/group_service.dart';
import 'group_permission_screen.dart';

class GroupCreateJoinScreen extends StatefulWidget {
  const GroupCreateJoinScreen({super.key});

  @override
  State<GroupCreateJoinScreen> createState() =>
      _GroupCreateJoinScreenState();
}

class _GroupCreateJoinScreenState
    extends State<GroupCreateJoinScreen> {
  final GroupService _groupService = GroupService.instance;

  final TextEditingController _groupNameController =
  TextEditingController();

  final TextEditingController _descriptionController =
  TextEditingController();

  final TextEditingController _inviteCodeController =
  TextEditingController();

  List<GroupModel> _myGroups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _descriptionController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _loadGroups() {
    setState(() {
      _myGroups = _groupService.getMyGroups();
    });
  }

  void _createGroup() {
    final groupName = _groupNameController.text.trim();
    final description = _descriptionController.text.trim();

    if (groupName.isEmpty) {
      _showMessage('그룹 이름을 입력해 주세요.');
      return;
    }

    final createdGroup = _groupService.createGroup(
      name: groupName,
      description: description.isEmpty
          ? null
          : description,
    );

    _groupNameController.clear();
    _descriptionController.clear();

    _loadGroups();

    FocusScope.of(context).unfocus();

    _showCreatedGroupDialog(createdGroup);
  }

  void _joinGroup() {
    final inviteCode =
    _inviteCodeController.text.trim();

    if (inviteCode.isEmpty) {
      _showMessage('초대 코드를 입력해 주세요.');
      return;
    }

    final joinedGroup = _groupService.joinGroup(
      inviteCode: inviteCode,
    );

    if (joinedGroup == null) {
      _showMessage('유효하지 않은 초대 코드입니다.');
      return;
    }

    _inviteCodeController.clear();

    _loadGroups();

    FocusScope.of(context).unfocus();

    _showMessage(
      '${joinedGroup.name} 그룹에 참여했습니다.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showCreatedGroupDialog(
      GroupModel group,
      ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '그룹 생성 완료',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: Color(0xFFE66A9F),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                group.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      '초대 코드',
                      style: TextStyle(
                        color: Color(0xFF8B737D),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      group.inviteCode,
                      style: const TextStyle(
                        color: Color(0xFFE66A9F),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '함께 관리할 사람에게 초대 코드를 알려주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF777A86),
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Color(0xFFE66A9F),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
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
          '공동 관리',
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
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildCreateGroupCard(),
            const SizedBox(height: 18),
            _buildJoinGroupCard(),
            const SizedBox(height: 22),
            _buildMyGroupsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFDCE9),
            Color(0xFFE8E0FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.groups_rounded,
              color: Color(0xFFE66A9F),
              size: 34,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  '함께 관리하면 더 쉬워요',
                  style: TextStyle(
                    color: Color(0xFF332A30),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  '가족, 친구와 그룹을 만들고\n공동 지출을 함께 관리해 보세요.',
                  style: TextStyle(
                    color: Color(0xFF786C72),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateGroupCard() {
    return _buildSectionCard(
      title: '새 그룹 만들기',
      subtitle: '내가 관리할 새로운 그룹을 만들어요.',
      icon: Icons.add_circle_outline_rounded,
      child: Column(
        children: [
          TextField(
            controller: _groupNameController,
            maxLength: 30,
            decoration: _inputDecoration(
              hintText: '그룹 이름을 입력해 주세요.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLength: 100,
            maxLines: 3,
            decoration: _inputDecoration(
              hintText:
              '그룹 설명을 입력해 주세요. (선택)',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                const Color(0xFFE66A9F),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '그룹 생성하기',
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

  Widget _buildJoinGroupCard() {
    return _buildSectionCard(
      title: '초대 코드로 참여하기',
      subtitle: '전달받은 초대 코드를 입력해 주세요.',
      icon: Icons.login_rounded,
      child: Column(
        children: [
          TextField(
            controller: _inviteCodeController,
            textCapitalization:
            TextCapitalization.characters,
            decoration: _inputDecoration(
              hintText: '예: DDANG123',
              prefixIcon: const Icon(
                Icons.key_rounded,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _joinGroup,
              style: OutlinedButton.styleFrom(
                foregroundColor:
                const Color(0xFF8566FF),
                side: const BorderSide(
                  color: Color(0xFFCFC4FF),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '그룹 참여하기',
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

  Widget _buildMyGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '내 그룹',
                style: TextStyle(
                  color: Color(0xFF252735),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_myGroups.length}개',
              style: const TextStyle(
                color: Color(0xFF999CA7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_myGroups.isEmpty)
          _buildEmptyGroupCard()
        else
          ..._myGroups.map(
                (group) => Padding(
              padding:
              const EdgeInsets.only(bottom: 12),
              child: _buildGroupCard(group),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupCard(GroupModel group) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupPermissionScreen(
              group: group,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE9E7EF),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color:
                const Color(0xFFF0EDFF),
                borderRadius:
                BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: Color(0xFF8566FF),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      color: Color(0xFF252735),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    group.description ??
                        '그룹 설명이 없습니다.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF92949E),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: Color(0xFF999CA7),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${group.memberCount}명',
                        style: const TextStyle(
                          color: Color(0xFF777A86),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        Icons.key_rounded,
                        color: Color(0xFF999CA7),
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        group.inviteCode,
                        style: const TextStyle(
                          color: Color(0xFF777A86),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFB0B2BB),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyGroupCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.group_off_outlined,
            color: Color(0xFFB5B7C0),
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            '참여 중인 그룹이 없어요.',
            style: TextStyle(
              color: Color(0xFF777A86),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
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
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFFFEEF4),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color:
                  const Color(0xFFE66A9F),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color:
                        Color(0xFF252735),
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color:
                        Color(0xFF92949E),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      counterText: '',
      filled: true,
      fillColor: const Color(0xFFF8F8FA),
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE8E8EE),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE66A9F),
          width: 1.5,
        ),
      ),
    );
  }
}