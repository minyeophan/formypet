# 현재 컨텍스트

## 현재 상태

- 프론트엔드는 Flutter, Riverpod, go_router 기준이며 백엔드는 Java 21, Spring Boot, MySQL, Flyway 기준이다.
- Flyway migration은 `V1`부터 `V21__add_comment_management.sql`까지 존재한다. 기존 migration은 수정하지 않는다.
- 사용자 기능은 인증, 펫, 기록, 루틴·일정, 커뮤니티, 미디어, 지갑·지출까지 backend와 Flutter에 연결돼 있다.
- 화면 V2 진행 상태는 `docs/SCREEN_V2_STATUS.md`, 프론트 API 연결 상태는 `docs/FRONTEND_STATUS.md`를 기준으로 한다.
- backend 후속 계약과 구현 계획은 `docs/backend-roadmap/02_DOMAIN_DECISIONS.md`~`11_VERIFICATION_PLAN.md`를 기준으로 한다.

## 최근 완료 작업

- 커뮤니티 댓글 수정·soft delete·신고 접수 backend를 구현했다. 댓글 작성자는 수정할 수 있고 댓글 또는 게시글 작성자는 삭제할 수 있으며, 삭제 root의 활성 답글은 tombstone 아래 유지된다.
- 신고는 5개 사유와 선택 상세를 저장하고 `OTHER` 상세 필수, 자기 신고 금지, 사용자별 중복 신고 금지를 적용한다. 신고 시 댓글 내용 snapshot을 함께 보존한다.
- Flutter의 tombstone 표시와 댓글 수정·삭제 메뉴/API 연결을 반영했다. 신고 사유 입력과 400/409 오류 표시는 별도 후속 작업이다.
- 커뮤니티 댓글 신고 backend 계약 테스트를 보강했다. 신고 상세 trim 저장·응답, 상세 500자 초과 validation, 삭제된 댓글 신고 거부를 통합 테스트로 고정했다.
- 지갑 지출 backend invalid input 계약 테스트를 보강했다. `limit=51`, 잘못된 날짜 query, 지원하지 않는 category 요청이 `INVALID_INPUT`으로 응답하는지 확인한다.
- backend roadmap 08~10을 현재 코드와 대조했다. 08 백엔드 구현과 09 프론트 전환은 완료 상태로 기록하고, 10 cleanup은 대부분 정리됐으며 `/records/expense/new` legacy redirect만 보류로 남겼다.

- test Java 진단 307개를 BLOCKER 0, ACTIONABLE 0, CONTRACT_CANDIDATE 49, TEST_FRAMEWORK_BOUNDARY 256, MANAGED_LIFECYCLE 1, LIFECYCLE_POLICY_CANDIDATE 1, UNKNOWN 0으로 분류했다.
- 2026-07-13 사용자 IDE 관측 Java Problems는 349개다. 이는 2026-07-08 안정 snapshot 328개보다 높지만, 확인된 신규 루틴 변경분은 `RoutineService.java`에 Problems가 없고 `RoutineIntegrationTest.java`의 MockMvc/Jackson/Spring test null annotation 경계만 보였다.
- Problems 숫자는 다음 정식 snapshot 전까지 임시 관측값으로 본다. 새 BLOCKER/ACTIONABLE 여부는 Problems 항목의 파일·메시지를 기준으로 별도 분류한다.
- 여러 통합 테스트 클래스가 공유하는 MySQL container의 생성·시작 책임을 package-private `SharedMySqlContainer`로 분리했다. `IntegrationTestSupport`는 datasource property 연결만 담당한다.
- JVM 안에서 동일한 실행 중 container instance가 반환되는지 테스트로 고정하고, singleton 예외와 `maxParallelForks = 1`, 기본 `forkEvery = 0`, Ryuk cleanup 정책을 `docs/BACKEND_RULES.md`에 기록했다.
- 완료된 작업 계획, 중복 포인터, 오래된 상태판, devlog 초안과 참조되지 않는 HTML mockup을 정리했다. 유효한 Git 규칙은 `AGENTS.md`, backend roadmap 링크는 `docs/README.md`에 통합했다.

## Java 진단 후속 원칙

- 제품 기능 작업을 우선한다. 현재 Java Problems의 BLOCKER와 ACTIONABLE은 0개이므로 test 계약 후보 49개와 프레임워크 경계 256개를 줄이기 위한 일괄 수정은 진행하지 않는다.
- 기능 변경 중 해당 URL helper를 직접 수정할 때만 반환 계약을 같은 작업 범위에서 검토한다.
- 별도 진단 정리가 필요하면 파일 하나만 TDD 파일럿으로 진행하고 전후 안정 Problems snapshot에서 경고 이동과 신규 진단이 없는지 확인한다.
- suppression, cast, `Objects.requireNonNull`, dependency 또는 JDT 설정으로 진단만 숨기지 않는다. 새 BLOCKER나 ACTIONABLE이 발생하면 기능 작업보다 우선해 처리한다.

