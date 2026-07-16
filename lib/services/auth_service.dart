import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'consultation_service.dart';
import 'notification_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }


  /// 이메일 회원가입
  Future<User?> signUpWithEmail(String email, String password) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  /// 이메일 로그인
  Future<User?> signInWithEmail(String email, String password) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return result.user;
  }

  /// 이메일/비밀번호로 가입한 계정만 인증 메일을 보낸다.
  /// 구글 로그인 계정은 이미 구글이 이메일 소유를 검증했으므로
  /// Firebase가 emailVerified를 자동으로 true로 채워준다 — 별도 처리 불필요.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null || user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// 현재 로그인된 사용자 정보를 서버에서 새로 받아온다.
  /// (다른 기기/메일 앱에서 인증 링크를 눌렀을 수 있으므로 emailVerified를
  ///  다시 확인하려면 reload 후 currentUser를 읽어야 한다)
  Future<bool> refreshEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// 비밀번호 찾기 — Firebase가 발송하는 재설정 링크 메일을 이용한다.
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  /// 설정 > 비밀번호 변경 — 로그인된 상태에서 이메일로 6자리 인증번호 발송.
  /// (Cloud Functions: requestPasswordChangeOtp)
  Future<void> requestPasswordChangeOtp() async {
    await _functions.httpsCallable('requestPasswordChangeOtp').call();
  }

  /// 인증번호 검증 + 통과 시 서버에서 바로 비밀번호를 변경한다.
  /// (Cloud Functions: verifyPasswordChangeOtp)
  Future<void> verifyPasswordChangeOtp(String code, String newPassword) async {
    await _functions.httpsCallable('verifyPasswordChangeOtp').call({
      'code': code,
      'newPassword': newPassword,
    });
  }

  /// Cloud Functions HttpsError를 화면에 보여줄 한국어 메시지로 변환.
  String getFunctionsErrorMessage(FirebaseFunctionsException e) {
    return e.message ?? '문제가 발생했어요. 잠시 후 다시 시도해주세요';
  }

  String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return '이미 만들어진 통장이에요. 로그인을 시도해보세요';
      case 'invalid-email':
        return '이메일 형식이 올바르지 않아요';
      case 'weak-password':
        return '비밀번호는 6자 이상이어야 해요';
      case 'user-not-found':
        return '가입되지 않은 이메일이에요';
      case 'wrong-password':
      case 'invalid-credential':
        return '이메일 또는 비밀번호가 올바르지 않아요';
      case 'too-many-requests':
        return '잠시 후 다시 시도해주세요';
      default:
        return e.message ?? '문제가 발생했어요';
    }
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // users/{uid} 문서를 지워도 서브컬렉션(상담이력 등)은 자동으로 안 지워지므로
    // 먼저 직접 정리한다 — 그래야 탈퇴 후 고아 데이터가 안 남는다.
    await ConsultationService().deleteAll(uid);
    await _db.collection('users').doc(uid).delete();
    await _auth.currentUser?.delete();
    await GoogleSignIn().signOut();
    await NotificationService.instance.cancelAll();
  }
}