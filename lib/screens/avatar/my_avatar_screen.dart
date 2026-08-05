import 'package:flutter/material.dart';

import '../../models/avatar_item_model.dart';
import '../../services/avatar_service.dart';
import 'point_shop_screen.dart';
import '../../widgets/avatar/avatar_layered_character.dart';
import '../../widgets/common/app_snack_bar.dart';

class MyAvatarScreen extends StatefulWidget {
  const MyAvatarScreen({super.key});

  @override
  State<MyAvatarScreen> createState() => _MyAvatarScreenState();
}

class _MyAvatarScreenState extends State<MyAvatarScreen> {
  final AvatarService _avatarService = AvatarService.instance;
  // 사용자 안내 스낵바 표시 메서드
  void _showMessage(
      String message, {
        AppSnackBarType type = AppSnackBarType.info,
      }) {
    AppSnackBar.show(
      context,
      message: message,
      type: type,
    );
  }

  final List<String> _slots = [
    'hair',
    'clothes',
    'shoes',
    'accessory',
    'pet',
  ];

  bool _isLoading = true;

  int _points = 0;
  int _level = 1;

  String _nickname = '사용자';
  String _selectedSlot = 'hair';

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

  // 아바타 화면 데이터 조회 메서드
  Future<void> _loadAvatarData() async {
    final results = await Future.wait([
      _avatarService.getItems(),
      _avatarService.getPoints(),
      _avatarService.getLevel(),
      _avatarService.getNickname(),
    ]);

    if (!mounted) return;

    setState(() {
      _items = results[0] as List<AvatarItem>;
      _points = results[1] as int;
      _level = results[2] as int;
      _nickname = results[3] as String;
      _isLoading = false;
    });
  }

  // 희귀도 값을 한글 이름으로 변환하는 메서드
  String _rarityLabel(String rarity) {
    switch (rarity) {
      case 'common':
        return '일반';
      case 'uncommon':
        return '고급';
      case 'rare':
        return '희귀';
      case 'epic':
        return '영웅';
      case 'legendary':
        return '전설';
      default:
        return '일반';
    }
  }

  // 희귀도별 대표 색상을 반환하는 메서드
  Color _rarityColor(String rarity) {
    switch (rarity) {
      case 'common':
        return const Color(0xFF7A7D88);

      case 'uncommon':
        return const Color(0xFF2EA96B);

      case 'rare':
        return const Color(0xFF3C7DDF);

      case 'epic':
        return const Color(0xFF8A5AD9);

      case 'legendary':
        return const Color(0xFFD79B16);

      default:
        return const Color(0xFF7A7D88);
    }
  }

// 희귀도별 연한 배경색을 반환하는 메서드
  Color _rarityBackgroundColor(String rarity) {
    switch (rarity) {
      case 'common':
        return const Color(0xFFF2F3F5);

      case 'uncommon':
        return const Color(0xFFECFAF2);

      case 'rare':
        return const Color(0xFFEEF5FF);

      case 'epic':
        return const Color(0xFFF5F0FF);

      case 'legendary':
        return const Color(0xFFFFF7E4);

      default:
        return const Color(0xFFF2F3F5);
    }
  }

  // 아바타 아이템 선택 처리 메서드
  Future<void> _selectItem(AvatarItem item) async {
    final bool isLocked = _level < item.unlockLevel;

    if (isLocked) {
      _showMessage(
        'Lv.${item.unlockLevel}부터 사용할 수 있습니다.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (!item.isOwned) {
      _showMessage(
        '보유하지 않은 아이템입니다. 포인트 상점으로 이동합니다.',
        type: AppSnackBarType.info,
      );

      await _openPointShop();
      return;
    }

    if (item.isEquipped) {
      await _unequipItem(item);
      return;
    }

    await _equipItem(item);
  }

  // 아바타 아이템 착용 처리 메서드
  Future<void> _equipItem(AvatarItem item) async {
    try {
      final bool success =
      await _avatarService.equipItem(item.id);

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          '아이템 착용에 실패했습니다.',
          type: AppSnackBarType.error,
        );
        return;
      }

      await _reloadAvatarData();

      if (!mounted) {
        return;
      }

      _showMessage(
        '${item.name} 착용을 완료했습니다.',
        type: AppSnackBarType.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e
          .toString()
          .replaceFirst('Exception: ', '');

      _showMessage(
        message,
        type: AppSnackBarType.error,
      );
    }
  }

