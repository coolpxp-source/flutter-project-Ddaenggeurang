import 'package:flutter/material.dart';

/// 코치 캐릭터(땡구/땡쥐/땡냥이) 아바타 — assets/images의 실제 캐릭터 그림을
/// 원형으로 잘라 보여준다. 기존에 이모지를 넣던 원형 컨테이너 안에
/// 그대로 대체해 넣을 수 있도록 크기만 받는다.
class CoachAvatar extends StatelessWidget {
  final String imagePath;
  final double size;
  const CoachAvatar({super.key, required this.imagePath, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        imagePath,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
