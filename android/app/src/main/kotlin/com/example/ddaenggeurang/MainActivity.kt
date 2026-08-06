package com.example.ddaenggeurang

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth(생체인증 앱 잠금)의 BiometricPrompt는 FragmentActivity가 필요해서
// FlutterActivity 대신 FlutterFragmentActivity를 상속한다 — 완전한 상위 호환이라
// 다른 기능에는 영향 없음.
class MainActivity : FlutterFragmentActivity()
