import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import '../models/mission_definition_model.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class MissionService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    return user.uid;
  }

  String _formatSubmittedAt(
      Timestamp? timestamp,
      ) {
    if (timestamp == null) {
      return '';
    }

    final date = timestamp.toDate();

    final month =
    date.month.toString().padLeft(2, '0');

    final day =
    date.day.toString().padLeft(2, '0');

    final hour =
    date.hour.toString().padLeft(2, '0');

    final minute =
    date.minute.toString().padLeft(2, '0');

    return '$month월 $day일 $hour:$minute';
  }

  Future<List<Map<String, dynamic>>> getRecentMissionRewards() async {
    final rewards = <Map<String, dynamic>>[];

    final attendanceSnapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('attendanceRecords')
        .orderBy(
      'checkedAt',
      descending: true,
    )
        .limit(5)
        .get();

    for (final doc in attendanceSnapshot.docs) {
      final data = doc.data();

      final checkedAt =
      data['checkedAt'] as Timestamp?;

      final pointsEarned =
          (data['pointsEarned'] as num?)?.toInt() ?? 0;

      rewards.add({
        'type': 'attendance',
        'title': '일일 출석',
        'date': checkedAt,
        'points': pointsEarned,
      });
    }

    final progressSnapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('missionProgress')
        .where(
      'status',
      isEqualTo: 'completed',
    )
        .get();

    for (final doc in progressSnapshot.docs) {
      if (doc.id == 'attendance') {
        continue;
      }

      final data = doc.data();

      final completedAt =
      data['completedAt'] as Timestamp?;

      final pointsEarned =
          (data['pointsEarned'] as num?)?.toInt() ?? 0;

      if (completedAt == null || pointsEarned <= 0) {
        continue;
      }

      final missionSnapshot = await _firestore
          .collection('missionDefinitions')
          .doc(doc.id)
          .get();

      final title =
          missionSnapshot.data()?['title']
          as String? ??
              doc.id;

      rewards.add({
        'type': doc.id,
        'title': title,
        'date': completedAt,
        'points': pointsEarned,
      });
    }

    rewards.sort((a, b) {
      final aDate =
      a['date'] as Timestamp?;

      final bDate =
      b['date'] as Timestamp?;

      if (aDate == null && bDate == null) {
        return 0;
      }

      if (aDate == null) {
        return 1;
      }

      if (bDate == null) {
        return -1;
      }

      return bDate.compareTo(aDate);
    });

    return rewards.take(5).toList();
  }

  Future<Set<int>> getMonthlyAttendanceDays({
    required int year,
    required int month,
  }) async {
    final startDate =
    DateTime(year, month, 1);

    final endDate =
    DateTime(year, month + 1, 1);

    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('attendanceRecords')
        .where(
      'checkedAt',
      isGreaterThanOrEqualTo:
      Timestamp.fromDate(startDate),
    )
        .where(
      'checkedAt',
      isLessThan:
      Timestamp.fromDate(endDate),
    )
        .get();

    return snapshot.docs
        .map((doc) {
      final checkedAt =
      doc.data()['checkedAt'] as Timestamp?;

      return checkedAt?.toDate().day;
    })
        .whereType<int>()
        .toSet();
  }

  Future<String?> getMissionApprovalStatus(
      String missionDefId,
      ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('missionProgress')
        .doc(missionDefId)
        .get();

    return snapshot.data()?['approvalStatus'] as String?;
  }

  Future<Map<String, dynamic>?> getMissionProgressData(
      String missionDefId,
      ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('missionProgress')
        .doc(missionDefId)
        .get();

    return snapshot.data();
  }

  Future<bool> rejectMissionVerification({
    required String verificationId,
    required String reason,
  }) async {
    try {
      final verificationRef = _firestore
          .collection('missionVerifications')
          .doc(verificationId);

      await _firestore.runTransaction(
            (transaction) async {
          final verificationSnapshot =
          await transaction.get(verificationRef);

          if (!verificationSnapshot.exists) {
            throw StateError(
              '인증 정보를 찾을 수 없습니다.',
            );
          }

          final verificationData =
          verificationSnapshot.data()!;

          final approvalStatus =
              verificationData['approvalStatus']
              as String? ??
                  '';

          if (approvalStatus != 'pending') {
            throw StateError(
              '이미 처리된 인증입니다.',
            );
          }

          final userId =
              verificationData['userId']
              as String? ??
                  '';

          final missionDefId =
              verificationData['missionDefId']
              as String? ??
                  '';

          if (userId.isEmpty ||
              missionDefId.isEmpty) {
            throw StateError(
              '사용자 또는 미션 정보가 올바르지 않습니다.',
            );
          }

          final progressRef = _firestore
              .collection('users')
              .doc(userId)
              .collection('missionProgress')
              .doc(missionDefId);

          transaction.update(
            verificationRef,
            {
              'approvalStatus': 'rejected',
              'approvedAt': null,
              'rejectedAt':
              FieldValue.serverTimestamp(),
              'rejectionReason': reason,
            },
          );

          transaction.set(
            progressRef,
            {
              'status': 'in_progress',
              'completedAt': null,
              'pointsEarned': 0,
              'approvalStatus': 'rejected',
              'rejectionReason': reason,
            },
            SetOptions(
              merge: true,
            ),
          );
        },
      );

      return true;
    } catch (e) {
      debugPrint(
        '미션 인증 반려 실패: $e',
      );

      return false;
    }
  }

  Future<bool> approveMissionVerification(
      String verificationId,
      ) async {
    try {
      final verificationRef = _firestore
          .collection('missionVerifications')
          .doc(verificationId);

      await _firestore.runTransaction(
            (transaction) async {
          final verificationSnapshot =
          await transaction.get(verificationRef);

          if (!verificationSnapshot.exists) {
            throw StateError(
              '인증 정보를 찾을 수 없습니다.',
            );
          }

          final verificationData =
          verificationSnapshot.data()!;

          final approvalStatus =
              verificationData['approvalStatus']
              as String? ??
                  '';

          if (approvalStatus != 'pending') {
            throw StateError(
              '이미 처리된 인증입니다.',
            );
          }

          final userId =
              verificationData['userId']
              as String? ??
                  '';

          final missionDefId =
              verificationData['missionDefId']
              as String? ??
                  '';

          if (userId.isEmpty ||
              missionDefId.isEmpty) {
            throw StateError(
              '사용자 또는 미션 정보가 올바르지 않습니다.',
            );
          }

          final userRef = _firestore
              .collection('users')
              .doc(userId);

          final missionRef = _firestore
              .collection('missionDefinitions')
              .doc(missionDefId);

          final progressRef = userRef
              .collection('missionProgress')
              .doc(missionDefId);

          final userSnapshot =
          await transaction.get(userRef);

          final missionSnapshot =
          await transaction.get(missionRef);

          if (!userSnapshot.exists ||
              !missionSnapshot.exists) {
            throw StateError(
              '사용자 또는 미션 정보를 찾을 수 없습니다.',
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

          transaction.update(
            verificationRef,
            {
              'approvalStatus': 'approved',
              'approvedAt':
              FieldValue.serverTimestamp(),
              'rejectedAt': null,
              'rejectionReason': null,
            },
          );

          transaction.set(
            progressRef,
            {
              'status': 'completed',
              'completedAt':
              FieldValue.serverTimestamp(),
              'pointsEarned': rewardPoints,
              'approvalStatus': 'approved',
            },
            SetOptions(
              merge: true,
            ),
          );

          transaction.update(
            userRef,
            {
              'points':
              currentPoints + rewardPoints,
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
          );
        },
      );

      return true;
    } catch (e) {
      debugPrint(
        '미션 인증 승인 실패: $e',
      );

      return false;
    }
  }

  Future<List<Map<String, dynamic>>>
  getPendingMissionVerifications() async {
    final snapshot = await _firestore
        .collection('missionVerifications')
        .where(
      'approvalStatus',
      isEqualTo: 'pending',
    )
        .orderBy(
      'submittedAt',
      descending: true,
    )
        .get();

    final proofs =
    <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final userId =
          data['userId'] as String? ?? '';

      String nickname = '알 수 없는 사용자';

      if (userId.isNotEmpty) {
        final userSnapshot = await _firestore
            .collection('users')
            .doc(userId)
            .get();

        nickname =
            userSnapshot.data()?['nickname']
            as String? ??
                '알 수 없는 사용자';
      }

      final submittedAt =
      data['submittedAt'] as Timestamp?;

      proofs.add({
        'id': doc.id,
        'userId': userId,
        'nickname': nickname,
        'missionDefId':
        data['missionDefId'] as String? ?? '',
        'missionTitle':
        data['missionTitle'] as String? ?? '',
        'description':
        data['proofDescription'] as String? ?? '',
        'submittedAt':
        _formatSubmittedAt(submittedAt),
        'status':
        data['approvalStatus'] as String? ??
            'pending',
        'imageUrl':
        data['proofImageUrl'] as String? ?? '',
      });
    }

    return proofs;
  }

  Future<bool> submitMissionProof({
    required String missionDefId,
    required XFile image,
    required String description,
  }) async {
    try {
      final userId = _currentUserId;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final extension =
      image.path.split('.').last.toLowerCase();

      final storageRef = _storage
          .ref()
          .child(
        'missionProofs/'
            '$userId/'
            '$missionDefId/'
            '$timestamp.$extension',
      );

      await storageRef.putFile(
        File(image.path),
      );

      final downloadUrl =
      await storageRef.getDownloadURL();

      final missionRef = _firestore
          .collection('missionDefinitions')
          .doc(missionDefId);

      final missionSnapshot =
      await missionRef.get();

      if (!missionSnapshot.exists) {
        throw StateError(
          '미션 정보를 찾을 수 없습니다.',
        );
      }

      final missionData =
      missionSnapshot.data()!;

      final missionTitle =
          missionData['title'] as String? ?? '';

      final progressRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('missionProgress')
          .doc(missionDefId);

      final verificationRef = _firestore
          .collection('missionVerifications')
          .doc();

      final batch = _firestore.batch();

      batch.set(
        progressRef,
        {
          'status': 'in_progress',
          'completedAt': null,
          'pointsEarned': 0,
          'proofImageUrl': downloadUrl,
          'proofDescription': description,
          'approvalStatus': 'pending',
          'verificationId': verificationRef.id,
          'submittedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      batch.set(
        verificationRef,
        {
          'userId': userId,
          'missionDefId': missionDefId,
          'missionTitle': missionTitle,
          'proofImageUrl': downloadUrl,
          'proofDescription': description,
          'approvalStatus': 'pending',
          'submittedAt':
          FieldValue.serverTimestamp(),
          'approvedAt': null,
          'rejectedAt': null,
          'rejectionReason': null,
        },
      );

      await batch.commit();

      return true;
    } catch (e) {
      debugPrint(
        '미션 인증 제출 실패: $e',
      );
      return false;
    }
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