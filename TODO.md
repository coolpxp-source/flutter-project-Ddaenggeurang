# TODO (feature/auth-mypage)

## 막혀있는 것
- [ ] `categories` Firestore 컬렉션이 비어있어서 지출 입력 자체가 안 됨 (임예림 담당,
      `categories`/`expenses` 컬렉션 시딩 필요). 시딩되면 아래 두 기능을 실데이터로
      재검증할 것:
  - [ ] 홈 화면 소비 챌린지 카드 (`lib/screens/home/home_screen.dart`,
        `_LiveChallengeSection`)
  - [ ] 마이페이지 월간 소비 통계 / 공유 (`lib/screens/mypage/monthly_report_screen.dart`)
  - [ ] 홈 화면 주간 브리핑 카드 (`_LiveWeeklyBriefingSection`)

## 다음에 만들면 좋을 것 (미구현 후보)
- [ ] 소비심리테스트 결과 ↔ 코치 톤 추천 매칭 (테스트 끝나면 어울리는 코치 제안)
- [ ] 뱃지/업적 시스템 (로그인 스트릭 등 이미 쌓이는 데이터 활용)
- [ ] 연동된 소셜 로그인 계정 관리 화면 (설정 > 계정)

## 기술 부채
- [ ] `AiService.consultDailyLimit`이 메모리 카운터라 앱 재시작하면 리셋됨 —
      Firestore `users/{uid}`에 날짜별로 저장하는 방식으로 교체 필요
      (`ai_service.dart` 주석에 이미 명시돼 있음)
