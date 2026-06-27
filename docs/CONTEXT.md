# 현재 컨텍스트

## 2026-06-25 커뮤니티 상세·댓글·투표 참여 연동

- 커뮤니티 피드 카드는 제목 1줄, 본문 2줄 preview로 정리했고, 첫 첨부 이미지를 오른쪽 썸네일로 표시한다. 이미지가 2장 이상이면 썸네일 위에 전체 개수를 표시하며, 투표 글은 제목 왼쪽에 작은 `투표` badge를 표시한다. 카드 열기와 좋아요 tap 영역은 분리했다.
- 실제 상세 route `/community/posts/:postId`를 인증 ShellRoute 안에 추가했다. 상세 화면은 전체 제목·본문·이미지·좋아요·투표·댓글을 한 화면에서 표시하고, direct URL 진입 시 뒤로갈 수 없으면 `/community`로 돌아간다.
- 백엔드는 게시글 상세 조회, 댓글 cursor 목록 조회, 댓글 작성 API를 추가했다. `post_comments` 테이블은 새 `V17__create_post_comments.sql`로 추가했고, 댓글 작성과 `posts.comments_count` 증가는 하나의 트랜잭션으로 처리한다. 없는 게시글은 상세·댓글 API 모두 `POST_NOT_FOUND` 404를 반환한다.
- Flutter `CommunityService`와 `CommunityProvider`에 상세 조회, 투표 참여, 댓글 목록, 댓글 작성을 연결했다. 좋아요·투표·댓글 작성 결과는 피드 목록과 상세 캐시에 함께 반영하며, 댓글 수는 댓글 작성 응답의 서버 `commentsCount`를 사용한다. 투표 option 파서는 백엔드의 `label` 필드도 읽는다.
- 검증 상태: `.\gradlew.bat test --tests com.petyilgi.community.CommunityIntegrationTest` GREEN. Flutter 선택 검증은 `flutter test test\models\post_test.dart test\services\community_service_test.dart test\screens\community\community_screen_test.dart test\router\app_router_test.dart` GREEN(66 tests), 선택 파일 `dart analyze` Exit 0(info 2건), `git diff --check` whitespace 오류 없음, 한글 깨짐 검사 GREEN. 전체 `flutter test`는 기존/범위 밖 실패 4건(`community_mock_screen_test.dart` 3건, `records_screen_test.dart` 1건)으로 GREEN 아님.

## 2026-06-23 레거시 기록 타입 영구 삭제 계획(현재 코드 미반영)

- 당시 계획은 `V17__remove_deprecated_activity_types.sql`로 `play`, `sleep`, `checkup` 기록의 미디어 storage key를 `media_cleanup_queue`에 복사하고, 관련 루틴 참조를 null 처리한 뒤 대상 루틴·완료 이력·기록·타입(`bath`, `groom` 포함)을 영구 삭제하는 것이었다. 현재 실제 `V17`은 `V17__create_post_comments.sql`이므로 이 cleanup을 적용하려면 실제 migration 목록 기준의 새 번호로 재검토해야 한다.
- 앱 시작 `MediaCleanupRunner`는 queue의 파일을 먼저 삭제하고 성공한 key만 queue에서 제거한다. 로컬 저장소 삭제는 `deleteIfExists`라 멱등이며, 파일 또는 DB queue 삭제 실패는 다음 시작에서 재시도한다.
- 백엔드는 create/list filter와 루틴 create/update에서 제거 타입을 400으로 거부한다. Flutter는 타입 정의, quick type preference, 루틴 선택지, 홈/health 표시 및 직접 URL redirect를 9개 타입 기준으로 맞춘다. 일정·지갑 `grooming`과 병원 방문 사유 `checkup`은 유지한다.
- 검증 상태: `MediaCleanupRunnerTest`와 backend `testClasses`는 통과했다. Docker daemon 부재로 Testcontainers 통합 테스트와 Flyway migration 실행은 보류됐고, Flutter wrapper가 120초 무출력 timeout되어 Flutter test/pub get은 보류됐다. 직접 Dart analyze는 worktree의 Flutter 의존성 해석 파일 부재로 실행할 수 없었다.

