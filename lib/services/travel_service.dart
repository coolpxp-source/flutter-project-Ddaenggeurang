import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/travel_model.dart';

class TravelService {
  // 여행 생성자를 포함한 최대 참여 인원
  static const int maxTravelMembers = 10;

  TravelService({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _travelCollection {
    return _db.collection('travels');
  }

  /// 여행 생성
  Future<String> addTravel(TravelModel travel) async {
    if (travel.userId.trim().isEmpty) {
      throw ArgumentError('사용자 정보가 없습니다.');
    }

    if (travel.title.trim().isEmpty) {
      throw ArgumentError('여행 제목을 입력해주세요.');
    }

    if (travel.endDate.isBefore(travel.startDate)) {
      throw ArgumentError('여행 종료일은 시작일보다 빠를 수 없습니다.');
    }

    try {
      final document = _travelCollection.doc();

      await document.set({
        'travelId': document.id,
        'userId': travel.userId,
        'title': travel.title.trim(),
        'startDate': Timestamp.fromDate(travel.startDate),
        'endDate': Timestamp.fromDate(travel.endDate),
        'budgetAmount': travel.budgetAmount,
        'isActive': travel.isActive,

        // 생성자도 여행 참여자에 포함
        'memberIds': <String>[travel.userId],

        // 초대 수락 전 회원
        'pendingMemberIds': <String>[],

        // 생성자 포함 최대 10명
        'maxMembers': maxTravelMembers,

        'isDeleted': false,
        'deletedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 생성 성공: ${document.id}');
      return document.id;
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError('여행 생성 실패', error, stackTrace);
      rethrow;
    }
  }

  /// 생성하거나 참여 중인 여행 목록을 실시간으로 조회한다.
  ///
  /// Firestore에서는 memberIds 배열에 현재 회원 UID가 포함되어 있는지만
  /// 조회하고, 소프트 삭제 여부와 시작일 최신순 정렬은 Flutter에서 처리한다.
  ///
  /// 위 조건에 startDate orderBy까지 함께 사용하면 Firestore 복합 색인이
  /// 필요해진다. 별도의 색인을 만들지 않아도 동작하도록 Firestore 쿼리에서는
  /// orderBy를 사용하지 않고, 조회 결과를 Flutter에서 시작일 최신순으로 정렬한다.
  Stream<List<TravelModel>> getTravelsByUserId(String userId) {
    final String normalizedUserId = userId.trim();

    // 로그인 UID가 없으면 Firestore를 조회하지 않고 빈 목록을 반환한다.
    if (normalizedUserId.isEmpty) {
      return Stream<List<TravelModel>>.value(
        <TravelModel>[],
      );
    }

    return _travelCollection
        .where(
      'memberIds',
      arrayContains: normalizedUserId,
    )
        .snapshots()
        .map((snapshot) {
      final List<TravelModel> travels = snapshot.docs
          .map(TravelModel.fromFirestore)
      // 삭제된 여행은 Firestore 복합 조건 대신 앱에서 제외한다.
          .where(
            (TravelModel travel) => !travel.isDeleted,
      )
          .toList();

      // Firestore orderBy 대신 앱에서 여행 시작일 최신순으로 정렬한다.
      travels.sort(
            (
            TravelModel first,
            TravelModel second,
            ) {
          return second.startDate.compareTo(
            first.startDate,
          );
        },
      );

      return travels;
    });
  }

  /// 현재 회원이 직접 생성한 여행만 실시간으로 조회한다.
  ///
  /// 이 쿼리도 복합 색인 오류를 방지하기 위해 Flutter에서 최신순으로 정렬한다.
  Stream<List<TravelModel>> getOwnedTravels(String userId) {
    final String normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return Stream<List<TravelModel>>.value(
        <TravelModel>[],
      );
    }

    return _travelCollection
        .where(
      'userId',
      isEqualTo: normalizedUserId,
    )
        .snapshots()
        .map((snapshot) {
      final List<TravelModel> travels = snapshot.docs
          .map(TravelModel.fromFirestore)
          .where(
            (TravelModel travel) => !travel.isDeleted,
      )
          .toList();

      travels.sort(
            (
            TravelModel first,
            TravelModel second,
            ) {
          return second.startDate.compareTo(
            first.startDate,
          );
        },
      );

      return travels;
    });
  }

  /// 나에게 온 여행 초대 목록
  Stream<List<TravelModel>> getPendingInvitations(
      String userId,
      ) {
    if (userId.trim().isEmpty) {
      return Stream<List<TravelModel>>.value([]);
    }

    return _travelCollection
        .where(
      'pendingMemberIds',
      arrayContains: userId,
    )
        .snapshots()
        .map((snapshot) {
      final travels = snapshot.docs
          .map(TravelModel.fromFirestore)
      // 삭제된 여행은 앱에서 제외해 복합 색인 생성을 피한다.
          .where(
            (TravelModel travel) => !travel.isDeleted,
      )
          .toList();

      travels.sort(
            (a, b) => b.startDate.compareTo(a.startDate),
      );

      return travels;
    });
  }

  /// 여행 한 건 조회
  Future<TravelModel?> getTravelById(String travelId) async {
    if (travelId.trim().isEmpty) {
      return null;
    }

    try {
      final document =
      await _travelCollection.doc(travelId).get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      final travel = TravelModel.fromFirestore(document);

      if (travel.isDeleted) {
        return null;
      }

      return travel;
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 단건 조회 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 회원을 여행에 초대
  ///
  /// 초대를 수락하기 전에는 pendingMemberIds에 저장한다.
  Future<void> inviteMember({
    required String travelId,
    required String ownerId,
    required String invitedUserId,
  }) async {
    final normalizedTravelId = travelId.trim();
    final normalizedOwnerId = ownerId.trim();
    final normalizedInvitedUserId = invitedUserId.trim();

    if (normalizedTravelId.isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('여행 생성자 정보가 없습니다.');
    }

    if (normalizedInvitedUserId.isEmpty) {
      throw ArgumentError('초대할 회원 정보가 없습니다.');
    }

    if (normalizedOwnerId == normalizedInvitedUserId) {
      throw StateError('여행 생성자는 초대할 수 없습니다.');
    }

    final reference =
    _travelCollection.doc(normalizedTravelId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);

        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('여행 정보를 찾을 수 없습니다.');
        }

        final travel = TravelModel.fromFirestore(snapshot);

        if (travel.isDeleted) {
          throw StateError('삭제된 여행입니다.');
        }

        if (!travel.isOwner(normalizedOwnerId)) {
          throw StateError('여행 생성자만 회원을 초대할 수 있습니다.');
        }

        if (travel.isMember(normalizedInvitedUserId)) {
          throw StateError('이미 여행에 참여한 회원입니다.');
        }

        if (travel.isPendingMember(normalizedInvitedUserId)) {
          throw StateError('이미 초대한 회원입니다.');
        }

        // 기존에 최대 8명으로 저장된 여행도 10명 기준으로 계산한다.
        final Map<String, dynamic> data = snapshot.data()!;
        final List<dynamic> memberIds =
            data['memberIds'] as List<dynamic>? ?? <dynamic>[];
        final List<dynamic> pendingMemberIds =
            data['pendingMemberIds'] as List<dynamic>? ?? <dynamic>[];

        final Set<String> reservedMemberIds = <String>{
          ...memberIds.map((dynamic id) => id.toString()),
          ...pendingMemberIds.map((dynamic id) => id.toString()),
        };

        if (reservedMemberIds.length >= maxTravelMembers) {
          throw StateError(
            '여행 인원은 생성자를 포함하여 '
                '$maxTravelMembers명까지 추가할 수 있습니다.',
          );
        }

        transaction.update(reference, {
          'pendingMemberIds': FieldValue.arrayUnion(
            [normalizedInvitedUserId],
          ),
          // 예전에 생성된 8명 제한 문서도 자동으로 10명으로 변경
          'maxMembers': maxTravelMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('여행 회원 초대 성공: $normalizedInvitedUserId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 회원 초대 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 여행 초대 수락
  Future<void> acceptInvitation({
    required String travelId,
    required String userId,
  }) async {
    final normalizedTravelId = travelId.trim();
    final normalizedUserId = userId.trim();

    if (normalizedTravelId.isEmpty ||
        normalizedUserId.isEmpty) {
      throw ArgumentError('초대 정보가 올바르지 않습니다.');
    }

    final reference =
    _travelCollection.doc(normalizedTravelId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(reference);

        if (!snapshot.exists || snapshot.data() == null) {
          throw StateError('여행 정보를 찾을 수 없습니다.');
        }

        final travel = TravelModel.fromFirestore(snapshot);

        if (travel.isDeleted) {
          throw StateError('삭제된 여행입니다.');
        }

        if (!travel.isPendingMember(normalizedUserId)) {
          throw StateError('유효한 여행 초대가 없습니다.');
        }

        if (travel.memberCount >= maxTravelMembers) {
          throw StateError(
            '여행 인원이 이미 $maxTravelMembers명입니다.',
          );
        }

        transaction.update(reference, {
          'pendingMemberIds': FieldValue.arrayRemove(
            [normalizedUserId],
          ),
          'memberIds': FieldValue.arrayUnion(
            [normalizedUserId],
          ),
          // 예전에 생성된 8명 제한 문서도 자동으로 10명으로 변경
          'maxMembers': maxTravelMembers,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      debugPrint('여행 초대 수락 성공: $normalizedUserId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 초대 수락 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 여행 초대 거절
  Future<void> rejectInvitation({
    required String travelId,
    required String userId,
  }) async {
    if (travelId.trim().isEmpty || userId.trim().isEmpty) {
      throw ArgumentError('초대 정보가 올바르지 않습니다.');
    }

    try {
      await _travelCollection.doc(travelId).update({
        'pendingMemberIds': FieldValue.arrayRemove(
          [userId],
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 초대 거절 성공: $userId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 초대 거절 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 초대 취소
  Future<void> cancelInvitation({
    required String travelId,
    required String ownerId,
    required String invitedUserId,
  }) async {
    final travel = await getTravelById(travelId);

    if (travel == null) {
      throw StateError('여행 정보를 찾을 수 없습니다.');
    }

    if (!travel.isOwner(ownerId)) {
      throw StateError('여행 생성자만 초대를 취소할 수 있습니다.');
    }

    await _travelCollection.doc(travelId).update({
      'pendingMemberIds': FieldValue.arrayRemove(
        [invitedUserId],
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 참여 회원 내보내기
  Future<void> removeMember({
    required String travelId,
    required String ownerId,
    required String memberId,
  }) async {
    if (ownerId == memberId) {
      throw StateError('여행 생성자는 내보낼 수 없습니다.');
    }

    final travel = await getTravelById(travelId);

    if (travel == null) {
      throw StateError('여행 정보를 찾을 수 없습니다.');
    }

    if (!travel.isOwner(ownerId)) {
      throw StateError('여행 생성자만 회원을 내보낼 수 있습니다.');
    }

    if (!travel.isMember(memberId)) {
      throw StateError('여행에 참여하지 않은 회원입니다.');
    }

    await _travelCollection.doc(travelId).update({
      'memberIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 참여 중인 여행에서 나가기
  Future<void> leaveTravel({
    required String travelId,
    required String userId,
  }) async {
    final travel = await getTravelById(travelId);

    if (travel == null) {
      throw StateError('여행 정보를 찾을 수 없습니다.');
    }

    if (travel.isOwner(userId)) {
      throw StateError(
        '여행 생성자는 여행에서 나갈 수 없습니다. '
            '여행을 삭제하거나 생성자를 변경해주세요.',
      );
    }

    if (!travel.isMember(userId)) {
      throw StateError('참여 중인 여행이 아닙니다.');
    }

    await _travelCollection.doc(travelId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 지출 입력 권한 확인
  Future<bool> canWriteExpense({
    required String travelId,
    required String userId,
  }) async {
    final travel = await getTravelById(travelId);

    if (travel == null) {
      return false;
    }

    return travel.canWriteExpense(userId);
  }

  /// 정산 조회 권한 확인
  Future<bool> canViewSettlement({
    required String travelId,
    required String userId,
  }) async {
    final travel = await getTravelById(travelId);

    if (travel == null) {
      return false;
    }

    return travel.canViewSettlement(userId);
  }

  /// 활성 여행 조회
  Future<TravelModel?> getActiveTravel(String userId) async {
    if (userId.trim().isEmpty) {
      return null;
    }

    try {
      final snapshot = await _travelCollection
          .where('memberIds', arrayContains: userId)
          .get();

      for (final document in snapshot.docs) {
        final TravelModel travel =
        TravelModel.fromFirestore(document);

        // 활성 상태이며 삭제되지 않은 첫 번째 여행을 반환한다.
        if (travel.isActive && !travel.isDeleted) {
          return travel;
        }
      }

      return null;
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '활성 여행 조회 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 여행 정보 수정
  Future<void> updateTravel(TravelModel travel) async {
    if (travel.travelId.trim().isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    if (travel.title.trim().isEmpty) {
      throw ArgumentError('여행 제목을 입력해주세요.');
    }

    if (travel.endDate.isBefore(travel.startDate)) {
      throw ArgumentError(
        '여행 종료일은 시작일보다 빠를 수 없습니다.',
      );
    }

    try {
      await _travelCollection.doc(travel.travelId).update({
        'title': travel.title.trim(),
        'startDate': Timestamp.fromDate(travel.startDate),
        'endDate': Timestamp.fromDate(travel.endDate),
        'budgetAmount': travel.budgetAmount,
        'isActive': travel.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 수정 성공: ${travel.travelId}');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 수정 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 여행 활성화
  Future<void> activateTravel({
    required String userId,
    required String travelId,
  }) async {
    if (userId.trim().isEmpty ||
        travelId.trim().isEmpty) {
      throw ArgumentError('여행 정보가 올바르지 않습니다.');
    }

    final selectedTravel = await getTravelById(travelId);

    if (selectedTravel == null) {
      throw StateError('여행 정보를 찾을 수 없습니다.');
    }

    if (!selectedTravel.isParticipant(userId)) {
      throw StateError('참여 중인 여행이 아닙니다.');
    }

    try {
      final snapshot = await _travelCollection
          .where('memberIds', arrayContains: userId)
          .get();

      final batch = _db.batch();

      for (final document in snapshot.docs) {
        final TravelModel travel =
        TravelModel.fromFirestore(document);

        // 삭제되지 않은 활성 여행만 비활성화한다.
        if (travel.isActive && !travel.isDeleted) {
          batch.update(document.reference, {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      batch.update(_travelCollection.doc(travelId), {
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      debugPrint('여행 활성화 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 활성화 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 여행 비활성화
  Future<void> deactivateTravel(String travelId) async {
    if (travelId.trim().isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    try {
      await _travelCollection.doc(travelId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 비활성화 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 비활성화 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  /// 여행 소프트 삭제
  Future<void> deleteTravel(String travelId) async {
    if (travelId.trim().isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    try {
      await _travelCollection.doc(travelId).update({
        'isDeleted': true,
        'isActive': false,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 삭제 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 삭제 실패',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  void _printFirebaseError(
      String title,
      FirebaseException error,
      StackTrace stackTrace,
      ) {
    debugPrint(title);
    debugPrint('오류 코드: ${error.code}');
    debugPrint('오류 메시지: ${error.message}');
    debugPrintStack(stackTrace: stackTrace);
  }
}
