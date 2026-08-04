import 'package:flutter/material.dart';

import '../../models/avatar_item_model.dart';

class AvatarItemCard extends StatelessWidget {
  final AvatarItem item;
  final int userLevel;
  final VoidCallback? onTap;

  const AvatarItemCard({
    super.key,
    required this.item,
    required this.userLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const pinkColor = Color(0xFFFF68AE);
    const purpleColor = Color(0xFF8566FF);

    final bool isLocked = userLevel < item.unlockLevel;
    final Color rarityColor = _rarityColor(item.rarity);
    final Color rarityBackgroundColor =
    _rarityBackgroundColor(item.rarity);

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isEquipped
                ? pinkColor
                : rarityColor.withOpacity(
              isLocked ? 0.35 : 0.8,
            ),
            width: item.isEquipped ? 2.2 : 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _buildStatusBadge(
                isLocked: isLocked,
                pinkColor: pinkColor,
              ),
            ),
            const SizedBox(height: 4),

            // 실제 아바타 아이템 이미지를 출력하는 영역
            Container(
              width: 82,
              height: 82,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: isLocked
                    ? const Color(0xFFF1F2F5)
                    : rarityBackgroundColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isLocked ? 0.6 : 1,
                    child: _buildItemImage(
                      pinkColor: pinkColor,
                    ),
                  ),
                  if (isLocked)
                    const Icon(
                      Icons.lock_outline,
                      size: 29,
                      color: Color(0xFF8F929D),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: rarityBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: rarityColor.withOpacity(0.55),
                ),
              ),
              child: Text(
                _rarityLabel(item.rarity),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: rarityColor,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              item.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isLocked
                    ? const Color(0xFFB2B4BC)
                    : const Color(0xFF343644),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _buildBottomText(isLocked),
              style: TextStyle(
                color: isLocked
                    ? const Color(0xFFB9BBC2)
                    : item.isOwned
                    ? pinkColor
                    : purpleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // imageUrl, assetPath, 기본 아이콘 순서로 아이템 이미지를 출력하는 메서드
  Widget _buildItemImage({
    required Color pinkColor,
  }) {
    final imageUrl = item.imageUrl.trim();
    final assetPath = item.assetPath.trim();

    if (imageUrl.isNotEmpty) {
      return _buildPreviewTransform(
        Image.network(
          imageUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) {
            return _buildAssetOrIcon(
              assetPath: assetPath,
              pinkColor: pinkColor,
            );
          },
        ),
      );
    }

    return _buildAssetOrIcon(
      assetPath: assetPath,
      pinkColor: pinkColor,
    );
  }

// 로컬 에셋 또는 슬롯 기본 아이콘을 출력하는 메서드
  Widget _buildAssetOrIcon({
    required String assetPath,
    required Color pinkColor,
  }) {
    if (assetPath.isNotEmpty) {
      return _buildPreviewTransform(
        Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, error, _) {
            debugPrint('아바타 에셋 로드 실패: $assetPath');
            debugPrint('$error');

            return Icon(
              _getIcon(item.slot),
              size: 34,
              color: pinkColor,
            );
          },
        ),
      );
    }

    return Icon(
      _getIcon(item.slot),
      size: 34,
      color: pinkColor,
    );
  }

// 슬롯별 미리보기 위치와 확대 비율을 적용하는 메서드
  Widget _buildPreviewTransform(Widget image) {
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
      borderRadius: BorderRadius.circular(14),
      child: Transform.scale(
        scale: scale,
        alignment: alignment,
        child: SizedBox.expand(
          child: image,
        ),
      ),
    );
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

  // 잠금, 착용, 보유 상태 배지를 출력하는 메서드
  Widget _buildStatusBadge({
    required bool isLocked,
    required Color pinkColor,
  }) {
    if (isLocked) {
      return const Text(
        '잠김',
        style: TextStyle(
          color: Color(0xFFB6B8C0),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (item.isEquipped) {
      return Text(
        '착용중',
        style: TextStyle(
          color: pinkColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (item.isOwned) {
      return const Text(
        '보유중',
        style: TextStyle(
          color: Color(0xFF6E7180),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return const SizedBox(height: 14);
  }

  // 아이템 상태에 따른 하단 문구를 반환하는 메서드
  String _buildBottomText(bool isLocked) {
    if (isLocked) {
      return 'Lv.${item.unlockLevel} 해금';
    }

    if (item.isOwned) {
      return '보유중';
    }

    return '${item.price} P';
  }

  // 슬롯별 기본 아이콘을 반환하는 메서드
  IconData _getIcon(String slot) {
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
}