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
                  fallbackAsset:
                  'assets/avatar/clothes/clothes_001_common.png',
                ),

                // Firestore에서 현재 착용한 신발 표시
                _buildItemLayer(
                  item: equippedShoes,
                  fallbackAsset:
                  'assets/avatar/shoes/shoes_001_common.png',
                ),

                // Firestore에서 현재 착용한 액세서리 표시
                _buildItemLayer(
                  item: equippedAccessory,
                  fallbackAsset:
                  'assets/avatar/accessory/accessory_001_common.png',
                ),

                // hair 슬롯 연결 전까지 common 헤어 고정 표시
                _buildItemLayer(
                  item: equippedHair,
                  fallbackAsset: 'assets/avatar/hair/hair_001_common.png',
                ),
              ],
            ),
          ),

          // pet 슬롯 연결 전까지 common 펫 고정 표시
          Positioned(
            right: 4,
            bottom: 0,
            child: _buildPetLayer(
              item: equippedPet,
              fallbackAsset: 'assets/avatar/pet/pet_001_common.png',
            ),
          ),
        ],
      ),
    );
  }

  // 장착 펫 이미지 또는 기본 로컬 펫 이미지를 출력하는 위젯
  Widget _buildPetLayer({
    required AvatarItem? item,
    required String fallbackAsset,
  }) {
    final imageUrl = item?.imageUrl.trim() ?? '';

    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: size * 0.9,
        height: size * 0.9,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) {
          return Image.asset(
            fallbackAsset,
            width: size * 0.9,
            height: size * 0.9,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          );
        },
      );
    }

    return Image.asset(
      fallbackAsset,
      width: size * 0.9,
      height: size * 0.9,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      errorBuilder: (_, _, _) {
        return const SizedBox.shrink();
      },
    );
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

  // 장착 아이템 이미지 또는 기본 로컬 이미지를 출력
  Widget _buildItemLayer({
    required AvatarItem? item,
    required String fallbackAsset,
  }) {
    final imageUrl = item?.imageUrl.trim() ?? '';

    if (imageUrl.isNotEmpty) {
      return Positioned.fill(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) {
            return Image.asset(
              fallbackAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            );
          },
        ),
      );
    }

    return _buildLocalAsset(fallbackAsset);
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