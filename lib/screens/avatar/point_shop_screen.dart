import 'package:flutter/material.dart';

import '../../models/avatar_item_model.dart';
import '../../services/avatar_service.dart';
import '../../widgets/avatar/avatar_item_card.dart';

class PointShopScreen extends StatefulWidget {
  const PointShopScreen({super.key});

  @override
  State<PointShopScreen> createState() => _PointShopScreenState();
}

class _PointShopScreenState extends State<PointShopScreen> {
  final AvatarService _avatarService = AvatarService();

  final List<String> _slots = [
    'hat',
    'clothes',
    'shoes',
    'accessory',
  ];

  int _points = 0;
  int _userLevel = 2;
  String _selectedSlot = 'hat';
  bool _isLoading = true;

  List<AvatarItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final points = await _avatarService.getPoints();
    final items = await _avatarService.getItems();

    if (!mounted) return;

    setState(() {
      _points = points;
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _purchaseItem(AvatarItem item) async {
    if (item.isOwned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이미 보유 중인 아이템입니다.'),
        ),
      );
      return;
    }

    if (_points < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('포인트가 부족합니다.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('아이템 구매'),
          content: Text(
            '${item.name}을(를) ${item.price}P에 구매할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('구매'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final success = await _avatarService.purchaseItem(item);

    if (!mounted) return;

    if (success) {
      setState(() {
        _points -= item.price;

        final index = _items.indexWhere(
              (avatarItem) => avatarItem.id == item.id,
        );

        if (index != -1) {
          _items[index] = item.copyWith(isOwned: true);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} 구매 완료!'),
        ),
      );
    }
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'hat':
        return '모자';
      case 'clothes':
        return '옷';
      case 'shoes':
        return '신발';
      case 'accessory':
        return '소품';
      default:
        return slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF20A67A);
    const backgroundColor = Color(0xFFF7F8F7);

    final filteredItems = _items
        .where((item) => item.slot == _selectedSlot)
        .toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          '아바타 상점',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Center(
              child: Text(
                '$_points P',
                style: const TextStyle(
                  color: primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF8F3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lv.$_userLevel · 기본 모자 착용중',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF53615C),
                    ),
                  ),
                ),
                Text(
                  '아이템 ${_items.where((item) => item.isOwned).length}개 보유',
                  style: const TextStyle(
                    color: Color(0xFF82908A),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _slots.length,
              separatorBuilder: (_, _) =>
              const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final isSelected = slot == _selectedSlot;

                return ChoiceChip(
                  label: Text(_slotLabel(slot)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedSlot = slot;
                    });
                  },
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF727E79),
                    fontWeight: FontWeight.bold,
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredItems.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final item = filteredItems[index];

              return AvatarItemCard(
                item: item,
                userLevel: _userLevel,
                onTap: () => _purchaseItem(item),
              );
            },
          ),
        ],
      ),
    );
  }
}