  // 현재 장착 중인 아바타 아이템을 해제하는 메서드
  Future<void> _unequipItem(AvatarItem item) async {
    try {
      final bool success =
      await _avatarService.unequipSlot(item.slot);

      if (!mounted) {
        return;
      }

      if (!success) {
        _showMessage(
          '아이템 해제에 실패했습니다.',
          type: AppSnackBarType.error,
        );
        return;
      }

      await _reloadAvatarData();

      if (!mounted) {
        return;
      }

      _showMessage(
        '${item.name} 아이템을 해제했습니다.',
        type: AppSnackBarType.success,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e
          .toString()
          .replaceFirst('Exception: ', '');

      _showMessage(
        message,
        type: AppSnackBarType.error,
      );
    }
  }

  // 아바타 화면 데이터 새로고침 메서드
  Future<void> _reloadAvatarData() async {
    await _avatarService.initializeDefaultAvatar();

    final results = await Future.wait([
      _avatarService.getPoints(),
      _avatarService.getLevel(),
      _avatarService.getItems(),
      _avatarService.getNickname(),
    ]);

    if (!mounted) return;

    setState(() {
      _points = results[0] as int;
      _level = results[1] as int;
      _items = results[2] as List<AvatarItem>;
      _nickname = results[3] as String;
      _isLoading = false;
    });
  }

  // 아바타 슬롯의 화면 표시 이름을 반환하는 메서드
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

  // 아바타 슬롯별 아이콘을 반환하는 메서드
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
        return Icons.star_outline;
    }
  }

  // 아이템 카드에 실제 이미지를 출력하는 메서드
  Widget _buildItemImage({
    required AvatarItem item,
    required Color pinkColor,
  }) {
    final imageUrl = item.imageUrl.trim();
    final assetPath = item.assetPath.trim();

    if (imageUrl.isNotEmpty) {
      return _buildItemPreview(
        item: item,
        image: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) {
            return _buildLocalItemImage(
              item: item,
              pinkColor: pinkColor,
            );
          },
        ),
      );
    }

    return _buildLocalItemImage(
      item: item,
      pinkColor: pinkColor,
    );
  }

// 로컬 에셋 또는 슬롯 아이콘을 출력하는 메서드
  Widget _buildLocalItemImage({
    required AvatarItem item,
    required Color pinkColor,
  }) {
    final assetPath = item.assetPath.trim();

    if (assetPath.isEmpty) {
      return Icon(
        _slotIcon(item.slot),
        color: pinkColor,
      );
    }

    return _buildItemPreview(
      item: item,
      image: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          return Icon(
            _slotIcon(item.slot),
            color: pinkColor,
          );
        },
      ),
    );
  }

// 1024×1024 에셋을 슬롯별로 확대해 보여주는 메서드
  Widget _buildItemPreview({
    required AvatarItem item,
    required Widget image,
  }) {
    double scale;
    Alignment alignment;

    switch (item.slot) {
      case 'hair':
        scale = 2.0;
        alignment = const Alignment(0, -0.85);
        break;

      case 'clothes':
        scale = 3.0;
        alignment = const Alignment(0, 0.4);
        break;

      case 'shoes':
        scale = 3.6;
        alignment = const Alignment(0, 0.90);
        break;

      case 'accessory':
        scale = 3.0;
        alignment = const Alignment(0, -0.4);
        break;

      case 'pet':
        scale = 2.8;
        alignment = const Alignment(0.9, 0.65);
        break;

      default:
        scale = 1;
        alignment = Alignment.center;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Transform.scale(
        scale: scale,
        alignment: alignment,
        child: SizedBox.expand(
          child: image,
        ),
      ),
    );
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
    final equippedCount = _items.where((item) => item.isEquipped).length;

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
            nickname: _nickname,
            level: _level,
            ownedCount: ownedCount,
            equippedCount: equippedCount,
            items: _items,
            pinkColor: pinkColor,
            purpleColor: purpleColor,
          ),
          const SizedBox(height: 18),
          _buildItemSection(
            filteredItems: filteredItems,
            pinkColor: pinkColor,
            purpleColor: purpleColor,
          ),
        ],
      ),
    );
  }

  // 아바타 사용자 정보 영역
  Widget _buildAvatarHeader({
    required String nickname,
    required int level,
    required int ownedCount,
    required int equippedCount,
    required Color pinkColor,
    required Color purpleColor, required List<AvatarItem> items,
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
          Text(
            '$nickname님의 절약 캐릭터',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '땡그랑 절약 메이트',
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
            child: Center(
              child: AvatarLayeredCharacter(
                items: _items,
                size: 180,
              ),
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
                  label: '착용 아이템',
                  value: '$equippedCount개',
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
                childAspectRatio: 0.62,
              ),
              itemBuilder: (context, index) {
                final AvatarItem item = filteredItems[index];
                final bool isLocked = _level < item.unlockLevel;

                final Color rarityColor =
                _rarityColor(item.rarity);

                final Color rarityBackgroundColor =
                _rarityBackgroundColor(item.rarity);

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
                            : rarityColor.withOpacity(
                          isLocked ? 0.35 : 0.8,
                        ),
                        width: item.isEquipped ? 2.2 : 1.4,
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
                                    : rarityBackgroundColor,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: isLocked ? 0.55 : 1,
                                    child: _buildItemImage(
                                      item: item,
                                      pinkColor: pinkColor,
                                    ),
                                  ),
                                  if (isLocked)
                                    const Icon(
                                      Icons.lock_outline,
                                      color: Color(0xFF8F929D),
                                      size: 25,
                                    ),
                                ],
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
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rarityBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: rarityColor.withOpacity(0.55),
                            ),
                          ),
                          child: Text(
                            _rarityLabel(item.rarity),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: rarityColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
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
}