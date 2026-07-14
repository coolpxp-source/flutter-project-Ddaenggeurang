class SharedExpenseModel {
  const SharedExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidByUserId,
    required this.paidByNickname,
    required this.category,
    required this.date,
    required this.createdAt,
    this.memo,
  });

  final String id;
  final String groupId;
  final String title;
  final int amount;
  final String paidByUserId;
  final String paidByNickname;
  final String category;
  final DateTime date;
  final DateTime createdAt;
  final String? memo;

  factory SharedExpenseModel.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return SharedExpenseModel(
      id: id,
      groupId: data['groupId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
      paidByUserId: data['paidByUserId'] as String? ?? '',
      paidByNickname:
      data['paidByNickname'] as String? ?? '',
      category: data['category'] as String? ?? '',
      date: data['date'] is DateTime
          ? data['date'] as DateTime
          : DateTime.now(),
      createdAt: data['createdAt'] is DateTime
          ? data['createdAt'] as DateTime
          : DateTime.now(),
      memo: data['memo'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidByUserId': paidByUserId,
      'paidByNickname': paidByNickname,
      'category': category,
      'date': date,
      'createdAt': createdAt,
      'memo': memo,
    };
  }
}