## 2026-06-05 PetEdit 입력 UI 보정

- 공통 `PetDateField`를 추가해 PetEdit 생년월일/함께한 날, Onboarding 생년월일을 read-only `TextField`가 아닌 `Material + InkWell` 날짜 선택 필드로 바꿨다. 캘린더 아이콘과 `생년월일을 몰라요` 동작은 유지했다.
- PetEdit 기본 프로필의 종 선택은 3열 `GridView`로 고정하고, 성별/중성화는 각각 `Row + Expanded 2개`, 특수상태는 dense `PetChoiceButton` 4개 한 줄로 보정했다. 중성화 활성 정책과 저장 payload 보존 정책은 변경하지 않았다.
- `PetTextField`는 RecordScreen 입력과 맞춰 흰 배경, muted hint, 14px semibold 텍스트, `AppColors.primary` cursor/focused border, 14px radius, tap outside unfocus를 사용한다. selection highlight/handle theme은 바꾸지 않았다.
- 테스트는 구조 기준으로 보강했다. PetEdit 종 3열 grid, 날짜 필드 타입과 date picker sheet 진입, 성별/중성화/특수상태 row 구조, `PetTextField` focused border 색상을 확인하고 Onboarding 생년월일이 `PetDateField`로 렌더링되는지 확인한다.

## 2026-06-05 기록 입력 날짜 흐름 및 기타 기록 연동

- `/records?date=YYYY-MM-DD`와 `/records/{type}/new?date=YYYY-MM-DD`를 지원한다. route date는 strict `YYYY-MM-DD` 검증 후 유효할 때만 사용하고, 없거나 잘못된 값이면 오늘 날짜로 fallback한다.
- 기록 메인에서 선택한 날짜를 급식 및 카테고리 입력 화면으로 전달한다. 입력 화면의 날짜 picker는 제거하고 읽기 전용 날짜 라벨만 표시하며, `현재 시간으로 설정`은 날짜를 바꾸지 않고 시간만 현재 시간으로 갱신한다.
- 급식/카테고리 기록 저장 성공 후에는 `/records?date=<저장 날짜>`로 돌아가 저장한 날짜의 기록 목록을 유지한다. 저장 CTA는 상단 헤더가 아니라 스크롤 콘텐츠 최하단의 `RecordFormSubmitButton`으로 통일했다.
- `etc` 활동 타입을 추가해 `기타` TypeCard가 전체 화면 입력으로 진입한다. `etc`는 `diary`와 같은 note-only 타입이며 detail 테이블 없이 `activity_records.note`만 사용한다. 빠른 기록용 `record_modal.dart`와 지출 날짜 선택 흐름은 유지했다.
- 백엔드는 `V13__add_etc_activity_type.sql`, `ActivityRecordService.SUPPORTED_TYPES`, test seed, `ActivityRecordIntegrationTest`에 `etc` create/get/delete note-only 흐름을 반영했다.

## 2026-06-02 My 메뉴 · 설정 · 로그아웃 구현

- My 메인의 설정, 전체 펫, 프로필 편집 진입점을 `/my/settings`, `/my/pets`, `/my/profile`로 연결했다. 대표 펫은 `activePet ?? pets.firstOrNull`을 사용하고 전체 목록에서는 active pet에만 `현재 선택` badge를 표시한다.
- 인증이 필요한 이미지 bytes 로딩을 `AuthenticatedNetworkImage`로 추출해 Home, My 펫 카드, My 프로필 기존 이미지에 적용했다.
- 로그아웃은 서비스 호출 직후 loading lock을 걸고, 실패 시 기존 인증 상태를 복원한다. 성공, 인증 만료, 저장 토큰 검증 실패는 펫 정리 실패를 기록하고도 signed-out 상태를 보장하는 공통 helper를 사용한다.
- 후속 작업: `PetNotifier.clearForSignedOutUser()` 환경설정 Future 실패/무한 대기 방어, 백엔드 사용자 응답과 `UserProfile.id` 매핑 정리, 프로필 저장 API 연결.

## 2026-06-02 사용자 접근 화면 현황 문서 동기화

