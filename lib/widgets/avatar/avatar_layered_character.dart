import 'package:flutter/material.dart';

import '../../models/avatar_item_model.dart';

class AvatarLayeredCharacter extends StatelessWidget {
  const AvatarLayeredCharacter({
    super.key,
    required this.items,
    this.size = 220,
  });

  final List<AvatarItem> items;
  final double size;

  @override
  Widget build(BuildContext context) {
    final equippedHair = _findEquippedItem('hair');
    final equippedClothes = _findEquippedItem('clothes');
    final equippedShoes = _findEquippedItem('shoes');
    final equippedAccessory = _findEquippedItem('accessory');
    final equippedPet = _findEquippedItem('pet');


    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 캐릭터 본체와 착용 파츠 레이어
          Positioned.fill(
            child: Stack(
              children: [
                _buildLocalAsset(
                  'assets/avatar/base/base_001.png',
                ),

                // Firestore에서 현재 착용한 의상 표시
                _buildItemLayer(
                  item: equippedClothes,
                ),

                // Firestore에서 현재 착용한 신발 표시
                _buildItemLayer(
                  item: equippedShoes,
                ),

                // Firestore에서 현재 착용한 액세서리 표시
                _buildItemLayer(
                  item: equippedAccessory,
                ),

                // hair 슬롯 연결 전까지 common 헤어 고정 표시
                _buildItemLayer(
                  item: equippedHair,
                ),
              ],
            ),
          ),

          // pet 슬롯 연결 전까지 common 펫 고정 표시
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildPetLayer(
              item: equippedPet,
            ),
          ),
        ],
      ),
    );
  }

  // 장착된 펫의 로컬 assetPath 또는 imageUrl 이미지를 출력하는 위젯
  Widget _buildPetLayer({
    required AvatarItem? item,
  }) {
    if (item == null) {
      return const SizedBox.shrink();
    }

    final imageUrl = item.imageUrl.trim();
    final assetPath = item.assetPath.trim();

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: size * 0.9,
        height: size * 0.9,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          if (assetPath.isEmpty) {
            return const SizedBox.shrink();
          }

          return Image.asset(
            assetPath,
            width: size * 0.9,
            height: size * 0.9,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          );
        },
      );
    }

    if (assetPath.isNotEmpty) {
      return Image.asset(
        assetPath,
        width: size * 0.9,
        height: size * 0.9,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          return const SizedBox.shrink();
        },
      );
    }

    return const SizedBox.shrink();
  }

  // 특정 슬롯에서 현재 착용 중인 아이템 조회
  AvatarItem? _findEquippedItem(String slot) {
    for (final item in items) {
      if (item.slot == slot && item.isEquipped) {
        return item;
      }
    }

    return null;
  }

  // 장착 아이템의 로컬 assetPath 또는 imageUrl 이미지를 출력하는 위젯
  Widget _buildItemLayer({
    required AvatarItem? item,
  }) {
    if (item == null) {
      return const SizedBox.shrink();
    }

    final imageUrl = item.imageUrl.trim();
    final assetPath = item.assetPath.trim();

    // 외부 이미지가 있으면 우선 사용
    if (imageUrl.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) {
            if (assetPath.isEmpty) {
              return const SizedBox.shrink();
            }

            return Image.asset(
              assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            );
          },
        ),
      );
    }

    // 로컬 assetPath가 있으면 사용
    if (assetPath.isNotEmpty) {
      return Positioned.fill(
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) {
            return const SizedBox.shrink();
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // 로컬 아바타 파츠 이미지를 동일한 캔버스로 출력
  Widget _buildLocalAsset(String path) {
    return Positioned.fill(
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          return const SizedBox.shrink();
        },
      ),
    );
  }
}