## 마지막 검증

- 2026-07-08 backend 전체 `test --rerun-tasks`가 `BUILD SUCCESSFUL`로 통과했다.
- 2026-07-12 backend 전체 `.\gradlew test --rerun-tasks`가 `BUILD SUCCESSFUL`로 통과했다.
- 2026-07-12 댓글 신고 targeted 테스트 3개와 `WalletExpenseIntegrationTest` 전체 강제 재실행이 통과했다.
- MySQL singleton 테스트와 rollback 기반 `PetIntegrationTest`, 명시적 cleanup 기반 `AuthIntegrationTest` 조합이 통과했다.
- 2026-07-08 변경 후 Java Problems 안정 snapshot 2회는 328개(main 21, test 307)로 일치했다. 기존 lifecycle warning 1개만 `IntegrationTestSupport`에서 `SharedMySqlContainer`로 이동했다.
- 2026-07-13 사용자 IDE 관측 Problems는 349개다. 이 숫자는 정식 fresh snapshot 2회로 검증된 값이 아니며, 루틴 반복 규칙 변경에서 확인된 항목은 기존 `TEST_FRAMEWORK_BOUNDARY` 유형이었다.
- snapshot 산출물은 `C:\tmp\paa-shared-mysql-container-0f9ab5d-20260708`, test 진단 감사는 `docs/superpowers/specs/2026-07-07-java-test-diagnostics-audit.md`에 있다.
- 최근 기록된 Flutter 전체 검증은 2026-07-05 `flutter test` 354개 통과와 `flutter analyze` `No issues found!`다. 2026-07-09 댓글 수정·삭제 관련 targeted 테스트와 사용자 터미널 `flutter analyze`가 통과했다.

## 다음 행동

- 현재 제품 기능 backlog로 복귀한다. 사용자가 UI 작업은 아직 진행하지 않기로 했으므로 우선은 backend 계약·검증 backlog와 문서 정리를 먼저 본다.
- UI 작업을 재개할 때 후보는 댓글 신고 UI, 커뮤니티 검색 UI·알림·카테고리 필터, 기록 direct URL 예외, 루틴 수정 UI다.
- backend roadmap 작업을 재개할 때는 08번 구현 작업, 09번 프론트 연결, 10번 dead code cleanup의 미완료 체크부터 현재 코드와 대조한다.
- Flutter UI 작업은 `DESIGN.md`와 `docs/SCREEN_V2_STATUS.md`, backend 작업은 `docs/BACKEND_RULES.md`와 `docs/FRONTEND_STATUS.md`를 먼저 읽는다.

## 보류 작업

- Android 기기 또는 emulator에서 backend와 Flutter를 함께 실행하는 수동 E2E 검증
- 회원가입·로그인, 펫 onboarding, 기록 CRUD, 루틴 CRUD, 커뮤니티 feed·좋아요, 배변 사진 표시, logout 후 재진입 전체 동선 확인
- 운영 배포, domain·SSL, S3·MinIO·LocalStack 등 운영 storage, push notification 운영 구성

## 주의사항

- 기존 `V*.sql` Flyway migration은 수정하지 않고 DB 변경은 다음 번호의 새 migration으로만 추가한다.
- `maxParallelForks = 1`, 기본 `forkEvery = 0`, Ryuk cleanup을 유지한다. experimental reuse, 별도 shutdown hook, suppression을 추가하지 않는다.
- 문서 정리 작업에서는 `backend/`, `frontend/`, `DESIGN.md`를 수정하지 않는다.
- 기존 dirty 변경은 사용자 또는 이전 작업자의 작업으로 보고 되돌리지 않는다.
- 한글 문서를 편집한 뒤에는 `scripts/check-korean-mojibake.ps1`을 실행한다.

## 최신 Handover

- Goal: UI 작업을 보류하고 backend 계약·검증 backlog와 roadmap 상태를 정리한다.
- Done: 커뮤니티 댓글 신고 backend 계약 테스트와 지갑 지출 invalid input 계약 테스트를 보강했다. backend 전체 `test --rerun-tasks`가 통과했고, 테스트 변경분은 커밋된 상태다. backend roadmap 08~10에는 현재 코드 대조 결과를 추가했다.
- Remaining: UI 신고 사유 입력과 400/409 오류 표시, 실제 기기 수동 회귀는 보류다. `/records/expense/new` legacy redirect 제거는 UI cleanup 재개 또는 제거 결정 전까지 보류다.
- Next step: backend backlog를 계속 진행한다면 wallet/커뮤니티의 남은 계약 구멍을 작은 targeted 테스트로 먼저 고정한다. 문서 변경을 마무리하려면 roadmap/CONTEXT 변경분을 검토 후 별도 커밋한다.
- Warnings: 삭제 root는 활성 답글이 남을 때만 tombstone으로 유지한다. UI 보류 중에는 `frontend/`와 `DESIGN.md`를 건드리지 않는다.