- `docs/FRONTEND_STATUS.md`를 파일 존재 여부가 아니라 현재 사용자 동선 기준으로 정리했다. `🚧 부분 구현`, `🧭 진입점 없음` 상태를 추가하고 Home, Community, My, Records, Wallet, Routine의 placeholder와 미연결 화면을 표로 기록했다.
- 기록 문서에서 이전 `QuickRecordRow`, `RecordModal`, records 탭 위젯을 현재 기능처럼 설명하던 내용을 정정했다. 현재 `/records`에서 접근 가능한 타입, 숨겨진 타입, `기타` placeholder, 상세·수정·삭제 UI 부재, 급식 전용 사진 첨부 범위를 분리했다.
- 루틴 일정 목록은 고정 샘플, 일정 저장과 지도 검색은 `준비중`, 지출 저장과 항목·사진 추가는 미구현, Community 게시글 상세·댓글·이미지/투표 표시와 참여는 미연결, My 메뉴 대부분과 로그아웃 UI는 진입점 없음으로 기록했다.
- `docs/ARCHITECTURE.md`에서 실제로 없는 `pet_selector.dart` 참조를 제거하고 현재 라우터에서 호출되지 않는 legacy 위젯 경계를 명시했다. 애플리케이션 코드, 테스트, `DESIGN.md`는 수정하지 않았다.

## 2026-06-02 Home · Community · My 헤더 색상 및 액션 아이콘 통일

- 탭 헤더 규칙을 `DESIGN.md`에 추가했다. 탭 헤더는 `AppColors.background`, 제목은 `AppColors.text`, 우측 액션은 `38x38` surface와 `20px` `AppColors.textSecondary` 아이콘을 사용한다. 탐색 역할의 뒤로가기 아이콘은 기존 `28px`를 유지한다.
- `AppHeaderIconButton.onTap`을 nullable로 바꿔 표시 전용 비활성 액션도 공용 surface를 사용할 수 있게 했다. Home 알림 버튼은 `home-notification-button` key와 바깥 `48x48` 슬롯을 유지한 채 공용 버튼으로 교체했다.
- Community 메인/카테고리 공유 헤더는 `AppColors.background` 배경, border 없음, `AppColors.text` 제목으로 맞췄다. My는 기존 `AppHeader`와 설정 액션을 그대로 유지했다.
- 관련 회귀 검증: 2026-06-02 `flutter test test/widgets/app_header_test.dart test/screens/home/home_screen_test.dart test/screens/community/community_screen_test.dart test/screens/my/my_screen_test.dart` GREEN(33 tests).

## 2026-06-01 화면 헤더 역할별 통일 및 복귀 안정화

- `frontend/lib/widgets/app_header.dart`에 Scaffold `appBar`용 `AppHeader`, 조회형 body 헤더 `AppInlineHeader`, 입력형 body 헤더 `AppFormHeader`를 구분했다. 공용 헤더는 UI만 담당하고 화면별 `pop()` 우선, direct URL fallback, 키보드 dismiss 정책은 각 화면에 남겼다.
- 기록, 성장곡선, 지갑, 지출 리포트, 루틴, 기록 입력, 비용 추가, 온보딩, 펫 상세·수정 화면에 역할별 헤더를 적용했다. 커뮤니티 메인/카테고리와 글쓰기는 bespoke 헤더를 유지하되 direct URL fallback을 보강했다.
- `/records`는 active pet이 없어도 헤더와 뒤로가기를 유지하고 `전체 기록` 액션만 숨긴다. `/pet/:id`는 로딩과 없는 ID를 구분하며, `/pet/:id/edit`는 provider late hydration 중 예외 없이 spinner를 표시하고 같은 ID rebuild가 사용자 편집값을 덮어쓰지 않는다.
- 마지막 반려동물 삭제 시 상세 화면은 추가 `pop()`을 호출하지 않고 router redirect에 맡긴다. 반려동물이 남아 있을 때만 상세 화면을 이탈한다.

## 2026-06-01 기록 입력, 지갑, 루틴 화면 변경

