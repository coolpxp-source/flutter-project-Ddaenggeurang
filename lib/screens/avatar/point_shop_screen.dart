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
  final AvatarService _avatarService = AvatarService.instance;

  final List<String> _slots = [
    'hair',
    'clothes',
    'shoes',
    'accessory',
    'pet',
  ];


  int _points = 0;
  int _userLevel = 1;
  String _selectedSlot = 'hair';
  bool _isLoading = true;

  List<AvatarItem> _items = [];
  Widget _buildPointSummaryCard() {
    const pinkColor = Color(0xFFFF68AE);
    const purpleColor = Color(0xFF8566FF);

    final ownedCount = _items.where((item) => item.isOwned).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            pinkColor,
            purpleColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
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
            '현재 보유 포인트',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$_points P',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildShopStatBox(
                  label: '현재 레벨',
                  value: 'Lv. $_userLevel',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildShopStatBox(
                  label: '보유 아이템',
                  value: '$ownedCount개',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            '미션으로 포인트를 모아 나만의 아바타를 꾸며보세요.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopStatBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
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

  // 슬롯별 아이콘을 반환하는 메서드
  IconData _slotIcon(String slot) {
    switch (slot) {
      case 'hair':
        return Icons.face_retouching_natural;
      case 'clothes':
        return Icons.dry_cleaning;
      case 'shoes':
        return Icons.ice_skating;
      case 'accessory':
        return Icons.auto_awesome;
      case 'pet':
        return Icons.pets;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  // 아바타 상점 데이터 조회 메서드
  Future<void> _loadShop() async {
    final results = await Future.wait([
      _avatarService.getPoints(),
      _avatarService.getLevel(),
      _avatarService.getItems(),
    ]);

    if (!mounted) return;

    setState(() {
      _points = results[0] as int;
      _userLevel = results[1] as int;
      _items = results[2] as List<AvatarItem>;
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
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF68AE),
                        Color(0xFF8566FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: _buildPurchaseItemImage(item),
                ),
                const SizedBox(height: 18),
                const Text(
                  '아이템 구매',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF252735),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF454754),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.price} P',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8566FF),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '구매 후 남은 포인트: ${_points - item.price} P',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92949E),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6F727E),
                          side: const BorderSide(
                            color: Color(0xFFE3E4E9),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF68AE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '구매하기',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) return;

    final success = await _avatarService.purchaseItem(item.id);

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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // 구매 팝업에 아이템 실제 이미지를 출력하는 메서드
  Widget _buildPurchaseItemImage(AvatarItem item) {
    final imageUrl = item.imageUrl.trim();
    final assetPath = item.assetPath.trim();

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          return _buildPurchaseAssetOrIcon(item);
        },
      );
    }

    return _buildPurchaseAssetOrIcon(item);
  }

// 구매 팝업에 로컬 에셋 또는 기본 아이콘을 출력하는 메서드
  Widget _buildPurchaseAssetOrIcon(AvatarItem item) {
    if (item.assetPath.trim().isNotEmpty) {
      return Image.asset(
        item.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          return Icon(
            _slotIcon(item.slot),
            color: Colors.white,
            size: 36,
          );
        },
      );
    }

    return Icon(
      _slotIcon(item.slot),
      color: Colors.white,
      size: 36,
    );
  }

  // 슬롯별 한글 이름을 반환하는 메서드
  String _slotLabel(String slot) {
    switch (slot) {
      case 'hair':
        return '헤어';
      case 'clothes':
        return '의상';
      case 'shoes':
        return '신발';
      case 'accessory':
        return '소품';
      case 'pet':
        return '펫';
      default:
        return slot;
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF7F8F7);

    final filteredItems = _items
        .where((item) => item.slot == _selectedSlot)
        .toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '아바타 상점',
          style: TextStyle(
            color: Color(0xFF252735),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _buildPointSummaryCard(),
          const SizedBox(height: 20),

          const Row(
            children: [
              Expanded(
                child: Text(
                  '아이템 카테고리',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2D3A),
                  ),
                ),
              ),
              Text(
                '원하는 부위를 선택하세요',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9699A4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _slots.length,
              separatorBuilder: (context, index) {
                return const SizedBox(width: 8);
              },
              itemBuilder: (context, index) {
                final slot = _slots[index];
                final isSelected = slot == _selectedSlot;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedSlot = slot;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF252735)
                          : const Color(0xFFF0F1F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF252735)
                            : const Color(0xFFE5E6EB),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _slotIcon(slot),
                          size: 17,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF7E818C),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _slotLabel(slot),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF737681),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              childAspectRatio: 0.74,
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