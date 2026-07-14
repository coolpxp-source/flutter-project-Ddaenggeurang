import '../models/group_model.dart';
import '../models/shared_expense_model.dart';
class GroupService {
  GroupService._();

  List<SharedExpenseModel> getSharedExpenses({
    required String groupId,
  }) {
    final expenses = _sharedExpenses
        .where(
          (expense) => expense.groupId == groupId,
    )
        .toList();

    expenses.sort(
          (a, b) => b.date.compareTo(a.date),
    );

    return List.unmodifiable(expenses);
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

  Future<void> addSharedExpense(SharedExpenseModel expense) async {
    await Future.delayed(const Duration(milliseconds: 300));

    _sharedExpenses.add(expense);
  }

  void deleteSharedExpense({
    required String expenseId,
  }) {
    _sharedExpenses.removeWhere(
          (expense) => expense.id == expenseId,
    );
  }

  void updateSharedExpense(
      SharedExpenseModel updatedExpense,
      ) {
    final index = _sharedExpenses.indexWhere(
          (expense) => expense.id == updatedExpense.id,
    );
    if (index == -1) {
      return;
    }
    _sharedExpenses[index] = updatedExpense;
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

  List<GroupModel> getMyGroups() {
    return List.unmodifiable(_groups);
  }

  GroupModel createGroup({
    required String name,
    String? description,
  }) {
    final group = GroupModel(
      id: 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      inviteCode: _generateInviteCode(),
      ownerId: 'mock_user_001',
      memberCount: 1,
      createdAt: DateTime.now(),
      description: description,
    );

    _groups.add(group);

    return group;
  }

  GroupModel? joinGroup({
    required String inviteCode,
  }) {
    final normalizedCode = inviteCode.trim().toUpperCase();

    for (int index = 0; index < _groups.length; index++) {
      final group = _groups[index];

      if (group.inviteCode == normalizedCode) {
        final updatedGroup = group.copyWith(
          memberCount: group.memberCount + 1,
        );

        _groups[index] = updatedGroup;

        return updatedGroup;
      }
    }

    return null;
  }

  String _generateInviteCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = timestamp.substring(timestamp.length - 6);

    return 'DDANG$suffix';
  }
}