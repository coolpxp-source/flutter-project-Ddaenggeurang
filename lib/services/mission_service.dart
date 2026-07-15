import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mission_definition_model.dart';

class MissionService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    return user.uid;
  }

  Future<List<MissionDefinition>> getMissions() async {
    final snapshot = await _firestore
        .collection('missionDefinitions')
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.map((doc) {
      return MissionDefinition.fromMap(
        doc.id,
        doc.data(),
      );
    }).toList();
  }

  Future<Map<String, Map<String, dynamic>>> getMissionProgress() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('missionProgress')
        .get();

    return {
      for (final doc in snapshot.docs)
        doc.id: doc.data(),
    };
  }

  Future<bool> checkAttendance() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    return true;
  }


}