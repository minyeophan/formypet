# JPA 중심 도메인별 전환 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기능과 데이터 호환성을 유지하면서 모든 프로덕션 Java 코드의 소속과 책임을 정리하고, 도메인별 JPA 전환을 develop PR 및 MuMu 검증 사이클로 완료한다.
**Architecture:** com.formypet.domain.<기능> 아래 controller, entity, dto/request, dto/response, repository, service, service/impl을 둔다. 기본 CRUD는 Spring Data JPA, 복잡한 조회·원자적 갱신·작업 큐는 검증된 전용 Repository 구현을 사용한다.
**Tech Stack:** 저장소 현재 기준 Java 21, Spring Boot 3.5.16, Spring Data JPA, MySQL, Flyway, Gradle, Testcontainers, Flutter, MuMu.
**Spec:** 이 문서의 합의 사항과 현재 대화의 사용자 요구: develop에서 도메인별 브랜치 생성 → PR 검사 → 머지 → 실제 기능 확인 → 반복. 이번 요청은 계획 작성만이며 실행은 별도 목표 실행 시 시작한다.

## Global Constraints

- 패키지 이동, 저장 방식 변경 외에 API 경로, JSON 필드, 오류 코드, 권한, 정렬, 페이지네이션, 데이터 의미를 유지한다.
- 한 번에 하나의 도메인 PR만 진행한다. 이전 PR의 머지 후 검증 완료 전 다음 도메인을 시작하지 않는다. 큰 도메인은 동일 도메인 안에서 여러 PR로 분리한다.
- 모든 브랜치는 그 시점 최신 origin/develop에서 시작한다. 이전 기능 브랜치 위에 다음 작업을 쌓지 않는다.
- Service 인터페이스와 service/impl 구현체를 사용한다. 의미 있는 상태 변경과 규칙을 엔티티/값 객체에 둔다. HTTP DTO를 엔티티가 의존하지 않는다.
- 기본 CRUD는 JpaRepository를 사용한다. QueryDSL은 기본 도입하지 않는다. JPQL/projection/명시적 SQL로 필요한 조회를 구현하고 추가 의존성은 별도 근거를 기록한다.
- JdbcTemplate와 SQL 문자열은 Controller/Service에서 제거한다. 남기는 JDBC/네이티브 SQL은 repository 하위에 격리하고 이유와 검증 항목을 기록한다.
- JPA entity는 순수 도메인 객체와 별도로 중복 생성하지 않는다. 필요 없는 추상화·빈 패키지는 만들지 않는다.
- 기존 테이블/열/외래키와 Flyway 이력 유지. ORM 자동 스키마 갱신 금지. 필요한 DB 변경은 호환 가능한 별도 마이그레이션으로 검토한다.
- 현재 refactor/security-hardening 체크아웃을 보존한다. 이전 미추적 산출물은 사용자 요청으로 정리되었으며, 실행 시 새로 생긴 변경 사항은 별도 확인한다. 전환 코드는 별도 worktree에서 작업한다. 해당 브랜치 변경이 develop에 필요한지는 실행 시작 때 비교하고 무단 포함하지 않는다.
- 운영 데이터로 검증하지 않는다. 테스트 계정·전용 DB를 사용하고 비밀번호/토큰을 증적에 넣지 않는다.
- CI/리뷰/에뮬레이터 확인을 생략하거나 실패를 통과로 취급하지 않는다. 외부 서비스/장비 접근 불가 시 해당 단계는 미완료로 남긴다.

## 브랜치·커밋·PR 규칙

- 새 브랜치: refactor/<작업명>. 기본 형식은 refactor/jpa-<domain>, 분할 시 refactor/jpa-<domain>-<scope>.
- 커밋 제목: refactor : <변경 내용>. 콜론 앞뒤 공백을 유지한다. 이 전환 작업의 테스트 보강·리뷰 수정·문서 커밋에도 같은 규칙을 적용한다.
- 예시: refactor : 지출 도메인 패키지 정리 및 JPA 전환
- 예시: refactor : 지출 커서 페이지네이션 회귀 테스트 보강
- 예시: refactor : 지출 조회 리뷰 지적 반영
- PR 제목도 refactor : <도메인과 변경 내용> 형식으로 통일한다. base는 항상 develop.
- squash merge 시 최종 커밋 제목도 같은 형식으로 지정한다. 저장소가 만드는 merge commit의 형식은 저장소 정책을 따른다.
- 복구 브랜치도 refactor/jpa-<domain>-followup 또는 refactor/jpa-<domain>-revert. 직접 작성하는 복구 커밋도 refactor : 형식을 사용하고 본문에 원본 SHA와 복구 사유를 적는다.
- 기존 원격 브랜치가 같은 이름으로 존재하면 임의 덮어쓰기하지 않는다. 작업 상태를 확인해 이어가거나 의미 있는 scope를 붙인다.

