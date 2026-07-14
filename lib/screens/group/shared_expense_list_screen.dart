import 'package:flutter/material.dart';

import '../../models/group_model.dart';
import '../../models/shared_expense_model.dart';
import '../../services/group_service.dart';

class SharedExpenseListScreen extends StatefulWidget {
  const SharedExpenseListScreen({
    super.key,
    required this.group,
  });

  final GroupModel group;

  @override
  State<SharedExpenseListScreen> createState() =>
      _SharedExpenseListScreenState();
}

class _SharedExpenseListScreenState
    extends State<SharedExpenseListScreen> {
  final GroupService _groupService =
      GroupService.instance;

  List<SharedExpenseModel> _expenses = [];
  int _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  void _loadExpenses() {
    setState(() {
      _expenses =
          _groupService.getSharedExpenses(
            groupId: widget.group.id,
          );

      _totalAmount =
          _groupService.getSharedExpenseTotal(
            groupId: widget.group.id,
          );
    });
  }

  String _formatAmount(int amount) {
    final text = amount.toString();
    final buffer = StringBuffer();

    for (int index = 0; index < text.length; index++) {
      final positionFromEnd =
          text.length - index;

      buffer.write(text[index]);

      if (positionFromEnd > 1 &&
          positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  String _formatDate(DateTime date) {
    return '${date.month}월 ${date.day}일';
  }

  IconData _getCategoryIcon(
      String category,
      ) {
    switch (category) {
      case '식비':
        return Icons.restaurant_rounded;
      case '고정비':
        return Icons.receipt_long_rounded;
      case '생활비':
      default:
        return Icons.shopping_cart_rounded;
    }
  }

  Color _getCategoryColor(
      String category,
      ) {
    switch (category) {
      case '식비':
        return const Color(0xFFFFA94D);
      case '고정비':
        return const Color(0xFF8566FF);
      case '생활비':
      default:
        return const Color(0xFFE66A9F);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '공동 지출',
          style: TextStyle(
            color: Color(0xFF252735),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                '공동지출 등록 기능은 다음 단계에서 연결합니다.',
              ),
            ),
          );
        },
        backgroundColor:
        const Color(0xFFE66A9F),
        foregroundColor: Colors.white,
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          '지출 추가',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            18,
            18,
            100,
          ),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildExpenseSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
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
        borderRadius:
        BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            widget.group.name,
            style: const TextStyle(
              color: Color(0xFF786C72),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이번 달 공동 지출',
            style: TextStyle(
              color: Color(0xFF332A30),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${_formatAmount(_totalAmount)}원',
            style: const TextStyle(
              color: Color(0xFF252735),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(alpha: 0.65),
              borderRadius:
              BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFFE66A9F),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '총 ${_expenses.length}건의 공동 지출',
                  style: const TextStyle(
                    color: Color(0xFF655A5F),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseSection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '지출 내역',
                style: TextStyle(
                  color: Color(0xFF252735),
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_expenses.length}건',
              style: const TextStyle(
                color: Color(0xFF999CA7),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_expenses.isEmpty)
          _buildEmptyState()
        else
          ..._expenses.map(
                (expense) => Padding(
              padding:
              const EdgeInsets.only(
                bottom: 12,
              ),
              child:
              _buildExpenseCard(
                expense,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpenseCard(
      SharedExpenseModel expense,
      ) {
    final color =
    _getCategoryColor(
      expense.category,
    );

    return InkWell(
      onTap: () {
        debugPrint(
          '공동지출 선택: ${expense.id}',
        );
      },
      borderRadius:
      BorderRadius.circular(20),
      child: Container(
        padding:
        const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.circular(20),
          border: Border.all(
            color:
            const Color(0xFFE9E7EF),
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
                color.withValues(
                  alpha: 0.12,
                ),
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),
              child: Icon(
                _getCategoryIcon(
                  expense.category,
                ),
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          expense.title,
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF252735,
                            ),
                            fontSize: 15,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                      Text(
                        '${_formatAmount(expense.amount)}원',
                        style:
                        const TextStyle(
                          color:
                          Color(
                            0xFF252735,
                          ),
                          fontSize: 15,
                          fontWeight:
                          FontWeight
                              .w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Row(
                    children: [
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration:
                        BoxDecoration(
                          color:
                          color.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            10,
                          ),
                        ),
                        child: Text(
                          expense.category,
                          style:
                          TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          '${expense.paidByNickname} · ${_formatDate(expense.date)}',
                          style:
                          const TextStyle(
                            color:
                            Color(
                              0xFF92949E,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (expense.memo != null &&
                      expense
                          .memo!.isNotEmpty) ...[
                    const SizedBox(
                      height: 7,
                    ),
                    Text(
                      expense.memo!,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        color:
                        Color(
                          0xFF777A86,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        vertical: 40,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: Color(0xFFB5B7C0),
            size: 44,
          ),
          SizedBox(height: 12),
          Text(
            '아직 등록된 공동 지출이 없어요.',
            style: TextStyle(
              color: Color(0xFF777A86),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}