- `RecordTypeGrid`에서 `checkup` 카드는 숨기고, `water`, `diary`는 전체 화면 입력 route로 연결했다. `checkup` 백엔드 타입과 기존 표시 config는 유지한다.
- `RecordCategoryFormScreen`은 `water`의 필수 음수량(`ml`), `diary`의 필수 메모, `poop`의 선택 메모를 저장 payload에 반영한다.
- `MealRecordScreen`은 섭취율 아래에 메모 필드를 항상 표시하고 payload `note`에 저장한다. 급식/카테고리 기록 저장 성공 후에는 `/records`로 이동한다.
- 백엔드는 `V12__add_diary_activity_type.sql`로 `diary` 타입을 추가했다. `diary`는 전용 detail 테이블 없이 `activity_records.note`만 사용한다.
- 홈 메뉴에서 `지갑`이 `/wallet`로 연결되고, `/wallet/report`, `/records/expense/new` 화면이 추가됐다. 지출 저장은 아직 `준비중`이며 백엔드 `expense` 타입은 확정되지 않았다.
- 루틴 메인은 달력/일정 탭과 월간 달력으로 정리됐다. `/routine/new`는 서버 `label`과 `note` 의미를 분리하고 반복 요일을 포함해 루틴 생성 API에 연결된다. `/routine/schedule/new`는 로컬 일정 입력 UI를 제공하며 저장은 아직 `준비중`이다.

## 2026-05-27 커뮤니티 글쓰기 화면 변경

