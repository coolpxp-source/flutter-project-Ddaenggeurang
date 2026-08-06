import 'package:flutter/material.dart';

/// 실제 화면(screens/)이 아직 없는 메뉴를 위한 임시 화면.
/// 나중에 진짜 화면 만들면 app_drawer.dart에서
/// destinationScreen: PlaceholderScreen(title: '지출 입력')
/// 이 부분을 destinationScreen: const ExpenseInputScreen() 으로 바꿔치기만 하면 됨.
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          '$title 화면 준비 중이에요',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}