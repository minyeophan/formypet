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
│   │   ├── meal_record_screen.dart
│   │   ├── record_category_form_screen.dart
│   │   ├── expense_add_screen.dart
│   │   ├── expense_wallet_screen.dart
│   │   ├── expense_report_screen.dart
│   │   ├── expense_record_utils.dart
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
│   ├── my/my_screen.dart
│   └── routine/
│       ├── routine_screen.dart
│       ├── routine_create_screen.dart
│       ├── routine_schedule_create_screen.dart
│       ├── routine_calendar_values.dart
│       └── routine_schedule_values.dart
├── widgets/
│   ├── app_header.dart              # 공통 AppBar, 헤더 아이콘 버튼
│   ├── app_navigation.dart          # 공통 뒤로가기 버튼, 진입 chevron 표시
│   ├── app_text.dart                # Noto Sans KR 폰트 래퍼
│   ├── main_scaffold.dart           # 하단 탭 바 + ShellRoute 컨테이너
│   ├── preparing_toast.dart         # 준비중 공통 토스트
│   ├── record_modal.dart            # 기록 추가 바텀 시트 (유형 선택 → 입력)
│   ├── record_detail_form.dart
│   └── record_inputs/               # 기록 날짜/시간 wheel sheet, 숫자 패널 공통 위젯
```

## 패턴
- **go_router ShellRoute**: `/home`, `/community`, `/my`는 ShellRoute로 묶여 탭 바 유지. 나머지(`/records`, `/routine`, `/pet/:id` 등)는 ShellRoute 밖에서 풀스크린 라우트.
- **AppText 강제 사용**: 모든 텍스트는 `<AppText>`로 — Noto Sans KR 폰트 일관성 보장.
- **공통 헤더/네비게이션 위젯**: 화면 내비게이션 의미의 뒤로가기는 `AppBackButton`을 사용한다. `AppBackButton`은 UI와 콜백만 담당하고 `context.pop()`, `context.go()` fallback, 키보드 dismiss는 호출 화면에 둔다. 행/카드의 진입 표시는 표시 전용 `AppDisclosureChevron`을 사용하며 tap 처리는 부모 row/card가 담당한다.
- **AppHeader 사용 범위**: 기본 화면 헤더는 `AppHeader`를 우선 사용하고, 뒤로가기가 필요하면 `showBackButton/onBack` 경로를 사용한다. 헤더 우측 원형 아이콘 버튼은 `AppHeaderIconButton`을 재사용한다.
- **기록 입력 패널**: `RecordTypeGrid`에서 진입하는 `MealRecordScreen`, `RecordCategoryFormScreen`의 날짜/시간/숫자 입력은 `widgets/record_inputs/`를 사용한다. `water`, `diary`도 `RecordCategoryFormScreen` 전체 화면 route를 사용한다. 날짜/시간은 `showRecordDatePickerSheet`, `showRecordTimePickerSheet` wheel bottom sheet로 열고, 숫자는 `RecordNumberInput`의 read-only field와 커스텀 숫자 패널을 사용한다. 화면 파일에는 wheel index 계산, 숫자 키 배열, sheet layout을 직접 두지 않는다.
- **지출 UI 경계**: 홈 `지갑`은 `/wallet`로 이동한다. `/wallet`, `/wallet/report`, `/records/expense/new`는 UI가 있지만 지출 저장은 아직 `준비중`이며 백엔드 계약과 분리한다.
- **루틴 UI 경계**: `/routine`은 월간 캘린더와 일정 샘플 목록을 제공한다. 루틴 생성은 API에 저장하고 일정 생성은 로컬 입력 UI 뒤 `준비중`으로 복귀한다. 반복 날짜와 일정 범위 보정은 `routine_calendar_values.dart`, `routine_schedule_values.dart`의 pure helper를 사용한다.
- **기록 입력 스타일 경계**: 기록 입력 패널의 surface, radius, header height, keypad spacing 같은 모양 값은 `RecordInputStyle`에서 관리한다. 저장 API, payload, schema는 입력 패널 변경과 분리한다.
- **Riverpod StateNotifier**: 전역 상태는 `StateNotifierProvider`로 관리. `ref.watch`로 UI 구독, `ref.read`로 액션 호출.

## 라우팅 (go_router)
```
GoRouter
├── /              → SplashScreen
├── /auth           → AuthScreen
├── /onboarding     → OnboardingScreen
├── /pets/new       → OnboardingScreen(additionalPet)
├── ShellRoute (MainScaffold — 탭 바)
│   ├── /home       → HomeScreen
│   ├── /community  → CommunityScreen
│   ├── /community/category/:category → CommunityCategoryScreen
│   └── /my         → MyScreen
├── /records        → RecordsScreen
├── /records/all    → AllRecordsScreen
├── /records/growth → GrowthRecordsScreen
├── /records/meal/new → MealRecordScreen
├── /records/expense/new → ExpenseAddScreen
├── /records/:typeId/new → RecordCategoryFormScreen
├── /wallet         → ExpenseWalletScreen
├── /wallet/report  → ExpenseReportScreen
├── /routine        → RoutineScreen
├── /routine/new    → RoutineCreateScreen
├── /routine/schedule/new → RoutineScheduleCreateScreen
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
