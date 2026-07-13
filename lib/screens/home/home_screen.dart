import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
      ),
      body: StreamBuilder<UserModel?>(
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
      ),
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