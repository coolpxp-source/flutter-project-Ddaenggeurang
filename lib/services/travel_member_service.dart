import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/travel_member_model.dart';
import '../models/travel_model.dart';
import 'travel_service.dart';

/// 회원 검색 결과를 화면에 전달하기 위한 모델
///
/// 여행 참여자 모델과 분리한 이유는 검색된 회원이 아직 여행 참여자가
/// 아닐 수 있기 때문이다.
class TravelUserSearchResult {
  final String userId;
  final String name;
  final String email;

  const TravelUserSearchResult({
    required this.userId,
    required this.name,
    required this.email,
  });

  /// 이름이 없으면 이메일을 대신 표시한다.
  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }

    if (email.trim().isNotEmpty) {
      return email.trim();
    }

    return '회원';
  }
}

class TravelMemberService {
  TravelMemberService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    TravelService? travelService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _travelService = travelService ??
            TravelService(
              firestore:
              firestore ?? FirebaseFirestore.instance,
            );

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final TravelService _travelService;

  /// 앱 회원 정보가 저장되는 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _userCollection {
    return _db.collection('users');
  }

  /// 여행 정보가 저장되는 컬렉션
  CollectionReference<Map<String, dynamic>>
  get _travelCollection {
    return _db.collection('travels');
  }

  /// 현재 로그인한 회원 UID
  String get _currentUserId {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw StateError('로그인이 필요한 기능입니다.');
    }

    return user.uid;
  }

  /// 이메일로 가입 회원 검색
  ///
  /// 비회원은 users 컬렉션에 문서가 없기 때문에 검색되지 않는다.
  /// 이메일은 대소문자 차이를 방지하기 위해 소문자로 변환한다.
  Future<TravelUserSearchResult?> findUserByEmail(
      String email,
      ) async {
    final String normalizedEmail =
    email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw ArgumentError('이메일을 입력해주세요.');
    }

    if (!_isValidEmail(normalizedEmail)) {
      throw ArgumentError(
        '올바른 이메일 형식으로 입력해주세요.',
      );
    }

    try {
      /*
       * 회원가입할 때 emailLowercase 필드를 저장한 경우를
       * 우선 검색한다.
       */
      QuerySnapshot<Map<String, dynamic>> snapshot =
      await _userCollection
          .where(
        'emailLowercase',
        isEqualTo: normalizedEmail,
      )
          .limit(1)
          .get();

      /*
       * 기존 회원 문서에 emailLowercase가 없는 경우
       * 기존 email 필드로 다시 검색한다.
       */
      if (snapshot.docs.isEmpty) {
        snapshot = await _userCollection
            .where(
          'email',
          isEqualTo: normalizedEmail,
        )
            .limit(1)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>>
      document = snapshot.docs.first;

      final Map<String, dynamic> data =
      document.data();

      final String userId =
      _readUserId(document.id, data);

      if (userId.isEmpty) {
        return null;
      }

      return TravelUserSearchResult(
        userId: userId,
        name: _readUserName(data),
        email: _readString(data['email']).isNotEmpty
            ? _readString(data['email'])
            : normalizedEmail,
      );
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '회원 이메일 검색 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage: '회원을 검색하지 못했습니다.',
        ),
      );
    }
  }

  /// 이메일로 회원을 검색한 후 여행에 초대
  ///
  /// 초대 직후에는 정식 참여자가 아니라 pendingMemberIds에 저장된다.
  /// 상대방이 초대를 수락해야 memberIds에 등록된다.
  Future<TravelUserSearchResult> inviteMemberByEmail({
    required String travelId,
    required String email,
  }) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    final TravelUserSearchResult? foundUser =
    await findUserByEmail(email);

    if (foundUser == null) {
      throw StateError(
        '가입된 회원을 찾을 수 없습니다.\n'
            '상대방이 먼저 회원가입을 해야 합니다.',
      );
    }

    final String ownerId = _currentUserId;

    if (foundUser.userId == ownerId) {
      throw StateError(
        '자기 자신은 초대할 수 없습니다.',
      );
    }

    /*
     * TravelService에서 다음 항목을 검사한다.
     *
     * 1. 현재 사용자가 여행 생성자인지
     * 2. 이미 참여한 회원인지
     * 3. 이미 초대 대기 중인지
     * 4. 생성자 포함 최대 8명을 초과하는지
     */
    await _travelService.inviteMember(
      travelId: trimmedTravelId,
      ownerId: ownerId,
      invitedUserId: foundUser.userId,
    );

    debugPrint(
      '여행 회원 초대 완료: ${foundUser.userId}',
    );

    return foundUser;
  }

  /// 현재 로그인한 회원이 여행 초대를 수락
  ///
  /// 수락하면 pendingMemberIds에서 제거되고 memberIds에 추가된다.
  Future<void> acceptInvitation(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    await _travelService.acceptInvitation(
      travelId: trimmedTravelId,
      userId: _currentUserId,
    );

    debugPrint('여행 초대 수락 완료: $trimmedTravelId');
  }

  /// 현재 로그인한 회원이 여행 초대를 거절
  ///
  /// 거절하면 pendingMemberIds에서 현재 UID가 제거된다.
  Future<void> rejectInvitation(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    await _travelService.rejectInvitation(
      travelId: trimmedTravelId,
      userId: _currentUserId,
    );

    debugPrint('여행 초대 거절 완료: $trimmedTravelId');
  }

  /// 여행 생성자가 보낸 초대를 취소
  Future<void> cancelInvitation({
    required String travelId,
    required String invitedUserId,
  }) async {
    if (travelId.trim().isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    if (invitedUserId.trim().isEmpty) {
      throw ArgumentError('초대 회원 정보가 없습니다.');
    }

    await _travelService.cancelInvitation(
      travelId: travelId.trim(),
      ownerId: _currentUserId,
      invitedUserId: invitedUserId.trim(),
    );

    debugPrint(
      '여행 초대 취소 완료: $invitedUserId',
    );
  }

  /// 여행 생성자가 참여 회원을 내보냄
  ///
  /// 여행 생성자 본인은 내보낼 수 없다.
  Future<void> removeMember({
    required String travelId,
    required String memberUserId,
  }) async {
    if (travelId.trim().isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    if (memberUserId.trim().isEmpty) {
      throw ArgumentError('참여자 정보가 없습니다.');
    }

    await _travelService.removeMember(
      travelId: travelId.trim(),
      ownerId: _currentUserId,
      memberId: memberUserId.trim(),
    );

    debugPrint(
      '여행 참여자 내보내기 완료: $memberUserId',
    );
  }

  /// 현재 로그인한 회원이 여행에서 나감
  ///
  /// 여행 생성자는 나갈 수 없으며 여행을 삭제해야 한다.
  Future<void> leaveTravel(
      String travelId,
      ) async {
    if (travelId.trim().isEmpty) {
      throw ArgumentError('여행 정보가 없습니다.');
    }

    await _travelService.leaveTravel(
      travelId: travelId.trim(),
      userId: _currentUserId,
    );

    debugPrint('여행 나가기 완료: $travelId');
  }

  /// 여행 참여자 목록 실시간 조회
  ///
  /// travels 문서의 memberIds를 기준으로 조회하기 때문에
  /// 비회원이나 초대 대기 회원은 목록에 포함되지 않는다.
  ///
  /// users 컬렉션에서 각 회원의 이름과 이메일을 가져와
  /// TravelMemberModel 목록으로 변환한다.
  Stream<List<TravelMemberModel>> watchMembers(
      String travelId,
      ) {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      return Stream<List<TravelMemberModel>>.value(
        <TravelMemberModel>[],
      );
    }

    return _travelCollection
        .doc(trimmedTravelId)
        .snapshots()
        .asyncMap(
          (
          DocumentSnapshot<Map<String, dynamic>>
          document,
          ) async {
        if (!document.exists ||
            document.data() == null) {
          return <TravelMemberModel>[];
        }

        final TravelModel travel =
        TravelModel.fromFirestore(document);

        if (travel.isDeleted ||
            !travel.isParticipant(_currentUserId)) {
          return <TravelMemberModel>[];
        }

        return _loadMembersFromTravel(travel);
      },
    );
  }

  /// 여행 참여자 목록 한 번 조회
  Future<List<TravelMemberModel>> getMembers(
      String travelId,
      ) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      return <TravelMemberModel>[];
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>>
      document = await _travelCollection
          .doc(trimmedTravelId)
          .get();

      if (!document.exists || document.data() == null) {
        return <TravelMemberModel>[];
      }

      final TravelModel travel =
      TravelModel.fromFirestore(document);

      if (travel.isDeleted) {
        return <TravelMemberModel>[];
      }

      if (!travel.isParticipant(_currentUserId)) {
        throw StateError(
          '여행 참여자만 회원 목록을 볼 수 있습니다.',
        );
      }

      return _loadMembersFromTravel(travel);
    } on FirebaseException catch (error, stackTrace) {
      _printFirebaseError(
        '여행 참여자 목록 조회 실패',
        error,
        stackTrace,
      );

      throw StateError(
        _firebaseErrorMessage(
          error,
          defaultMessage:
          '여행 참여자 목록을 불러오지 못했습니다.',
        ),
      );
    }
  }

  /// 여행 초대 대기 회원 정보 조회
  ///
  /// 여행 생성자가 초대를 취소할 때 사용할 수 있다.
  Future<List<TravelUserSearchResult>>
  getPendingMembers(String travelId) async {
    final String trimmedTravelId = travelId.trim();

    if (trimmedTravelId.isEmpty) {
      return <TravelUserSearchResult>[];
    }

    final TravelModel? travel =
    await _travelService.getTravelById(
      trimmedTravelId,
    );

    if (travel == null) {
      return <TravelUserSearchResult>[];
    }

    if (!travel.isOwner(_currentUserId)) {
      throw StateError(
        '여행 생성자만 초대 대기 목록을 볼 수 있습니다.',
      );
    }

    final List<TravelUserSearchResult> users =
    <TravelUserSearchResult>[];

    for (final String userId
    in travel.pendingMemberIds) {
      final DocumentSnapshot<Map<String, dynamic>>
      document =
      await _userCollection.doc(userId).get();

      final Map<String, dynamic> data =
          document.data() ?? <String, dynamic>{};

      users.add(
        TravelUserSearchResult(
          userId: userId,
          name: _readUserName(data),
          email: _readString(data['email']),
        ),
      );
    }

    return users;
  }

  /// 나에게 도착한 여행 초대 목록 실시간 조회
  Stream<List<TravelModel>> watchMyInvitations() {
    return _travelService.getPendingInvitations(
      _currentUserId,
    );
  }

  /// 여행 참여 인원 수
  Future<int> getMemberCount(
      String travelId,
      ) async {
    final List<TravelMemberModel> members =
    await getMembers(travelId);

    return members.length;
  }

  /// travels 문서의 memberIds를 회원 모델 목록으로 변환
  Future<List<TravelMemberModel>> _loadMembersFromTravel(
      TravelModel travel,
      ) async {
    final Set<String> uniqueMemberIds = <String>{
      travel.userId,
      ...travel.memberIds,
    };

    uniqueMemberIds.removeWhere(
          (String userId) => userId.trim().isEmpty,
    );

    final List<TravelMemberModel> members =
    <TravelMemberModel>[];

    for (final String userId in uniqueMemberIds) {
      final DocumentSnapshot<Map<String, dynamic>>
      userDocument =
      await _userCollection.doc(userId).get();

      final Map<String, dynamic> data =
          userDocument.data() ?? <String, dynamic>{};

      members.add(
        TravelMemberModel(
          memberId: '${travel.travelId}_$userId',
          travelId: travel.travelId,
          userId: userId,
          name: _readUserName(data),
          email: _readString(data['email']),
          isOwner: userId == travel.userId,
          createdAt:
          travel.createdAt ?? DateTime.now(),
          isDeleted: false,
          deletedAt: null,
        ),
      );
    }

    /*
     * 여행 생성자를 항상 목록 맨 위에 표시한다.
     * 그 외 참여자는 이름순으로 표시한다.
     */
    members.sort(
          (
          TravelMemberModel first,
          TravelMemberModel second,
          ) {
        if (first.isOwner != second.isOwner) {
          return first.isOwner ? -1 : 1;
        }

        return first.displayName.compareTo(
          second.displayName,
        );
      },
    );

    return members;
  }

  /// users 문서에서 UID 읽기
  ///
  /// 일반적으로 문서 ID가 Firebase UID지만,
  /// 기존 문서에 uid 또는 userId 필드가 있으면 함께 처리한다.
  String _readUserId(
      String documentId,
      Map<String, dynamic> data,
      ) {
    final String uid = _readString(data['uid']);

    if (uid.isNotEmpty) {
      return uid;
    }

    final String userId =
    _readString(data['userId']);

    if (userId.isNotEmpty) {
      return userId;
    }

    return documentId.trim();
  }

  /// users 문서에서 이름 또는 닉네임 읽기
  String _readUserName(
      Map<String, dynamic> data,
      ) {
    final List<dynamic> candidates = <dynamic>[
      data['name'],
      data['nickname'],
      data['displayName'],
      data['userName'],
    ];

    for (final dynamic candidate in candidates) {
      final String value = _readString(candidate);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  String _readString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  /// 간단한 이메일 형식 검사
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  String _firebaseErrorMessage(
      FirebaseException error, {
        required String defaultMessage,
      }) {
    switch (error.code) {
      case 'permission-denied':
        return '회원 또는 여행 접근 권한이 없습니다.';
      case 'unauthenticated':
        return '로그인이 필요한 기능입니다.';
      case 'unavailable':
        return '네트워크 상태를 확인해주세요.';
      case 'failed-precondition':
        return 'Firestore 색인 설정이 필요합니다.';
      default:
        return defaultMessage;
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