| 순서 | 기본 브랜치 | 대표 커밋 및 PR 제목 |
|---|---|---|
| 1 | refactor/jpa-wallet | refactor : 지출 도메인 패키지 정리 및 JPA 전환 |
| 2 | refactor/jpa-pet | refactor : 반려동물 도메인 구조 및 JPA 접근 정리 |
| 3 | refactor/jpa-routine | refactor : 루틴 및 케어 일정 도메인 JPA 전환 |
| 4 | refactor/jpa-record | refactor : 활동 기록 도메인 JPA 전환 |
| 5 | refactor/jpa-community | refactor : 커뮤니티 책임 분리 및 JPA 전환 |
| 6 | refactor/jpa-media | refactor : 미디어 도메인 JPA 전환 및 저장 처리 분리 |
| 7 | refactor/jpa-policy | refactor : 약관 및 동의 도메인 JPA 전환 |
| 8 | refactor/jpa-notification | refactor : 알림 도메인 JPA 전환 및 발송 처리 분리 |
| 9 | refactor/jpa-support | refactor : 문의 도메인 JPA 전환 및 메일 처리 분리 |
| 10 | refactor/jpa-user | refactor : 회원 도메인 구조 및 계정 처리 정리 |
| 11 | refactor/jpa-auth | refactor : 인증 및 계정 복구 도메인 JPA 접근 정리 |
| 12 | refactor/jpa-global | refactor : 공통 패키지 및 잔여 DB 접근 정리 |

예: 커뮤니티를 나누면 refactor/jpa-community-post → 머지 후 검증 → refactor/jpa-community-comment → 머지 후 검증 → refactor/jpa-community-poll 순서로 진행한다. 각 브랜치는 매번 최신 develop에서 생성한다.

## Review Focus

1. 다른 사용자 접근, 삭제된 반려동물, 차단된 작성자: 기존 권한/노출 규칙 유지. 각 도메인 통합 테스트에 포함.
2. 커서 경계, 동일 시각, NULL 시간, UTC/KST 날짜 경계: 누락/중복/날짜 이동 방지. wallet/routine/record 및 공통 시간 테스트에 포함.
3. 동시 좋아요·투표·완료·용량 예약: 중복 처리와 한도 초과 방지. community/routine/media 경합 테스트에 포함.
4. DB 롤백과 외부 파일/메일/푸시: 커밋 전 발송, 고아 파일, 이중 발송 방지. media/notification/support 테스트에 포함.
5. JPA 변경 감지와 JDBC bulk 갱신 혼용: stale entity, flush 순서, 락 순서와 전파 유지. auth/user/media 테스트에 포함.

## 목표 파일 구조

