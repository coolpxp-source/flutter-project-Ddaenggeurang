import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/travel_model.dart';

class TravelService {
  TravelService({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Firestore 여행 컬렉션
  CollectionReference<Map<String, dynamic>> get _travelCollection {
    return _db.collection('travels');
  }

  /// 여행 생성
  ///
  /// 생성된 여행 문서 ID를 반환한다.
  Future<String> addTravel(TravelModel travel) async {
    try {
      final DocumentReference<Map<String, dynamic>> document =
      _travelCollection.doc();

      await document.set({
        'travelId': document.id,
        'userId': travel.userId,
        'title': travel.title.trim(),
        'startDate': Timestamp.fromDate(travel.startDate),
        'endDate': Timestamp.fromDate(travel.endDate),
        'budgetAmount': travel.budgetAmount,
        'isActive': travel.isActive,
        'isDeleted': travel.isDeleted,
        'deletedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 생성 성공: ${document.id}');

      return document.id;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 생성 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 생성 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 사용자의 전체 여행 목록 실시간 조회
  ///
  /// 삭제되지 않은 여행만 시작일 최신순으로 반환한다.
  Stream<List<TravelModel>> getTravelsByUserId(
      String userId,
      ) {
    if (userId.trim().isEmpty) {
      return Stream<List<TravelModel>>.value([]);
    }

    return _travelCollection
        .where(
      'userId',
      isEqualTo: userId,
    )
        .where(
      'isDeleted',
      isEqualTo: false,
    )
        .orderBy(
      'startDate',
      descending: true,
    )
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs.map(
            (QueryDocumentSnapshot<Map<String, dynamic>> document) {
          return TravelModel.fromFirestore(document);
        },
      ).toList();
    });
  }

  /// 여행 ID로 여행 한 건 조회
  ///
  /// 여행 리포트 화면에서 사용한다.
  Future<TravelModel?> getTravelById(
      String travelId,
      ) async {
    if (travelId.trim().isEmpty) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
      await _travelCollection.doc(travelId).get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      final TravelModel travel =
      TravelModel.fromFirestore(document);

      if (travel.isDeleted) {
        return null;
      }

      return travel;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 단건 조회 실패');
      debugPrint('travelId: $travelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 단건 조회 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 현재 활성화된 여행 조회
  Future<TravelModel?> getActiveTravel(
      String userId,
      ) async {
    if (userId.trim().isEmpty) {
      return null;
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await _travelCollection
          .where(
        'userId',
        isEqualTo: userId,
      )
          .where(
        'isActive',
        isEqualTo: true,
      )
          .where(
        'isDeleted',
        isEqualTo: false,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return TravelModel.fromFirestore(
        snapshot.docs.first,
      );
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('활성 여행 조회 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('활성 여행 조회 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 정보 수정
  Future<void> updateTravel(
      TravelModel travel,
      ) async {
    if (travel.travelId.trim().isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    if (travel.title.trim().isEmpty) {
      throw ArgumentError('여행 제목이 비어 있습니다.');
    }

    if (travel.endDate.isBefore(travel.startDate)) {
      throw ArgumentError(
        '여행 종료일은 시작일보다 빠를 수 없습니다.',
      );
    }

    try {
      await _travelCollection
          .doc(travel.travelId)
          .update({
        'title': travel.title.trim(),
        'startDate': Timestamp.fromDate(
          travel.startDate,
        ),
        'endDate': Timestamp.fromDate(
          travel.endDate,
        ),
        'budgetAmount': travel.budgetAmount,
        'isActive': travel.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 수정 성공: ${travel.travelId}');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 수정 실패');
      debugPrint('travelId: ${travel.travelId}');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 수정 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 특정 여행을 활성화한다.
  ///
  /// 기존에 활성화된 여행은 모두 비활성화하고,
  /// 선택한 여행만 활성화한다.
  Future<void> activateTravel({
    required String userId,
    required String travelId,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userId가 비어 있습니다.');
    }

    if (travelId.trim().isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await _travelCollection
          .where(
        'userId',
        isEqualTo: userId,
      )
          .where(
        'isActive',
        isEqualTo: true,
      )
          .where(
        'isDeleted',
        isEqualTo: false,
      )
          .get();

      final WriteBatch batch = _db.batch();

      for (final QueryDocumentSnapshot<Map<String, dynamic>>
      document in snapshot.docs) {
        batch.update(
          document.reference,
          {
            'isActive': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        );
      }

      batch.update(
        _travelCollection.doc(travelId),
        {
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      debugPrint('여행 활성화 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 활성화 실패');
      debugPrint('travelId: $travelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 활성화 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 비활성화
  Future<void> deactivateTravel(
      String travelId,
      ) async {
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
      debugPrint('여행 비활성화 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 소프트 삭제
  Future<void> deleteTravel(
      String travelId,
      ) async {
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
      debugPrint('여행 삭제 실패');
      debugPrint('travelId: $travelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 삭제 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }
}