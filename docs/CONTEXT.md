# 현재 컨텍스트

## 5줄 현황 요약

1. 현재 상태: Flutter 마이그레이션 완료. `frontend/`는 React Native → Flutter (Riverpod + go_router)로 전환됐다.
2. 마지막 확인된 전체 검증: 2026-05-18 백엔드 `.\gradlew.bat clean test`, 프론트 `flutter analyze --no-fatal-infos`, `flutter test`, `flutter build web` 성공.
3. 최신 스키마: Flyway `V1`부터 `V11__add_oauth_accounts.sql`까지 존재한다. 기존 마이그레이션은 수정하지 않는다.
4. 최근 변경 흐름: 카카오/OAuth 변경을 유지한 상태에서 계정별 펫 상태 분리, `/` 스플래시 라우트, `/pets/new`, 기록 단건 조회와 미디어 정리를 보강했다.
5. 다음 우선순위: Android 에뮬레이터 또는 기기에서 백엔드 실행 후 수동 E2E 검증 (회원가입, 카카오 로그인, 펫 등록/추가, 기록 CRUD/사진, 루틴, 커뮤니티).

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

## 다음 행동

- 문서 정리 작업이면 `AGENTS.md`, `docs/AI_WORKFLOW.md`, `docs/BACKEND_RULES.md`, `docs/AI_MISTAKES.md` 기준을 우선 확인한다.
- 백엔드 작업이면 `docs/BACKEND_RULES.md`와 `docs/FRONTEND_STATUS.md`를 읽고 TDD 순서를 따른다.
- Flutter UI 작업이면 `DESIGN.md`를 먼저 읽고 디자인 시스템 준수 여부를 성공 기준에 포함한다.
- 앱 검증 작업이면 백엔드(`./gradlew.bat bootRun`)와 Flutter(`flutter run`)를 함께 실행한 뒤 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 확인한다.

## 주의사항

- `backend/src/main/resources/db/migration/V1`부터 `V11`까지 기존 Flyway 파일은 수정하지 않는다.
- 새 DB 변경은 다음 번호의 새 마이그레이션으로만 추가한다.
- 문서 정리만 하는 작업에서는 `backend/`, `frontend/`, `DESIGN.md`를 수정하지 않는다.
- 기존 dirty worktree 변경은 사용자 또는 이전 작업자의 작업으로 보고 되돌리지 않는다.
- Windows 콘솔의 기본 출력만 보고 한글 파일이 깨졌다고 판단하지 않는다.
- 한글 문서를 편집한 뒤에는 한글 깨짐 검사를 실행한다.
- 배포, S3, MinIO, LocalStack, 도메인, SSL, 운영 스토리지는 별도 배포 단계까지 보류한다.

## 최신 Handover

- Goal: 숫자 키패드 bottom sheet에 입력 중 preview를 추가하고, 기록 날짜/펫 생년월일 선택 범위를 `1950년~현재 기준`으로 정리한 내용을 문서까지 반영한다.
- Done: `RecordPickerSheet`에 `headerCenter` 슬롯을 추가하고 숫자 키패드에서 입력 중인 원본 값과 suffix/hint를 헤더 preview로 표시한다. 완료 전에는 외부 `TextEditingController`를 바꾸지 않고, 완료 시 정규화된 값만 반영한다. `core/calendar_ranges.dart`를 추가해 공통 시작일 `1950-01-01`, 기록 날짜 마지막일 현재년도 말, 생일 마지막일 오늘, `clampCalendarDate`를 관리한다. 온보딩/펫수정 생년월일 picker와 기록 날짜 picker에 같은 범위를 적용했다. `docs/FRONTEND_STATUS.md`에 관련 구현 현황과 API 계약 유지 내용을 기록했다.
- Remaining: Android 에뮬레이터/기기에서 백엔드와 함께 실제 E2E 검증은 여전히 미실시. 실제 기록 타입을 `groom -> water`, `etc -> abnormal`처럼 분리할지 여부와 백엔드 지원 타입/마이그레이션도 아직 결정하지 않았다.
- Next step: 실제 기기 또는 에뮬레이터에서 `.\gradlew.bat bootRun` + `flutter run`으로 회원가입/로그인, 펫 온보딩/추가/수정 생년월일 선택, 기록 날짜/숫자 입력, 기록 CRUD/사진, 루틴, 커뮤니티 화면 흐름을 수동 검증한다.
- Warnings: 기존 dirty worktree 변경이 있고, 이번 작업과 무관한 파일은 되돌리지 않는다. 날짜/숫자 입력 변경은 프론트 UI 동작만 바꿨으며 저장 payload, API, DB 타입은 변경하지 않았다. 현재 `RecordTypeGrid`의 `음수(groom)`, `이상현상(etc)`는 표시용 임시 매핑이며 API, payload, DB 계약으로 해석하지 않는다.
