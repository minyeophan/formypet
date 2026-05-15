# 아키텍처

## 디렉토리 구조
```
lib/
├── main.dart                        # 진입점 (initApiClient, ProviderScope)
├── core/
│   ├── api_client.dart              # Dio 싱글톤 + QueuedInterceptorsWrapper (토큰 갱신)
│   ├── date_utils.dart              # 날짜 헬퍼
│   ├── pet_colors.dart              # 색상 상수
│   ├── record_utils.dart            # 활동 유형 목록, 필드 매핑, sanitizeDetail
│   └── secure_storage.dart          # flutter_secure_storage 토큰 저장
├── models/
│   ├── pet.dart
│   ├── activity_record.dart
│   ├── routine.dart                 # Routine, RoutineCompletion, TodayRoutineData
│   ├── post.dart
│   └── user_profile.dart
├── services/
│   ├── auth_service.dart            # login/logout/getProfile
│   ├── pet_service.dart
│   ├── record_service.dart
│   ├── routine_service.dart         # getTodayRoutines, patchCompletion
│   ├── community_service.dart
│   └── media_service.dart
├── providers/
│   ├── auth_provider.dart           # AuthState (StateNotifier)
│   ├── pet_provider.dart            # PetState (StateNotifier) — pets, records, routines
│   └── community_provider.dart
├── router/
│   └── app_router.dart              # go_router + _RouterNotifier (refreshListenable)
├── screens/
│   ├── auth/auth_screen.dart
│   ├── onboarding/onboarding_screen.dart
│   ├── home/
│   │   ├── home_screen.dart
│   │   ├── pet_selector.dart
│   │   ├── quick_record_row.dart
│   │   ├── today_routine_card.dart
│   │   └── recent_records_card.dart
│   ├── records/
│   │   ├── records_screen.dart
│   │   ├── activity_tab.dart
│   │   ├── health_tab.dart
│   │   └── growth_tab.dart
│   ├── community/
│   │   ├── community_screen.dart
│   │   ├── post_card.dart
│   │   └── write_screen.dart
│   ├── pet/
│   │   ├── pet_detail_screen.dart
│   │   └── pet_edit_screen.dart
│   └── my/my_screen.dart
├── widgets/
│   ├── app_text.dart                # Noto Sans KR 폰트 래퍼
│   ├── main_scaffold.dart           # 하단 탭 바 + ShellRoute 컨테이너
│   ├── record_modal.dart            # 기록 추가 바텀 시트 (유형 선택 → 입력)
│   └── record_detail_form.dart
└── routine/
    └── routine_screen.dart
```

## 패턴
- **go_router ShellRoute**: `/home`, `/community`, `/my`는 ShellRoute로 묶여 탭 바 유지. 나머지(`/records`, `/routine`, `/pet/:id` 등)는 ShellRoute 밖에서 풀스크린 라우트.
- **AppText 강제 사용**: 모든 텍스트는 `<AppText>`로 — Noto Sans KR 폰트 일관성 보장.
- **Riverpod StateNotifier**: 전역 상태는 `StateNotifierProvider`로 관리. `ref.watch`로 UI 구독, `ref.read`로 액션 호출.

## 라우팅 (go_router)
```
GoRouter
├── /auth           → AuthScreen
├── /onboarding     → OnboardingScreen
├── ShellRoute (MainScaffold — 탭 바)
│   ├── /home       → HomeScreen
│   ├── /community  → CommunityScreen
│   └── /my         → MyScreen
├── /records        → RecordsScreen
├── /routine        → RoutineScreen
├── /community/write → WriteScreen
├── /pet/:id        → PetDetailScreen
└── /pet/:id/edit   → PetEditScreen
```

리다이렉트 로직 (`_RouterNotifier`):
1. `isLoading` 중이면 리다이렉트 없음
2. 미인증 → `/auth`
3. 인증됐지만 온보딩 미완료 → `/onboarding`
4. `/auth`, `/onboarding`, `/` → `/home`

`_RouterNotifier`는 `authProvider`, `petProvider` 양쪽을 `ref.listen`으로 구독하고 `notifyListeners()`를 호출 — GoRouter를 재생성하지 않고 `refreshListenable`로만 리다이렉트 재평가.

## 데이터 흐름
```
사용자 액션 (GestureDetector / InkWell)
    → ref.read(provider.notifier).action()
      → Service → Dio → /api/v1 백엔드
        → state 업데이트
          → ref.watch 구독 위젯 리빌드
```

## 앱 시작 흐름
```
main() → initApiClient() → runApp(ProviderScope)
  → PetyilgiApp → routerProvider 생성
    → PetNotifier._init()
      → SharedPreferences: hasOnboarded 확인
        → false: isLoading=false, /auth로 리다이렉트
        → true: PetService.getPets() → records/routines 로드
          → isLoading=false → /home
```

## 상태 관리
- **AuthProvider**: 인증 여부, 사용자 프로필 (flutter_secure_storage에 토큰 저장)
- **PetProvider**: pets, activePetId, records, routines, routineCompletions, todaySummary, quickTypeIds
- **CommunityProvider**: posts 목록
- **로컬 UI 상태**: 탭 선택, 폼 입력값 등은 `StatefulWidget` / `useState` (flutter_hooks 미사용 시 StatefulWidget)

## HTTP 클라이언트 (Dio)
- `QueuedInterceptorsWrapper`로 동시 요청 중 토큰 만료 시 한 번만 갱신 후 큐 재시도
- 갱신 요청 시 Authorization 헤더 제거 (무한 루프 방지)
- `unwrap(res)`: `{ success, data, message }` 응답 구조에서 `data` 추출
