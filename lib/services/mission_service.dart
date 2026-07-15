import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
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

  Future<bool> isTodayAttendanceCompleted() async {
    final now = DateTime.now();

    final dateId =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('attendanceRecords')
        .doc(dateId)
        .get();

    return snapshot.exists;
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
    try {
      final now = DateTime.now();

      final dateId =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';

      final userRef = _firestore
          .collection('users')
          .doc(_currentUserId);

      final missionRef = _firestore
          .collection('missionDefinitions')
          .doc('attendance');

      final attendanceRecordRef = userRef
          .collection('attendanceRecords')
          .doc(dateId);

      final progressRef = userRef
          .collection('missionProgress')
          .doc('attendance');

      await _firestore.runTransaction(
            (transaction) async {
          final userSnapshot =
          await transaction.get(userRef);

          final missionSnapshot =
          await transaction.get(missionRef);

          final attendanceRecordSnapshot =
          await transaction.get(attendanceRecordRef);

          final progressSnapshot =
          await transaction.get(progressRef);

          if (!userSnapshot.exists ||
              !missionSnapshot.exists) {
            throw StateError(
              '사용자 또는 출석 미션 정보가 없습니다.',
            );
          }

          if (attendanceRecordSnapshot.exists) {
            throw StateError(
              '오늘은 이미 출석했습니다.',
            );
          }

          final userData =
          userSnapshot.data()!;

          final missionData =
          missionSnapshot.data()!;

          final currentPoints =
              (userData['points'] as num?)
                  ?.toInt() ??
                  0;

          final rewardPoints =
              (missionData['points'] as num?)
                  ?.toInt() ??
                  0;

          int totalPointsEarned = rewardPoints;

          if (progressSnapshot.exists) {
            final progressData =
            progressSnapshot.data();

            final previousPointsEarned =
                (progressData?['pointsEarned'] as num?)
                    ?.toInt() ??
                    0;

            totalPointsEarned =
                previousPointsEarned +
                    rewardPoints;
          }

          transaction.set(
            attendanceRecordRef,
            {
              'missionDefId': 'attendance',
              'checkedAt':
              FieldValue.serverTimestamp(),
              'pointsEarned':
              rewardPoints,
            },
          );

          transaction.set(
            progressRef,
            {
              'status': 'in_progress',
              'completedAt':
              FieldValue.serverTimestamp(),
              'pointsEarned':
              totalPointsEarned,
              'proofImageUrl': null,
              'approvalStatus': null,
            },
            SetOptions(
              merge: true,
            ),
          );

          transaction.update(
            userRef,
            {
              'points':
              currentPoints +
                  rewardPoints,
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
          );
        },
      );

      return true;
    } catch (e) {
      debugPrint(
        '출석 체크 실패: $e',
      );

      return false;
    }
  }
}