import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/expense_model.dart';
import '../models/travel_model.dart';

class TravelService {
  TravelService({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _travelCollection {
    return _db.collection('travels');
  }

  /// 여행 등록
  ///
  /// 새 여행이 활성 상태이면 기존 활성 여행을 먼저 비활성화한다.
  Future<String> addTravel(TravelModel travel) async {
    try {
      debugPrint('========== 여행 등록 시작 ==========');
      debugPrint('사용자 ID: ${travel.userId}');
      debugPrint('여행 이름: ${travel.title}');
      debugPrint('시작일: ${travel.startDate}');
      debugPrint('종료일: ${travel.endDate}');
      debugPrint('예산: ${travel.budgetAmount}');
      debugPrint('활성 여부: ${travel.isActive}');

      if (travel.userId.trim().isEmpty) {
        throw ArgumentError('userId가 비어 있습니다.');
      }

      if (travel.title.trim().isEmpty) {
        throw ArgumentError('여행 이름이 비어 있습니다.');
      }

      if (travel.endDate.isBefore(travel.startDate)) {
        throw ArgumentError('여행 종료일이 시작일보다 빠릅니다.');
      }

      if (travel.isActive) {
        await _deactivateAllActive(travel.userId);
      }

      final Map<String, dynamic> travelData = {
        ...travel.toFirestore(),

        // toFirestore에 createdAt이 없거나 null이어도 저장되도록 보장
        'createdAt': FieldValue.serverTimestamp(),

        // 신규 문서에서는 삭제일을 null로 설정
        'deletedAt': null,
      };

      debugPrint('Firestore 저장 데이터: $travelData');

      final DocumentReference<Map<String, dynamic>> document =
      await _travelCollection.add(travelData);

      debugPrint('여행 저장 성공');
      debugPrint('생성된 travelId: ${document.id}');
      debugPrint('===================================');

      return document.id;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('Firestore 여행 저장 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrint('오류 플러그인: ${error.plugin}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 저장 중 일반 오류 발생');
      debugPrint('오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 사용자의 모든 여행 실시간 조회
  Stream<List<TravelModel>> getTravels(String userId) {
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
      return snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> document) =>
            TravelModel.fromFirestore(document),
      )
          .toList();
    });
  }

  /// 현재 활성화된 여행 조회
  Future<TravelModel?> getActiveTravel(String userId) async {
    try {
      if (userId.trim().isEmpty) {
        return null;
      }

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
    }
  }

  /// 여행 한 건 조회
  Future<TravelModel?> getTravelById(String travelId) async {
    try {
      if (travelId.trim().isEmpty) {
        return null;
      }

      final DocumentSnapshot<Map<String, dynamic>> document =
      await _travelCollection.doc(travelId).get();

      if (!document.exists) {
        return null;
      }

      return TravelModel.fromFirestore(document);
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 단건 조회 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 수정
  Future<void> updateTravel(
      String travelId,
      Map<String, dynamic> updates,
      ) async {
    try {
      if (travelId.trim().isEmpty) {
        throw ArgumentError('travelId가 비어 있습니다.');
      }

      final Map<String, dynamic> updateData = {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _travelCollection.doc(travelId).update(updateData);

      debugPrint('여행 수정 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 수정 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 활성화
  Future<void> activateTravel({
    required String travelId,
    required String userId,
  }) async {
    try {
      if (travelId.trim().isEmpty || userId.trim().isEmpty) {
        throw ArgumentError('travelId 또는 userId가 비어 있습니다.');
      }

      await _deactivateAllActive(userId);

      await _travelCollection.doc(travelId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 활성화 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 활성화 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 종료
  Future<void> deactivateTravel(String travelId) async {
    try {
      if (travelId.trim().isEmpty) {
        throw ArgumentError('travelId가 비어 있습니다.');
      }

      await _travelCollection.doc(travelId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 종료 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 종료 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 소프트 삭제
  Future<void> deleteTravel(String travelId) async {
    try {
      if (travelId.trim().isEmpty) {
        throw ArgumentError('travelId가 비어 있습니다.');
      }

      await _travelCollection.doc(travelId).update({
        'isActive': false,
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 삭제 성공: $travelId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 삭제 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 현재 활성화된 모든 여행 비활성화
  Future<void> _deactivateAllActive(String userId) async {
    if (userId.trim().isEmpty) {
      return;
    }

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
        .get();

    if (snapshot.docs.isEmpty) {
      debugPrint('비활성화할 기존 여행 없음');
      return;
    }

    final WriteBatch batch = _db.batch();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> document
    in snapshot.docs) {
      batch.update(document.reference, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    debugPrint(
      '기존 활성 여행 ${snapshot.docs.length}개 비활성화 완료',
    );
  }

  /// 지출 등록 시 자동 여행 분류
  Future<String?> resolveTravelIdForExpense({
    required String userId,
    required DateTime expenseDate,
    required ExpenseNature nature,
    String? installmentPlanId,
    String? recurringPaymentId,
  }) async {
    try {
      final TravelModel? activeTravel =
      await getActiveTravel(userId);

      if (activeTravel == null) {
        return null;
      }

      final bool shouldTag = activeTravel.shouldAutoTag(
        expenseDate: expenseDate,
        isFixedNature: nature == ExpenseNature.fixed,
        hasInstallmentPlan:
        installmentPlanId != null &&
            installmentPlanId.trim().isNotEmpty,
        hasRecurringPayment:
        recurringPaymentId != null &&
            recurringPaymentId.trim().isNotEmpty,
      );

      if (!shouldTag) {
        return null;
      }

      return activeTravel.travelId;
    } catch (error, stackTrace) {
      debugPrint('여행 자동 분류 확인 실패: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }
}