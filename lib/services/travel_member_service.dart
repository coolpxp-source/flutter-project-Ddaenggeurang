import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/travel_member_model.dart';

class TravelMemberService {
  TravelMemberService({
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Firestore 여행 참여자 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _memberCollection {
    return _db.collection('travelMembers');
  }

  /// 여행 참여자 등록
  ///
  /// 생성된 참여자 문서 ID를 반환한다.
  Future<String> addMember(
      TravelMemberModel member,
      ) async {
    if (member.travelId.trim().isEmpty) {
      throw ArgumentError('travelId가 비어 있습니다.');
    }

    if (member.name.trim().isEmpty) {
      throw ArgumentError('참여자 이름이 비어 있습니다.');
    }

    try {
      final DocumentReference<Map<String, dynamic>>
      document = _memberCollection.doc();

      await document.set(<String, dynamic>{
        'memberId': document.id,
        'travelId': member.travelId.trim(),
        'userId': member.userId.trim(),
        'name': member.name.trim(),
        'isOwner': member.isOwner,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'deletedAt': null,
      });

      debugPrint('여행 참여자 등록 성공: ${document.id}');

      return document.id;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 참여자 등록 실패');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 참여자 등록 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행 생성자를 참여자로 등록
  Future<String> addOwner({
    required String travelId,
    required String userId,
    required String name,
  }) {
    return addMember(
      TravelMemberModel(
        memberId: '',
        travelId: travelId,
        userId: userId,
        name: name,
        isOwner: true,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 비회원 여행 참여자 등록
  Future<String> addGuest({
    required String travelId,
    required String name,
  }) {
    return addMember(
      TravelMemberModel(
        memberId: '',
        travelId: travelId,
        userId: '',
        name: name,
        isOwner: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 여행별 참여자 목록 실시간 조회
  ///
  /// 삭제된 참여자는 제외하고 생성 순서대로 반환한다.
  Stream<List<TravelMemberModel>> watchMembers(
      String travelId,
      ) {
    if (travelId.trim().isEmpty) {
      return Stream<List<TravelMemberModel>>.value(
        <TravelMemberModel>[],
      );
    }

    return _memberCollection
        .where(
      'travelId',
      isEqualTo: travelId.trim(),
    )
        .snapshots()
        .map((
        QuerySnapshot<Map<String, dynamic>> snapshot,
        ) {
      final List<TravelMemberModel> members = snapshot.docs
          .map(
            (
            QueryDocumentSnapshot<Map<String, dynamic>>
            document,
            ) {
          return TravelMemberModel.fromFirestore(
            document,
          );
        },
      )
          .where(
            (TravelMemberModel member) =>
        !member.isDeleted,
      )
          .toList();

      members.sort(
            (
            TravelMemberModel first,
            TravelMemberModel second,
            ) {
          if (first.isOwner != second.isOwner) {
            return first.isOwner ? -1 : 1;
          }

          return first.createdAt.compareTo(
            second.createdAt,
          );
        },
      );

      return members;
    });
  }

  /// 여행별 참여자 목록 한 번 조회
  Future<List<TravelMemberModel>> getMembers(
      String travelId,
      ) async {
    if (travelId.trim().isEmpty) {
      return <TravelMemberModel>[];
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
      await _memberCollection
          .where(
        'travelId',
        isEqualTo: travelId.trim(),
      )
          .get();

      final List<TravelMemberModel> members = snapshot.docs
          .map(
            (
            QueryDocumentSnapshot<Map<String, dynamic>>
            document,
            ) {
          return TravelMemberModel.fromFirestore(
            document,
          );
        },
      )
          .where(
            (TravelMemberModel member) =>
        !member.isDeleted,
      )
          .toList();

      members.sort(
            (
            TravelMemberModel first,
            TravelMemberModel second,
            ) {
          if (first.isOwner != second.isOwner) {
            return first.isOwner ? -1 : 1;
          }

          return first.createdAt.compareTo(
            second.createdAt,
          );
        },
      );

      return members;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 참여자 목록 조회 실패');
      debugPrint('travelId: $travelId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 참여자 목록 조회 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 참여자 ID로 한 명 조회
  Future<TravelMemberModel?> getMemberById(
      String memberId,
      ) async {
    if (memberId.trim().isEmpty) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> document =
      await _memberCollection
          .doc(memberId.trim())
          .get();

      if (!document.exists || document.data() == null) {
        return null;
      }

      final TravelMemberModel member =
      TravelMemberModel.fromFirestore(document);

      if (member.isDeleted) {
        return null;
      }

      return member;
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 참여자 단건 조회 실패');
      debugPrint('memberId: $memberId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 참여자 단건 조회 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 참여자 이름 수정
  Future<void> updateMemberName({
    required String memberId,
    required String name,
  }) async {
    if (memberId.trim().isEmpty) {
      throw ArgumentError('memberId가 비어 있습니다.');
    }

    if (name.trim().isEmpty) {
      throw ArgumentError('참여자 이름이 비어 있습니다.');
    }

    try {
      await _memberCollection
          .doc(memberId.trim())
          .update(<String, dynamic>{
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 참여자 수정 성공: $memberId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 참여자 수정 실패');
      debugPrint('memberId: $memberId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 참여자 수정 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 참여자 소프트 삭제
  Future<void> deleteMember(
      String memberId,
      ) async {
    if (memberId.trim().isEmpty) {
      throw ArgumentError('memberId가 비어 있습니다.');
    }

    try {
      final DocumentReference<Map<String, dynamic>>
      reference = _memberCollection.doc(
        memberId.trim(),
      );

      final DocumentSnapshot<Map<String, dynamic>> document =
      await reference.get();

      if (!document.exists || document.data() == null) {
        throw StateError('참여자 정보가 존재하지 않습니다.');
      }

      final TravelMemberModel member =
      TravelMemberModel.fromFirestore(document);

      if (member.isOwner) {
        throw StateError('여행 생성자는 삭제할 수 없습니다.');
      }

      await reference.update(<String, dynamic>{
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('여행 참여자 삭제 성공: $memberId');
    } on FirebaseException catch (error, stackTrace) {
      debugPrint('여행 참여자 삭제 실패');
      debugPrint('memberId: $memberId');
      debugPrint('오류 코드: ${error.code}');
      debugPrint('오류 메시지: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    } catch (error, stackTrace) {
      debugPrint('여행 참여자 삭제 중 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  /// 여행에 등록된 참여자 수 조회
  Future<int> getMemberCount(
      String travelId,
      ) async {
    final List<TravelMemberModel> members =
    await getMembers(travelId);

    return members.length;
  }
}