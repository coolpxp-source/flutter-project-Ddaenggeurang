import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavTab _currentTab = NavTab.home;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D2247),
        foregroundColor: Colors.white,
        title: const Text('땡그랑',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
        // leading은 지정 안 해도 됨 — drawer가 있으면 Scaffold가
        // 햄버거 버튼을 자동으로 왼쪽에 넣어줌
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavBar(
        currentTab: _currentTab,
        onTabSelected: (tab) => setState(() => _currentTab = tab),
      ),
      body: _buildBody(uid),
    );
  }

  Widget _buildBody(String uid) {
    switch (_currentTab) {
      case NavTab.home:
        return _HomeDashboard(uid: uid);
      case NavTab.expense:
        return const _TabPlaceholder(title: '지출');
      case NavTab.aiConsult:
        return const _TabPlaceholder(title: 'AI상담');
      case NavTab.community:
        return const _TabPlaceholder(title: '커뮤니티');
      case NavTab.myPage:
        return const _TabPlaceholder(title: '마이');
    }
  }
}

/// 하단 탭 중 아직 화면이 없는 탭용 임시 바디
/// (Placeholder_screen.dart처럼 새 화면을 push하지 않고,
///  바텀네비 특성상 그 자리에서 body만 바뀌도록 구성)
class _TabPlaceholder extends StatelessWidget {
  final String title;
  const _TabPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title 화면 준비 중이에요',
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  final String uid;
  const _HomeDashboard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService().watchUser(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final user = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user.nickname}님, 환영해요!',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('${user.coachTone.emoji} ${user.coachTone.label} 코치가 함께해요',
                  style: const TextStyle(
                      fontSize: 15, color: Color(0xFF667085))),
              const SizedBox(height: 24),
              _InfoCard('레벨', 'Lv.${user.level}'),
              _InfoCard('포인트', '${user.points} P'),
              _InfoCard('월 수입', '${user.salary}원'),
              _InfoCard('연령대 / 직군', '${user.ageGroup} · ${user.job}'),
              const Spacer(),
              const Center(
                child: Text('🚧 홈 대시보드 개발 중',
                    style: TextStyle(color: Color(0xFF98A2B3))),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  const _InfoCard(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8ECF3)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF667085))),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}