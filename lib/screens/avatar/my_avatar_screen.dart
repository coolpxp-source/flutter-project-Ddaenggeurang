import 'package:flutter/material.dart';

import '../../models/avatar_item_model.dart';
import '../../services/avatar_service.dart';
import 'point_shop_screen.dart';
class MyAvatarScreen extends StatefulWidget {
  const MyAvatarScreen({super.key});

  @override
  State<MyAvatarScreen> createState() => _MyAvatarScreenState();
}

class _MyAvatarScreenState extends State<MyAvatarScreen> {
  final AvatarService _avatarService = AvatarService.instance;

  final List<String> _slots = [
    'hat',
    'clothes',
    'shoes',
    'accessory',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  int _points = 1250;
  int _level = 7;

  String _selectedSlot = 'hat';

  List<AvatarItem> _items = [];
  Future<void> _openPointShop() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PointShopScreen(),
      ),
    );

    await _reloadAvatarData();
  }

  @override
  void initState() {
    super.initState();
    _loadAvatarData();
  }

  Future<void> _loadAvatarData() async {
    final items = await _avatarService.getItems();
    final points = await _avatarService.getPoints();

    if (!mounted) return;

    setState(() {
      _items = items;
      _points = points;
      _isLoading = false;
    });
  }

  Future<void> _selectItem(AvatarItem item) async {
    final isLocked = _level < item.unlockLevel;

    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lv.${item.unlockLevel}부터 사용할 수 있습니다.',
          ),
        ),
      );
      return;
    }

    if (!item.isOwned) {
      await _showPurchaseDialog(item);
      return;
    }

    await _equipItem(item);
  }

  Future<void> _showPurchaseDialog(AvatarItem item) async {
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
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('구매'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await _avatarService.purchaseItem(item.id);

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이템 구매에 실패했습니다.'),
        ),
      );
      return;
    }

    await _reloadAvatarData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} 구매 완료!'),
      ),
    );
  }
  Future<void> _equipItem(AvatarItem item) async {
    final success = await _avatarService.equipItem(item.id);

    if (!mounted) {
      return;
    }

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('아이템 착용에 실패했습니다.'),
        ),
      );
      return;
    }

    await _reloadAvatarData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} 착용 완료!'),
      ),
    );
  }
  Future<void> _reloadAvatarData() async {
    final items = await _avatarService.getItems();
    final points = await _avatarService.getPoints();

    if (!mounted) {
      return;
    }

    setState(() {
      _items = items;
      _points = points;
      _isLoading = false;
    });
  }

  Future<void> _saveAvatar() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('현재 아바타가 저장되었습니다.'),
      ),
    );
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'hat':
        return '모자';
      case 'clothes':
        return '상의';
      case 'shoes':
        return '신발';
      case 'accessory':
        return '소품';
      default:
        return slot;
    }
  }

  IconData _slotIcon(String slot) {
    switch (slot) {
      case 'hat':
        return Icons.checkroom;
      case 'clothes':
        return Icons.dry_cleaning;
      case 'shoes':
        return Icons.ice_skating;
      case 'accessory':
        return Icons.auto_awesome;
      default:
        return Icons.star_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF4F5F8);
    const pinkColor = Color(0xFFFF66AE);
    const purpleColor = Color(0xFF8B63FF);
    const darkTextColor = Color(0xFF242737);

    final filteredItems = _items
        .where((item) => item.slot == _selectedSlot)
        .toList();

    final ownedCount = _items.where((item) => item.isOwned).length;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '아바타 꾸미기',
          style: TextStyle(
            color: darkTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F0FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🪙 $_points P',
                  style: const TextStyle(
                    color: purpleColor,
                    fontWeight: FontWeight.bold,
                  ),
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
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
        children: [
          _buildAvatarHeader(
            level: _level,
            ownedCount: ownedCount,
            pinkColor: pinkColor,
            purpleColor: purpleColor,
          ),
          const SizedBox(height: 18),
          _buildItemSection(
            filteredItems: filteredItems,
            pinkColor: pinkColor,
            purpleColor: purpleColor,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveAvatar,
              style: FilledButton.styleFrom(
                backgroundColor: pinkColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _isSaving ? '저장 중...' : '현재 아바타 저장하기',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildDailyMissionCard(
            pinkColor: pinkColor,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarHeader({
    required int level,
    required int ownedCount,
    required Color pinkColor,
    required Color purpleColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            pinkColor,
            purpleColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: purpleColor.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '태화님의 절약 캐릭터',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '저축왕 돼랑이',
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 62,
                  backgroundColor: Color(0xFFFFDBE9),
                  child: Icon(
                    Icons.pets,
                    size: 78,
                    color: Color(0xFF432C42),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '아바타 이미지 영역',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildStatBox(
                  label: '현재 레벨',
                  value: 'Lv. $level',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  label: '아이템 보유',
                  value: '$ownedCount개',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatBox(
                  label: '접속 기록',
                  value: '12일',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSection({
    required List<AvatarItem> filteredItems,
    required Color pinkColor,
    required Color purpleColor,
  }) {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '꾸미기 아이템',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openPointShop,
                child: Text(
                  '상점가기 >',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _slots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final isSelected = slot == _selectedSlot;

                return ChoiceChip(
                  label: Text(_slotLabel(slot)),
                  selected: isSelected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF202334),
                  backgroundColor: const Color(0xFFF1F2F6),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF777B89),
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedSlot = slot;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (filteredItems.isEmpty)
            const SizedBox(
              height: 170,
              child: Center(
                child: Text(
                  '해당 카테고리의 아이템이 없습니다.',
                  style: TextStyle(
                    color: Color(0xFF999CA7),
                  ),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredItems.length,
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.73,
              ),
              itemBuilder: (context, index) {
                final item = filteredItems[index];
                final isLocked = _level < item.unlockLevel;

                return InkWell(
                  onTap: () => _selectItem(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.isEquipped
                            ? pinkColor
                            : const Color(0xFFE8E9EF),
                        width: item.isEquipped ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                color: isLocked
                                    ? const Color(0xFFF0F1F4)
                                    : const Color(0xFFFFF0F6),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                isLocked
                                    ? Icons.lock_outline
                                    : _slotIcon(item.slot),
                                color: isLocked
                                    ? const Color(0xFFAEB0B8)
                                    : pinkColor,
                              ),
                            ),
                            if (item.isOwned)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF202334),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isLocked
                              ? 'Lv.${item.unlockLevel}'
                              : item.isEquipped
                              ? '착용 중'
                              : item.isOwned
                              ? '보유 중'
                              : '${item.price} P',
                          style: TextStyle(
                            color: item.isEquipped
                                ? pinkColor
                                : const Color(0xFF979AA5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDailyMissionCard({
    required Color pinkColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFDDB9),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE7C7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Color(0xFFE69A1F),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 아바타 미션',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '오늘 지출 1건을 기록하면 포인트를 받을 수 있어요.',
                  style: TextStyle(
                    color: Color(0xFF8E8277),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: const Color(0xFF202334),
              disabledForegroundColor: Colors.white,
            ),
            child: const Text('도전'),
          ),
        ],
      ),
    );
  }
}