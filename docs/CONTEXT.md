# 현재 컨텍스트

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
2. 마지막 확인된 전체 검증: 2026-05-18 백엔드 `.\gradlew.bat clean test`, 프론트 `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build web` 성공.
3. 최신 스키마: Flyway `V1`부터 `V12__add_diary_activity_type.sql`까지 존재한다. 기존 마이그레이션은 수정하지 않는다.
4. 최근 변경 흐름: `water`/`diary` 전체 화면 기록 입력, 급식/배변 메모, 홈 지갑 진입, 지갑/리포트 화면, 루틴 월간 달력과 전체 화면 생성 route를 보강했다.
5. 다음 우선순위: Android 에뮬레이터 또는 기기에서 백엔드 실행 후 수동 E2E 검증 (인증, 펫, 기록 CRUD/사진, 루틴, 커뮤니티)과 `expense` 저장 계약 결정.

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

## 다음 행동

- 문서 정리 작업이면 `AGENTS.md`, `docs/AI_WORKFLOW.md`, `docs/BACKEND_RULES.md`, `docs/AI_MISTAKES.md` 기준을 우선 확인한다.
- 백엔드 작업이면 `docs/BACKEND_RULES.md`와 `docs/FRONTEND_STATUS.md`를 읽고 TDD 순서를 따른다.
- Flutter UI 작업이면 `DESIGN.md`를 먼저 읽고 디자인 시스템 준수 여부를 성공 기준에 포함한다.
- 앱 검증 작업이면 백엔드(`./gradlew.bat bootRun`)와 Flutter(`flutter run`)를 함께 실행한 뒤 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 확인한다.

## 주의사항

- `backend/src/main/resources/db/migration/V1`부터 `V12`까지 기존 Flyway 파일은 수정하지 않는다.
- 새 DB 변경은 다음 번호의 새 마이그레이션으로만 추가한다.
- 문서 정리만 하는 작업에서는 `backend/`, `frontend/`, `DESIGN.md`를 수정하지 않는다.
- 기존 dirty worktree 변경은 사용자 또는 이전 작업자의 작업으로 보고 되돌리지 않는다.
- Windows 콘솔의 기본 출력만 보고 한글 파일이 깨졌다고 판단하지 않는다.
- 한글 문서를 편집한 뒤에는 한글 깨짐 검사를 실행한다.
- 배포, S3, MinIO, LocalStack, 도메인, SSL, 운영 스토리지는 별도 배포 단계까지 보류한다.

## 최신 Handover

- Goal: Home · Community · My 탭 헤더의 neutral-first 색상과 우측 액션 아이콘 규격을 통일한다.
- Done: 탭 헤더 디자인 계약을 추가하고 `AppHeaderIconButton`이 nullable `onTap`을 허용하게 했다. Home 알림은 공용 비활성 액션 surface로 교체했고, Community 메인/카테고리 헤더는 neutral 배경과 제목 색상으로 통일했다. My의 기존 `AppHeader` 설정 액션은 유지했다.
- Remaining: 일정 DB/API/provider와 지출 저장 계약은 여전히 미구현이다. Android 에뮬레이터/기기 E2E도 미실시다.
- Next step: 실제 기기 또는 에뮬레이터에서 `.\gradlew.bat bootRun` + `flutter run`으로 Home · Community · My 탭 헤더와 기존 인증, 펫, 기록, 루틴, 커뮤니티 흐름을 수동 검증한다.
- Warnings: 일정 저장과 지출 저장은 입력 후 `준비중` 토스트만 표시한다. 이미지 썸네일 관련 위젯 맵 문서 부채는 별도 범위로 남아 있다. 후속 백엔드 작업으로 루틴 요청 invariant 검증과 `record_utils.dart`의 `bath`, `groom` 타입 정리가 필요하다. 기존 dirty 변경은 되돌리지 않는다.