- `frontend/lib/screens/community/write_screen.dart`는 mock 기반 글쓰기 화면으로 변경됐다.
- 상단은 `취소 / 자유 / 등록` 커스텀 바를 사용한다. 게시판 기본값은 `FREE`이고 표시 라벨은 `자유`다.
- 게시판 선택은 `CupertinoPicker` bottom sheet로 열리며, 선택 완료 시에만 `_category`가 갱신된다.
- 제목은 필수다. 제목이 비면 `제목을 입력해 주세요`, 본문이 비면 `내용을 입력해 주세요`를 표시하고 등록하지 않는다.
- 하단 이미지/투표 버튼과 기존 provider/service 계약은 유지한다. 백엔드, DB, API service 변경은 없다.
- 투표 버튼을 누르면 글쓰기 화면 안에 mock 투표 패널이 표시된다. 패널은 `[체크] 투표`, 닫기 `X`, 기본 `항목 입력` 2개, `항목 추가`, `* 글 등록 이후에는 투표를 수정할 수 없어요.` 안내문으로 구성된다.
- 투표 항목 추가는 클라이언트 입력 컨트롤만 늘린다. 등록 payload는 기존 `PollDraft` 경로를 유지하며, 항목이 2개 이상 입력된 경우 question은 임시로 `투표`를 보낸다.
- 검증: 2026-05-27 `flutter test test/screens/community/community_screen_test.dart` GREEN, `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN.

## 5줄 현황 요약

1. 현재 상태: Flutter 마이그레이션 완료. `frontend/`는 React Native → Flutter (Riverpod + go_router)로 전환됐다.
2. 마지막 확인된 전체 검증: 백엔드 2026-05-18 `.\gradlew.bat clean test`, 프론트 2026-06-02 `flutter test`, `flutter analyze --no-fatal-infos`, `flutter build web` 성공. 2026-06-25 커뮤니티 상세·댓글·투표 변경은 선택 검증을 통과했지만 전체 Flutter suite는 기존/범위 밖 실패가 남아 있다.
3. 최신 스키마: Flyway `V1`부터 `V18__create_care_schedules.sql`까지 존재한다. 기존 마이그레이션은 수정하지 않는다.
4. 최근 변경 흐름: PetEdit/Onboarding 날짜 입력 UI 보정, 기록 입력 route date 유지, `etc` note-only 기록, 홈 지갑 진입, 지갑/리포트 화면, 루틴 월간 달력과 전체 화면 생성 route, 커뮤니티 상세·댓글·투표 참여를 보강했다.
5. 다음 우선순위: 기록 상세·수정·삭제, 지출 저장, 커뮤니티 검색/알림/카테고리 필터, 루틴 수정 UI 순서로 남은 사용자 동선을 완성한다.

## 마지막 검증

- 백엔드 전체 테스트: 2026-05-18 `.\gradlew.bat clean test` GREEN.
- 프론트 정적 분석: 2026-05-18 `flutter analyze --no-fatal-infos` Exit 0 (info 4건만, 경고/오류 없음).
- 프론트 테스트: 2026-05-18 `flutter test` GREEN.
- 프론트 웹 빌드: 2026-05-18 `flutter build web` → `√ Built build\web` 성공. `flutter_secure_storage_web` 관련 wasm dry-run 경고만 출력됨.
- 한글 깨짐 검사: 2026-05-18 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN.
- 공통 네비게이션 위젯 반영 후 부분 검증: 2026-05-23 `C:\flutter\bin\cache\dart-sdk\bin\dart.exe analyze` Exit 0 (info 3건만), 한글 깨짐 검사 GREEN. 단, `flutter.bat --version`과 `flutter test test/widgets/app_navigation_test.dart`는 로컬 Flutter wrapper가 응답하지 않아 timeout.
- 기록 입력 패널 통일 후 부분 검증: 2026-05-25 `flutter test test/widgets/record_inputs/record_picker_values_test.dart`, `flutter test test/widgets/record_inputs/record_input_pickers_test.dart`, `flutter test test/screens/records/meal_record_screen_test.dart`, `flutter test test/screens/records/record_category_form_screen_test.dart` GREEN. `flutter analyze --no-fatal-infos` Exit 0 (기존 info 3건만). 한글 깨짐 검사 GREEN.
- 기록 타입 그리드 라벨/순서 표시 변경 후 검증: 2026-05-26 한글 깨짐 검사 GREEN. 사용자 요청에 따라 테스트/분석 명령은 실행하지 않음.
- 숫자 키패드 preview 및 캘린더 연도 범위 변경 후 부분 검증: 2026-05-26 `flutter test test/core/calendar_ranges_test.dart`, `flutter test test/widgets/record_inputs/record_input_pickers_test.dart`, `flutter test test/widgets/record_inputs/record_picker_values_test.dart`, `flutter test test/screens/records/meal_record_screen_test.dart`, `flutter test test/screens/records/record_category_form_screen_test.dart`, `flutter test test/screens/expense/expense_add_screen_test.dart` GREEN. `flutter analyze --no-fatal-infos` Exit 0 (기존 info 3건만). 한글 깨짐 검사 GREEN.
- 기록 TypeCard 전체 화면 입력 변경 후 부분 검증: 2026-06-01 `flutter test test/screens/records/records_screen_test.dart`, `flutter test test/screens/records/meal_record_screen_test.dart`, `flutter test test/screens/records/record_category_form_screen_test.dart`, `flutter test test/router/app_router_test.dart`, `.\gradlew.bat test --tests com.petyilgi.record.ActivityRecordIntegrationTest` GREEN. 한글 깨짐 검사 GREEN.
- 루틴 상태 안정화 후 전체 검증: 2026-06-01 `flutter test` GREEN(151 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN. 루틴 화면 분리 테스트와 날짜 고정 기록 캘린더 fixture 안정화도 함께 반영했다.
- 화면 헤더 역할별 통일 및 복귀 안정화 후 전체 검증: 2026-06-01 `flutter test` GREEN(171 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check` whitespace 오류 없음. 직접 `AppBar`, records private 헤더, 오래된 위젯 맵 참조 검색도 빈 결과다.
- Home · Community · My 헤더 색상 및 액션 아이콘 통일 후 전체 검증: 2026-06-02 `flutter test` GREEN(172 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN(`flutter_secure_storage_web` wasm dry-run 경고만 출력), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check` whitespace 오류 없음.
- 사용자 접근 화면 현황 문서 동기화 후 검증: 2026-06-02 오래된 화면 현황 참조 `rg` 검색 빈 결과, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check`, `git diff --cached --check` whitespace 오류 없음, `git status --short backend frontend DESIGN.md` 빈 결과. 문서 전용 작업이므로 애플리케이션 테스트는 다시 실행하지 않았다.
- My 메뉴 · 설정 · 로그아웃 구현 후 전체 검증: 2026-06-02 `flutter test` GREEN(191 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `flutter build web` GREEN(`flutter_secure_storage_web` wasm dry-run 경고만 출력), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check`, `git diff --cached --check` whitespace 오류 없음.
- 기록 입력 날짜 흐름 및 기타 기록 연동 후 부분 검증: 2026-06-05 `.\gradlew.bat test --tests com.petyilgi.record.ActivityRecordIntegrationTest` GREEN, `flutter test test/screens/records/records_screen_test.dart test/screens/records/meal_record_screen_test.dart test/screens/records/record_category_form_screen_test.dart test/router/app_router_test.dart` GREEN(67 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN, `git diff --check` whitespace 오류 없음(CRLF 경고만 출력).
- PetEdit 입력 UI 보정 후 부분 검증: 2026-06-05 `flutter test test/screens/pet/pet_screen_test.dart test/screens/onboarding/onboarding_screen_test.dart` GREEN(24 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 3건), `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN.
- 커뮤니티 상세·댓글·투표 연동 후 부분 검증: 2026-06-25 `.\gradlew.bat test --tests com.petyilgi.community.CommunityIntegrationTest` GREEN, `flutter test test\models\post_test.dart test\services\community_service_test.dart test\screens\community\community_screen_test.dart test\router\app_router_test.dart` GREEN(66 tests), 선택 파일 `dart analyze` Exit 0(info 2건), `git diff --check` whitespace 오류 없음, `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` GREEN. 전체 `flutter test`는 기존/범위 밖 `community_mock_screen_test.dart` 3건과 `records_screen_test.dart` 1건 실패로 통과하지 않았다.
- 루틴 일정 서버 연동 후 부분 검증: 2026-06-26 `.\gradlew.bat test --tests com.petyilgi.routine.CareScheduleIntegrationTest` GREEN, `flutter test test\services\care_schedule_service_test.dart` GREEN, `flutter test test\providers\pet_provider_test.dart test\screens\routine\routine_schedule_create_screen_test.dart test\screens\routine\routine_screen_test.dart test\router\app_router_test.dart` GREEN(72 tests), `flutter analyze --no-fatal-infos` Exit 0(기존 info 4건).

## 다음 행동

- 문서 정리 작업이면 `AGENTS.md`, `docs/AI_WORKFLOW.md`, `docs/BACKEND_RULES.md`, `docs/AI_MISTAKES.md` 기준을 우선 확인한다.
- 백엔드 작업이면 `docs/BACKEND_RULES.md`와 `docs/FRONTEND_STATUS.md`를 읽고 TDD 순서를 따른다.
- Flutter UI 작업이면 `DESIGN.md`를 먼저 읽고 디자인 시스템 준수 여부를 성공 기준에 포함한다.
- 앱 검증 작업이면 백엔드(`./gradlew.bat bootRun`)와 Flutter(`flutter run`)를 함께 실행한 뒤 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 확인한다.

## 주의사항

- `backend/src/main/resources/db/migration/V1`부터 `V18`까지 기존 Flyway 파일은 수정하지 않는다.
- 새 DB 변경은 다음 번호의 새 마이그레이션으로만 추가한다.
- 문서 정리만 하는 작업에서는 `backend/`, `frontend/`, `DESIGN.md`를 수정하지 않는다.
- 기존 dirty worktree 변경은 사용자 또는 이전 작업자의 작업으로 보고 되돌리지 않는다.
- Windows 콘솔의 기본 출력만 보고 한글 파일이 깨졌다고 판단하지 않는다.
- 한글 문서를 편집한 뒤에는 한글 깨짐 검사를 실행한다.
- 배포, S3, MinIO, LocalStack, 도메인, SSL, 운영 스토리지는 별도 배포 단계까지 보류한다.

## 최신 Handover

- Goal: 기록 화면에서 `expense` 레거시 타입을 제거하고 `/records/expense/new` 직접 접근은 지갑 비용 추가 화면으로 안전하게 redirect한다.
- Done: `record_support.dart`에 카테고리 기록 입력 지원 타입과 판정 함수를 추가했고, 기록 메인 화면은 `meal`과 지원 카테고리 타입만 노출하도록 정리했다. `/records/:typeId/new` 라우트는 `expense`를 `/wallet/expenses/new`로 보내고, 지원하지 않는 타입은 `/records`로 redirect하되 strict valid `date=YYYY-MM-DD`만 보존한다. 관련 router/records 테스트와 `docs/FRONTEND_STATUS.md`를 현재 지갑 도메인 기준으로 갱신했다.
- Remaining: 백엔드와 지갑 화면/provider/service는 이번 범위에서 변경하지 않았다. `checkup` config 자체 삭제는 범위 밖이라 기록 화면 노출 기준으로만 숨긴다.
- Next step: 실제 앱 실행 시 `/records`, `/records/expense/new`, `/records/checkup/new?date=2026-05-09`, `/wallet/expenses/new` 진입을 수동 확인한다.
- Warnings: 커뮤니티/미디어/프로필 이미지 관련 dirty 파일은 병렬/이전 작업 변경으로 보고 건드리지 않았다. 사용자 요청 없이 Git add, commit, push를 하지 않았다.

## 이전 Handover

- Goal: backend-roadmap의 지갑 지출 1차 백엔드, 프론트 전환, cleanup, 최종 검증 문서 흐름을 구현자가 바로 따라갈 수 있게 03~11번 문서 계약과 작업 순서로 정리한다.
- Done: `docs/backend-roadmap/03_TARGET_ERD.md`~`08_BACKEND_IMPLEMENTATION_TASKS.md`에 `itemName` nullable, DELETE `204 No Content`, `ProblemDetail.errorCode`, 공통 `ApiException`, pet 검증 순서, `INVALID_INPUT`/`VALIDATION_FAILED` 구분, base64url opaque cursor, soft delete pet 정책, V16 migration 계획, 통합 테스트 기대값, 백엔드 Red-Green 구현 순서를 반영했다. 이어서 `docs/backend-roadmap/09_FRONTEND_INTEGRATION_PLAN.md`를 템플릿에서 실제 프론트 연결 계획으로 교체했고, `WalletExpense` 모델/service/provider, route `recordId -> expenseId`, `ActivityRecord.typeId == "expense"` 분리, wallet 화면/테스트/FRONTEND_STATUS 갱신 순서를 구체화했다. `docs/backend-roadmap/10_DEAD_CODE_CLEANUP_PLAN.md`는 `/records/expense/new`, `ExpenseFormData.toRecordBody()`, `ActivityRecord.typeId == "expense"` 필터, `expense_record_utils.dart`, wallet 테스트 fixture 제거 기준과 검증 명령을 포함한 확정 초안으로 구체화했다. 이번 작업에서는 `bath`/`groom`을 10번 지갑 cleanup이 아닌 별도 기록 cleanup 후보로 분리했고, `docs/backend-roadmap/11_VERIFICATION_PLAN.md`를 백엔드 선택/전체 테스트, 프론트 선택/전체 테스트, cleanup 역참조 검색, 문서/변경 범위 검증, 최종 보고 형식을 포함한 확정 초안으로 교체했다.
- Remaining: 실제 `V16__create_wallet_expenses.sql`, `init-test.sql`, 백엔드 구현 코드, 통합 테스트 코드, Flutter 모델/service/provider/screen/test 코드는 아직 작성하지 않았다.
- Next step: 문서를 계속 점검한다면 01~11번 전체를 다시 읽고 누락/충돌을 확인한다. 구현으로 넘어가면 08번의 `WalletExpenseIntegrationTest` 첫 Red 테스트부터 시작한다.
- Warnings: `docs/backend-roadmap/`는 `.gitignore`에 의해 ignored 상태라 일반 `git status --short`에는 문서 변경이 보이지 않는다. 현재 tracked 변경으로는 기존 `.gitignore`와 `docs/CONTEXT.md`가 보인다. 문서 정리 중에는 애플리케이션 코드, migration, test 파일을 수정하지 않았다.