backend/src/main/java/com/formypet/domain/<auth|user|pet|wallet|routine|record|community|media|notification|policy|support>/
- controller/*Controller.java
- entity/*.java (엔티티, 필요한 enum/값 객체는 별도 하위 패키지 허용)
- dto/request/*Request.java
- dto/response/*Response.java
- repository/*Repository.java (Spring Data JPA)
- repository/query/*QueryRepository.java (조회 projection 및 복잡한 목록)
- repository/jdbc/Jdbc*.java (SQL 유지 근거가 있는 경우만)
- service/*Service.java (인터페이스)
- service/impl/*ServiceImpl.java (트랜잭션과 유스케이스 조율)
- client/, storage/, scheduling/ 등은 해당 도메인에 실제 필요한 경우만 생성

공통 설정·보안·예외·응답·시간·요청 제한·모니터링은 com.formypet.global 아래 책임별로 배치한다. 글로벌 코드가 특정 도메인의 업무 규칙을 소유하지 않는다. User의 최종 소속은 domain.user.entity이며 auth 이동과 분리해 한 번만 이동한다.
테스트 패키지도 도메인 이동에 맞추되 공유 테스트 유틸은 별도 유지한다.

## 실행 전 기준선

- [ ] fetch 후 develop 존재, 최신 SHA, 브랜치 보호/필수 검사/머지 권한을 확인한다. 설정을 우회하거나 비활성화하지 않는다.
- [ ] 별도 develop worktree에서 Java 파일, SQL 사용처, 엔티티, 테스트, DB 매핑 목록을 다시 생성한다. 현재 분석은 176개 프로덕션 Java 및 33개 DB 접근 패턴 일치 파일 기준이며 최신 develop에서 달라질 수 있다.
- [ ] Java 21, Docker/Testcontainers, Flutter, MuMu 및 ADB 연결을 확인한다.
- [ ] backend에서 .\gradlew.bat test --no-daemon을 실행해 기준선을 기록한다. 기존 실패는 전환 실패와 구분하고 해결 전 첫 전환을 시작하지 않는다.
- [ ] 기존 앱으로 로그인·반려동물 선택·주요 화면을 확인한다. MuMu 기기 ID, 앱 버전, API URL, 백엔드 SHA를 기록한다.
- [ ] 최신 develop의 실제 메서드/스키마/테스트를 읽고 첫 도메인 상세 체크리스트를 작성한다. 이후 도메인도 착수 시 같은 방식으로 상세화한다. 이 문서는 순차 실행 마스터 계획이다.

## 모든 PR에 적용하는 반복 사이클

1. 최신 develop에서 refactor/jpa-<domain>-<scope> 브랜치/worktree를 만든다.
2. 해당 도메인의 기존 파일 → 목표 파일, 공개 메서드 계약, 테이블/인덱스/락, 호출하는 다른 도메인 목록을 PR별 문서에 고정한다.
3. 관련 기존 테스트를 실행한다. 부족한 권한·경계·동시성 시나리오는 의미 있는 회귀 테스트로 보강한다.
4. 패키지 이동, Service 인터페이스/구현 분리, JPA 매핑, 업무 규칙 이동, SQL Repository 격리를 수행한다. 다른 도메인은 필요한 import/호출부 수정만 포함한다.
5. 관련 테스트 → 전체 backend test 순으로 검증한다. 엔티티 매핑, 직렬화, N+1, 기존 인덱스 사용과 쿼리 증가를 대표 화면에서 점검한다.
6. MuMu에서 브랜치 백엔드에 연결하여 해당 기능의 주요 경로를 사전 확인한다.
7. refactor : <변경 내용> 형식으로 커밋/push 후 base=develop인 PR을 생성하고 채팅에 연결한다. 변경 범위, 남긴 SQL의 이유, 테스트 결과, MuMu 증적을 작성한다.
8. 현재 PR head SHA 기준 코드 리뷰 및 모든 필수 CI(Backend tests, Flutter analyze and tests, Monitoring 포함)를 확인한다. 지적 수정 후 영향 있는 검증을 재실행한다. develop 변경으로 병합 결과가 바뀌면 갱신된 코드도 재검증한다.
9. 미해결 결함 없이 저장소 정책대로 머지한다. 권한/필수 승인 부족은 우회하지 않고 필요한 조치를 구체적으로 보고한다.
10. 머지 이후 origin/develop의 실제 SHA를 가져와 해당 버전으로 백엔드를 빌드·기동한다. 이 SHA와 실행 프로세스/포트를 연결해 기록하고 필요한 CI를 확인한다.
11. MuMu를 머지된 백엔드에 연결해 도메인 전체 시나리오 및 로그인/반려동물 선택 공통 smoke를 실행한다. 화면뿐 아니라 재조회·앱 재실행 후 저장 결과와 서버 오류 로그를 확인한다.
12. 증적 및 상태를 갱신하고 성공한 경우에만 다음 도메인으로 진행한다.

머지 후 실패: 다음 작업 중단 → 재현 및 영향 확인 → develop 기준 수정 PR → 동일 검사/머지/재검증. 심각한 회귀는 기존 PR revert PR로 복구한다. 공유 develop을 reset/force-push하지 않는다. 스키마가 변경됐다면 코드 revert만으로 복구 가능한지 별도 판단한다.

## 순차 도메인 작업 목록

각 행은 최소 한 개 PR이며, 필요시 같은 도메인의 독립적인 하위 기능 단위로 분할한다. 모든 행에 위 반복 사이클이 필수다.

| 순서 | 범위 및 기존 소스 패키지 | 구현 초점 | 자동 검증 및 MuMu 완료 기준 |
|---|---|---|---|
| 1 | wallet | WalletExpense 엔티티, JPA CRUD, 통계/커서 조회 전용 Repository. 최초 표준 구현 | WalletExpenseIntegrationTest; 등록/수정/삭제, 분류·기간 필터, 통계, NULL 시간, 페이지 경계, 타인 펫 거부 |
| 2 | pet | 기존 Pet JPA 유지·정리, 소유권 접근 계약, 대표 사진 조회 분리 | PetIntegrationTest/PetWeightDeserializerTest; 등록/수정/삭제, 사진, 생일 미상, 체중, wallet 연계 |
| 3 | routine | Routine/Completion/CareSchedule 모델, 반복 규칙, 완료 처리·알림 연계 | RoutineIntegrationTest/CareScheduleIntegrationTest; 반복 유형별 오늘 목록, 완료/취소/건너뜀, 일정 변경/삭제, 날짜 경계 |
| 4 | record | ActivityRecord 및 기존 유형별 세부 테이블 매핑, 첨부/루틴 연결 유지 | ActivityRecordIntegrationTest; 기존 지원 종류 전부 등록/수정/삭제, 사진, 루틴 연결·삭제 후 상태 |
| 5 | community | 게시글/댓글/좋아요/투표 서비스 분리, 피드 projection, 차단 노출 규칙 | CommunityIntegrationTest/CommunityNewsPermissionIntegrationTest/MyActivityControllerTest 및 사진 제한 테스트; 작성·편집·삭제, 대댓글, 좋아요/투표, 차단, 내 활동, 페이지 이동 |
| 6 | media | 메타데이터 JPA, 원자적 용량 예약 유지, 파일 저장/정리/롤백 분리 | MediaIntegrationTest/MediaRollbackCleanupIntegrationTest/MediaStorageFailureIntegrationTest 및 storage 테스트; 프로필·펫·기록·게시글 업로드/교체/삭제, 실패 시 파일·용량 복원 |
| 7 | policy | 약관/동의 저장 및 publication 조회 분리, 버전·발효 시각 보존 | PolicyConsentIntegrationTest/PolicyPublicationIntegrationTest/PublicPolicyIntegrationTest/KakaoConsentIntegrationTest; 약관 확인/동의/재동의·제한 동작 |
| 8 | notification | 알림·기기 토큰 JPA, 조회/설정/발송/예약 분리, afterCommit 보존 | NotificationIntegrationTest/NotificationSettingsRaceIntegrationTest/ReminderTokenRaceIntegrationTest/ReminderCommitTest/PushPrivacyTest; 목록/읽음/전체읽음/설정, 예약 알림, 중복 방지 |
| 9 | support | 문의 JPA, outbox lease 및 재시도 SQL Repository 격리 | SupportIntegrationTest/SupportMailTransportTest; 문의·신고, 중복 제출, 발송 성공/실패/재시도 |
| 10 | user | User 이동, 프로필·차단·탈퇴·웹훅 및 cleanup 조율; auth 참조 import 갱신 | UserProfileIntegrationTest/UserBlockingIntegrationTest/KakaoCleanupConcurrencyTest/DeletionDataIntegrationTest/AccountDeletionIntegrationTest; 프로필/차단/해제/탈퇴, 타 사용자 데이터 보존, 재시도 |
| 11 | auth 및 auth/recovery | 기존 JPA 정리, refresh/session/OAuth/recovery 잠금·원자성 유지 | AuthIntegrationTest/RecoveryFlowIntegrationTest/RecoverySmallPoolIntegrationTest/PasswordRecoveryIntegrationTest/JwtIdentityTest; 가입/로그인/갱신/로그아웃, 복구, 카카오 로그인·가입·탈퇴 연계 |
| 12 | common/config/monitoring 잔여 | global 배치, 공통 DB 접근 Repository 격리, 오래된 패키지 및 스캔 설정 정리 | 전체 backend·frontend·monitoring CI; 전체 앱 회귀 및 API/OpenAPI/시간/보안 설정 테스트 |

주요 기존 소스 루트: backend/src/main/java/com/formypet/<위 표의 패키지>.
주요 기존 테스트 루트: backend/src/test/java/com/formypet/<기존 패키지>. 이동 후 실제 패키지에 맞춰 테스트 필터도 변경한다.
외부 서비스가 필요한 카카오·푸시·메일은 통합 테스트 결과와 실제 단말/서비스 결과를 구분한다. MuMu에서 실제 푸시 수신 불가 등은 가능한 테스트 단말로 대체 검증하고 사유를 기록한다. 대체도 불가하면 그 항목은 미완료다.

## MuMu 검증 절차

- ADB로 실제 MuMu 기기 ID를 탐지하고 명시적으로 지정한다. 10.0.2.2가 MuMu에서도 통한다고 가정하지 않는다.
- 앱은 frontend/lib/main.dart의 API_BASE_URL dart-define을 지원한다. adb reverse 또는 확인된 호스트 주소로 테스트 백엔드에 연결한다.
- 실행 예시 템플릿: flutter run -d <기기ID> --dart-define=API_BASE_URL=<확인된 테스트 URL>. 실제 값은 실행 시 기록한다.
- 테스트 전 서버 로그와 앱 요청으로 올바른 백엔드 접속을 확인한다. 환경별 포트/프로파일은 실제 설정을 읽어 결정한다.
- 각 도메인에서 정상 흐름, 빈 목록, 잘못된 입력, 권한 거부, 편집·삭제 후 재조회, 앱 재실행을 확인한다.
- 화면 스크린샷/필요시 영상, 실제/기대 결과, 서버 오류 유무를 남긴다. 화면 없는 동시성·작업 큐 동작은 API/DB 통합 테스트로 검증한다.
- 현재 도구로 MuMu 조작이 가능한지 실행 전 확인한다. 불가 시 사용자 수동 확인 항목을 제시하고 응답을 기다린다. 수행하지 않은 UI 검증을 완료로 기록하지 않는다.

## 증적 및 진행 상태

PR별 docs/refactoring/jpa/<순번>-<domain>.md에 다음을 기록한다.
- 상태: 예정 / 구현 / PR검사 / 머지 / 머지후검증 / 완료 / 실패
- 기준 develop SHA, 브랜치, PR URL, 검사한 head SHA, 머지 후 검증 SHA
- 기존→목표 파일 매핑, 영향 API, 테스트 명령·결과, 리뷰 해결 내역
- 남긴 SQL과 사유, JPA flush/clear/락 관련 결정
- MuMu 기기·앱·API 대상, 시나리오별 결과 및 증적 위치
- 실패·수정·재검증 기록과 다음 범위

## 최종 완료 조건

- [ ] 모든 도메인 및 잔여 공통 코드가 목표 패키지에 정리됨.
- [ ] 기본 CRUD가 JPA 중심이며, Service/Controller의 직접 SQL/DB row 매핑이 제거됨.
- [ ] 남은 JDBC/네이티브 SQL은 Repository에 있고 유지 이유와 테스트가 있음.
- [ ] 엔티티/값 객체에 업무 규칙을 배치하고 API DTO 의존을 제거함.
- [ ] API·데이터·권한·시간·페이징·트랜잭션 호환성 검증 완료.
- [ ] 모든 전환 브랜치가 refactor/ 형식이고 직접 작성한 커밋 제목이 refactor : 형식을 따름.
- [ ] 모든 전환 PR이 develop에 머지되고 각 PR의 머지 후 검증 증적이 있음.
- [ ] 최종 develop SHA의 전체 CI 통과 및 MuMu 전체 기능 회귀 완료.
- [ ] 열린 필수 결함/미검증 항목이 없고 최종 요약에 예외 SQL, PR 목록, 테스트 및 UI 증적이 연결됨.

## 목표 실행용 지시문

이 계획을 실행 목표로 삼아 전체 Java 코드를 domain/<기능> 패키지 및 JPA 중심 구조로 점진적으로 전환해줘. 최신 develop에서 refactor/<작업명> 형식으로 도메인별 브랜치를 만들고, 모든 직접 작성하는 커밋 제목은 refactor : <변경 내용> 형식으로 작성해줘. 이어서 구현·테스트·리뷰·develop PR 생성·검사·머지·머지된 버전의 MuMu 기능 확인까지 완료한 뒤 다음 도메인으로 넘어가줘. PR 생성/push/머지를 이 목표 범위에서 허용하되 저장소 승인·보호 규칙은 준수해줘. 기존 작업은 보존하고 전용 테스트 환경을 사용해줘. 실패 시 다음 단계로 넘어가지 말고 수정 PR 또는 revert PR로 복구한 뒤 재검증해줘. 증적과 진행 상태를 계속 기록하고, 전체 완료 조건이 충족됐을 때만 목표 완료로 처리해줘.

