/**
 * 땡그랑 - 비밀번호 변경 인증번호(OTP) Cloud Functions
 *
 * ★★★ 배포 전 필수 설정 (팀원 중 한 명이 한 번만 하면 됨) ★★★
 *  1) Firebase 프로젝트를 Blaze(종량제) 요금제로 전환 (Cloud Functions가
 *     외부 네트워크로 이메일을 보내려면 필요)
 *  2) SMTP 자격증명 등록 (예: Gmail 앱 비밀번호, 또는 SendGrid/Resend 등)
 *       firebase functions:secrets:set SMTP_USER
 *       firebase functions:secrets:set SMTP_PASS
 *  3) 배포: firebase deploy --only functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getMessaging } = require("firebase-admin/messaging");

admin.initializeApp();
const db = admin.firestore();

const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

const OTP_TTL_MS = 5 * 60 * 1000; // 5분
const RESEND_COOLDOWN_MS = 60 * 1000; // 60초
const MAX_ATTEMPTS = 5;

function hashCode(code, uid) {
  return crypto.createHash("sha256").update(`${code}:${uid}`).digest("hex");
}

function makeTransport() {
  return nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: { user: SMTP_USER.value(), pass: SMTP_PASS.value() },
  });
}

/**
 * 비밀번호 변경용 인증번호 발급 + 이메일 발송
 * 이미 로그인된 사용자만 호출 가능 (설정 > 비밀번호 변경 화면에서 사용)
 */
exports.requestPasswordChangeOtp = onCall(
  { secrets: [SMTP_USER, SMTP_PASS], region: "asia-northeast3" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요해요");
    }

    const user = await admin.auth().getUser(uid);
    const email = user.email;
    if (!email) {
      throw new HttpsError("failed-precondition", "이메일 계정이 아니에요");
    }

    const otpRef = db.collection("password_otps").doc(uid);
    const now = Date.now();

    const existing = await otpRef.get();
    if (existing.exists) {
      const lastSentAt = existing.data().lastSentAt?.toMillis?.() ?? 0;
      const waitLeft = RESEND_COOLDOWN_MS - (now - lastSentAt);
      if (waitLeft > 0) {
        throw new HttpsError(
          "resource-exhausted",
          `${Math.ceil(waitLeft / 1000)}초 후 다시 시도해주세요`
        );
      }
    }

    const code = String(crypto.randomInt(0, 1000000)).padStart(6, "0");

    await otpRef.set({
      codeHash: hashCode(code, uid),
      expiresAt: admin.firestore.Timestamp.fromMillis(now + OTP_TTL_MS),
      lastSentAt: admin.firestore.Timestamp.fromMillis(now),
      attempts: 0,
    });

    const transport = makeTransport();
    await transport.sendMail({
      from: '"땡그랑" <noreply@ddaenggeurang.app>',
      to: email,
      subject: "[땡그랑] 비밀번호 변경 인증번호",
      text: `인증번호: ${code}\n5분 이내에 입력해주세요.\n본인이 요청하지 않았다면 이 메일을 무시하세요.`,
      html: `
        <div style="font-family:sans-serif;padding:24px">
          <h2 style="color:#221A16">땡그랑 비밀번호 변경 인증번호</h2>
          <p style="font-size:32px;font-weight:800;letter-spacing:4px;color:#F5A623">${code}</p>
          <p style="color:#8A7E77;font-size:13px">5분 이내에 입력해주세요. 본인이 요청하지 않았다면 이 메일을 무시하세요.</p>
        </div>
      `,
    });

    return { ok: true };
  }
);

/**
 * 인증번호 검증 + 통과 시 비밀번호 변경까지 서버에서 직접 처리
 * (클라이언트가 "인증됨" 상태를 조작해 인증 없이 비밀번호를 바꾸는 것을 막기 위해
 *  검증과 변경을 한 함수에서 원자적으로 처리한다)
 */
exports.verifyPasswordChangeOtp = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "로그인이 필요해요");
    }

    const { code, newPassword } = request.data || {};
    if (!code || typeof code !== "string" || code.length !== 6) {
      throw new HttpsError("invalid-argument", "인증번호 6자리를 입력해주세요");
    }
    if (!newPassword || typeof newPassword !== "string" || newPassword.length < 6) {
      throw new HttpsError("invalid-argument", "비밀번호는 6자 이상이어야 해요");
    }

    const otpRef = db.collection("password_otps").doc(uid);
    const snap = await otpRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "인증번호를 먼저 요청해주세요");
    }

    const data = snap.data();
    const now = Date.now();

    if (data.expiresAt.toMillis() < now) {
      await otpRef.delete();
      throw new HttpsError("deadline-exceeded", "인증번호가 만료됐어요. 다시 받아주세요");
    }

    if ((data.attempts ?? 0) >= MAX_ATTEMPTS) {
      await otpRef.delete();
      throw new HttpsError(
        "resource-exhausted",
        "시도 횟수를 초과했어요. 인증번호를 다시 받아주세요"
      );
    }

    if (data.codeHash !== hashCode(code, uid)) {
      await otpRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
      const left = MAX_ATTEMPTS - (data.attempts + 1);
      throw new HttpsError(
        "invalid-argument",
        left > 0 ? `인증번호가 올바르지 않아요 (${left}회 남음)` : "인증번호가 올바르지 않아요"
      );
    }

    await admin.auth().updateUser(uid, { password: newPassword });
    await otpRef.delete();

    return { ok: true };
  }
);

/**
 * 누군가 내 게시글에 좋아요를 누르면, 글 작성자에게 푸시 알림을 보낸다.
 */
exports.onPostLiked = onDocumentCreated(
  { document: "communityPosts/{postId}/likedBy/{userId}", region: "asia-northeast3" },
  async (event) => {
    const { postId, userId } = event.params;

    const postSnap = await db.collection("communityPosts").doc(postId).get();
    if (!postSnap.exists) return;

    const post = postSnap.data();

    // 본인이 본인 글에 좋아요 누른 경우는 알림 안 보냄
    if (post.authorId === userId) return;

    const authorSnap = await db.collection("users").doc(post.authorId).get();
    const fcmToken = authorSnap.data()?.fcmToken;
    if (!fcmToken) return;

    // 좋아요 누른 사람 닉네임 조회 (없으면 "누군가"로 대체)
    const likerSnap = await db.collection("users").doc(userId).get();
    const likerName = likerSnap.data()?.nickname ?? "누군가";

    await getMessaging().send({
      token: fcmToken,
      notification: {
        title: "새 좋아요 💛",
        body: `${likerName}님이 회원님의 게시글을 좋아해요`,
      },
      data: {
        type: "post_like",
        postId: postId,
      },
    });
  }
);
