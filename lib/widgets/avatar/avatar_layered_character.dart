import 'package:flutter/material.dart';

class AvatarLayeredCharacter extends StatelessWidget {
  const AvatarLayeredCharacter({
    super.key,
    this.size = 220,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 기본 몸체
          _buildAsset('assets/avatar/base/base_001.png'),

          // 헤어
          _buildAsset('assets/avatar/hair/hair_001_common.png'),

          // 의상
          _buildAsset('assets/avatar/clothes/clothes_001_common.png'),

          // 신발
          _buildAsset('assets/avatar/shoes/shoes_001_common.png'),

          // 모자
          _buildAsset('assets/avatar/hat/hat_001_common.png'),

          // 액세서리
          _buildAsset('assets/avatar/accessory/accessory_001_common.png'),
        ],
      ),
    );
  }

  // 아바타 파츠 이미지를 동일 크기로 출력하는 위젯
  Widget _buildAsset(String path) {
    return Positioned.fill(
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
      ),
    );
  }
}