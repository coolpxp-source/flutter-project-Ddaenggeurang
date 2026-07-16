import 'dart:math';

import '../models/group_model.dart';
import '../models/shared_expense_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  GroupService._();

  // Firestore 접근 객체
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

// 현재 로그인 사용자 확인 객체
  final FirebaseAuth _auth =
      FirebaseAuth.instance;

// 현재 로그인 사용자 UID 반환
  String get _currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    return user.uid;
  }

  // 그룹 공동지출 목록 조회 메서드
  Future<List<SharedExpenseModel>> getSharedExpenses({
    required String groupId,
  }) async {
    if (groupId.trim().isEmpty) {
      throw Exception('그룹 정보가 올바르지 않습니다.');
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('sharedExpenses')
        .orderBy(
      'date',
      descending: true,
    )
        .get();

    return snapshot.docs.map(
          (document) {
        return SharedExpenseModel.fromMap(
          document.id,
          document.data(),
        );
      },
    ).toList();
  }

  int getSharedExpenseTotal({
    required String groupId,
  }) {
    return _sharedExpenses
        .where(
          (expense) => expense.groupId == groupId,
    )
        .fold<int>(
      0,
          (total, expense) => total + expense.amount,
    );
  }

  static final GroupService instance = GroupService._();

  final List<SharedExpenseModel> _sharedExpenses = [
    SharedExpenseModel(
      id: 'expense_001',
      groupId: 'group_001',
      title: '마트 장보기',
      amount: 68500,
      paidByUserId: 'mock_user_001',
      paidByNickname: '이태화',
      category: '생활비',
      date: DateTime(2026, 7, 14),
      createdAt: DateTime(2026, 7, 14, 18, 30),
      memo: '주말 장보기',
    ),
    SharedExpenseModel(
      id: 'expense_002',
      groupId: 'group_001',
      title: '배달 음식',
      amount: 32000,
      paidByUserId: 'mock_user_002',
      paidByNickname: '절약왕김땡',
      category: '식비',
      date: DateTime(2026, 7, 13),
      createdAt: DateTime(2026, 7, 13, 20, 10),
    ),
    SharedExpenseModel(
      id: 'expense_003',
      groupId: 'group_001',
      title: '인터넷 요금',
      amount: 38500,
      paidByUserId: 'mock_user_003',
      paidByNickname: '통장지킴이',
      category: '고정비',
      date: DateTime(2026, 7, 10),
      createdAt: DateTime(2026, 7, 10, 9, 0),
    ),
  ];

  // 공동지출 추가 메서드
  Future<void> addSharedExpense({
    required String groupId,
    required String title,
    required int amount,
    required String paidByNickname,
    required String category,
    required DateTime date,
    String? memo,
  }) async {
    final String userId = _currentUserId;

    if (groupId.trim().isEmpty) {
      throw Exception('그룹 정보가 올바르지 않습니다.');
    }

    if (title.trim().isEmpty) {
      throw Exception('지출 제목을 입력해 주세요.');
    }

    if (amount <= 0) {
      throw Exception('지출 금액은 0원보다 커야 합니다.');
    }

    if (paidByNickname.trim().isEmpty) {
      throw Exception('결제자를 입력해 주세요.');
    }

    final DocumentReference<Map<String, dynamic>> groupRef =
    _firestore.collection('groups').doc(groupId);

    final DocumentSnapshot<Map<String, dynamic>> groupDocument =
    await groupRef.get();

    if (!groupDocument.exists) {
      throw Exception('그룹 정보를 찾을 수 없습니다.');
    }

    final Map<String, dynamic> groupData =
        groupDocument.data() ?? {};

    final List<String> memberIds = List<String>.from(
      groupData['memberIds'] as List? ?? <String>[],
    );

    if (!memberIds.contains(userId)) {
      throw Exception('해당 그룹의 멤버만 공동지출을 등록할 수 있습니다.');
    }

    final DocumentReference<Map<String, dynamic>> expenseRef =
    groupRef.collection('sharedExpenses').doc();

    await expenseRef.set({
      'groupId': groupId,
      'title': title.trim(),
      'amount': amount,
      'paidByUserId': userId,
      'paidByNickname': paidByNickname.trim(),
      'category': category,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      'memo': memo?.trim().isEmpty == true
          ? null
          : memo?.trim(),
    });
  }

  // 공동지출 삭제 메서드
  Future<void> deleteSharedExpense({
    required String groupId,
    required String expenseId,
  }) async {
    final String userId = _currentUserId;

    if (groupId.trim().isEmpty ||
        expenseId.trim().isEmpty) {
      throw Exception('공동지출 정보가 올바르지 않습니다.');
    }

    final DocumentReference<Map<String, dynamic>> groupRef =
    _firestore.collection('groups').doc(groupId);

    final DocumentSnapshot<Map<String, dynamic>> groupDocument =
    await groupRef.get();

    if (!groupDocument.exists) {
      throw Exception('그룹 정보를 찾을 수 없습니다.');
    }

    final Map<String, dynamic> groupData =
        groupDocument.data() ?? {};

    final List<String> memberIds = List<String>.from(
      groupData['memberIds'] as List? ?? <String>[],
    );

    if (!memberIds.contains(userId)) {
      throw Exception('해당 그룹의 멤버만 공동지출을 삭제할 수 있습니다.');
    }

    final DocumentReference<Map<String, dynamic>> expenseRef =
    groupRef
        .collection('sharedExpenses')
        .doc(expenseId);

    final DocumentSnapshot<Map<String, dynamic>> expenseDocument =
    await expenseRef.get();

    if (!expenseDocument.exists) {
      throw Exception('공동지출 정보를 찾을 수 없습니다.');
    }

    await expenseRef.delete();
  }

  // 공동지출 수정 메서드
  Future<void> updateSharedExpense({
    required String groupId,
    required String expenseId,
    required String title,
    required int amount,
    required String paidByNickname,
    required String category,
    required DateTime date,
    String? memo,
  }) async {
    final String userId = _currentUserId;

    if (groupId.trim().isEmpty ||
        expenseId.trim().isEmpty) {
      throw Exception('공동지출 정보가 올바르지 않습니다.');
    }

    if (title.trim().isEmpty) {
      throw Exception('지출 제목을 입력해 주세요.');
    }

    if (amount <= 0) {
      throw Exception('지출 금액은 0원보다 커야 합니다.');
    }

    if (paidByNickname.trim().isEmpty) {
      throw Exception('결제자를 입력해 주세요.');
    }

    final DocumentReference<Map<String, dynamic>> groupRef =
    _firestore.collection('groups').doc(groupId);

    final DocumentSnapshot<Map<String, dynamic>> groupDocument =
    await groupRef.get();

    if (!groupDocument.exists) {
      throw Exception('그룹 정보를 찾을 수 없습니다.');
    }

    final Map<String, dynamic> groupData =
        groupDocument.data() ?? {};

    final List<String> memberIds = List<String>.from(
      groupData['memberIds'] as List? ?? <String>[],
    );

    if (!memberIds.contains(userId)) {
      throw Exception('해당 그룹의 멤버만 공동지출을 수정할 수 있습니다.');
    }

    final DocumentReference<Map<String, dynamic>> expenseRef =
    groupRef
        .collection('sharedExpenses')
        .doc(expenseId);

    final DocumentSnapshot<Map<String, dynamic>> expenseDocument =
    await expenseRef.get();

    if (!expenseDocument.exists) {
      throw Exception('공동지출 정보를 찾을 수 없습니다.');
    }

    await expenseRef.update({
      'title': title.trim(),
      'amount': amount,
      'paidByNickname': paidByNickname.trim(),
      'category': category,
      'date': Timestamp.fromDate(date),
      'memo': memo?.trim().isEmpty == true
          ? null
          : memo?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  final List<GroupModel> _groups = [
    GroupModel(
      id: 'group_001',
      name: '우리 가족 생활비',
      inviteCode: 'DDANG123',
      ownerId: 'mock_user_001',
      memberCount: 3,
      createdAt: DateTime(2026, 7, 1),
      description: '가족 공동 생활비를 관리하는 그룹입니다.',
    ),
  ];

  // 그룹 멤버 및 권한 조회 메서드
  Future<List<Map<String, dynamic>>> getGroupMembers({
    required String groupId,
  }) async {
    final String userId = _currentUserId;

    final groupDocument = await _firestore
        .collection('groups')
        .doc(groupId)
        .get();

    if (!groupDocument.exists) {
      throw Exception('그룹 정보를 찾을 수 없습니다.');
    }

    final groupData = groupDocument.data() ?? {};

    final List<String> memberIds = List<String>.from(
      groupData['memberIds'] as List? ?? <String>[],
    );

    if (!memberIds.contains(userId)) {
      throw Exception('해당 그룹의 멤버만 접근할 수 있습니다.');
    }

    final String ownerId =
        groupData['ownerId'] as String? ?? '';

    final Map<String, dynamic> memberRoles =
    Map<String, dynamic>.from(
      groupData['memberRoles'] as Map? ?? <String, dynamic>{},
    );

    final List<Map<String, dynamic>> members = [];

    for (final memberId in memberIds) {
      final userDocument = await _firestore
          .collection('users')
          .doc(memberId)
          .get();

      final userData = userDocument.data() ?? {};

      members.add({
        'userId': memberId,
        'nickname':
        userData['nickname'] as String? ?? '알 수 없는 사용자',
        'role': memberId == ownerId
            ? 'owner'
            : memberRoles[memberId] as String? ?? 'viewer',
      });
    }

    members.sort((a, b) {
      if (a['role'] == 'owner') {
        return -1;
      }

      if (b['role'] == 'owner') {
        return 1;
      }

      return (a['nickname'] as String).compareTo(
        b['nickname'] as String,
      );
    });

    return members;
  }

  // 그룹 멤버 권한 변경 메서드
  Future<void> updateMemberRole({
    required String groupId,
    required String memberId,
    required String newRole,
  }) async {
    final String userId = _currentUserId;

    if (newRole != 'editor' &&
        newRole != 'viewer') {
      throw Exception('올바르지 않은 권한입니다.');
    }

    final groupRef =
    _firestore.collection('groups').doc(groupId);

    final groupDocument = await groupRef.get();

    if (!groupDocument.exists) {
      throw Exception('그룹 정보를 찾을 수 없습니다.');
    }

    final groupData = groupDocument.data() ?? {};

    final String ownerId =
        groupData['ownerId'] as String? ?? '';

    if (ownerId != userId) {
      throw Exception('그룹장만 권한을 변경할 수 있습니다.');
    }

    if (memberId == ownerId) {
      throw Exception('그룹장의 권한은 변경할 수 없습니다.');
    }

    final List<String> memberIds = List<String>.from(
      groupData['memberIds'] as List? ?? <String>[],
    );

    if (!memberIds.contains(memberId)) {
      throw Exception('그룹 멤버를 찾을 수 없습니다.');
    }

    await groupRef.update({
      'memberRoles.$memberId': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 현재 사용자가 참여한 그룹 목록 조회 메서드
  Future<List<GroupModel>> getMyGroups() async {
    final snapshot = await _firestore
        .collection('groups')
        .where(
      'memberIds',
      arrayContains: _currentUserId,
    )
        .get();

    final groups = snapshot.docs.map(
          (document) {
        return GroupModel.fromMap(
          document.id,
          document.data(),
        );
      },
    ).toList();

    groups.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return groups;
  }

  // 새 그룹 생성 메서드
  Future<GroupModel> createGroup({
    required String name,
    String? description,
  }) async {
    final String userId = _currentUserId;

    final DocumentReference<Map<String, dynamic>> groupRef =
    _firestore.collection('groups').doc();

    final String inviteCode = _generateInviteCode();

    final Map<String, dynamic> data = {
      'name': name.trim(),
      'description': description?.trim(),
      'ownerId': userId,
      'inviteCode': inviteCode,
      'memberIds': <String>[userId],
      'memberRoles': <String, String>{
        userId: 'owner',
      },
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await groupRef.set(data);

    final DocumentSnapshot<Map<String, dynamic>> createdDocument =
    await groupRef.get();

    return GroupModel.fromMap(
      createdDocument.id,
      createdDocument.data() ?? {},
    );
  }

  // 그룹 초대코드 생성 메서드
  String _generateInviteCode() {
    const String characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random();

    return List.generate(
      6,
          (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  // 초대코드로 그룹 참여 메서드
  Future<GroupModel> joinGroup({
    required String inviteCode,
  }) async {
    final String userId = _currentUserId;
    final String normalizedCode =
    inviteCode.trim().toUpperCase();

    if (normalizedCode.isEmpty) {
      throw Exception('초대코드를 입력해 주세요.');
    }

    // 초대코드에 해당하는 그룹 조회
    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('groups')
        .where(
      'inviteCode',
      isEqualTo: normalizedCode,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('유효하지 않은 초대코드입니다.');
    }

    final DocumentReference<Map<String, dynamic>> groupRef =
        snapshot.docs.first.reference;

    // 그룹 참여 정보 갱신
    await _firestore.runTransaction(
          (transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> groupDocument =
        await transaction.get(groupRef);

        if (!groupDocument.exists) {
          throw Exception('그룹 정보를 찾을 수 없습니다.');
        }

        final Map<String, dynamic> data =
            groupDocument.data() ?? {};

        final List<String> memberIds =
        List<String>.from(
          data['memberIds'] as List? ?? <String>[],
        );

        if (memberIds.contains(userId)) {
          throw Exception('이미 참여 중인 그룹입니다.');
        }

        transaction.update(
          groupRef,
          {
            'memberIds': FieldValue.arrayUnion(
              <String>[userId],
            ),
            'memberRoles.$userId': 'viewer',
            'memberCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      },
    );

    // 갱신된 그룹 정보 다시 조회
    final DocumentSnapshot<Map<String, dynamic>> updatedDocument =
    await groupRef.get();

    return GroupModel.fromMap(
      updatedDocument.id,
      updatedDocument.data() ?? {},
    );
  }
}