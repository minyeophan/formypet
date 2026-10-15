# 09. 문의 JPA 전환

## 기준과 범위
- develop: 1b57d77f0486ec0a13666519815efbbdfb9677c6 (알림 PR106 머지 후 모든 검증 완료).
- branch: refactor/jpa-support. 선행 ffee658은 알림 완료 증적뿐이다.
- 기존 SupportService/SupportMailWorker의 직접 SQL/Map 행 접근을 repository로 격리하고 문의 및 outbox 생성을 JPA로 전환한다.
- 테스트 인프라 com.formypet.support.IntegrationTestSupport/SharedMySqlContainer 등은 문의 도메인 코드가 아니므로 그대로 둔다.

## 보존 계약
- V28/V33 스키마, requester SET NULL/target_author CASCADE/outbox CASCADE와 unique 요청·신고·ticket 관계 유지.
- 사용자 FOR UPDATE 후 기존 요청 조회; 동일 payload는 같은 id/receivedAt, 다르면 REQUEST_CONFLICT. request_id ascii_bin 대소문자 구분.
- inquiry type/title/body/reply와 report postId/reason/detail의 기존 JSON SHA256 입력 순서 및 trim 의미 유지. OTHER 빈 detail 오류 우선순위 유지.
- 신고 재요청은 게시글 삭제 후에도 재접수 번호 반환. 다른 requestId 중복 신고는 POST_ALREADY_REPORTED, 없는 글404/본인 글403.
- ticket+outbox 원자 생성; outbox 실패 시 ticket rollback. 접수 시 외부 발송 없음.
- UTC Instant API/DB DATETIME6 직접 LocalDateTime 매핑, micros 응답과 재조회 일치.
- mail claim은 짧은 TransactionTemplate 트랜잭션: 최대5회, 만료된 최종 lease FAILED, id ASC FOR UPDATE SKIP LOCKED, lease300초, 새 UUID token.
- 발송은 claim commit 이후; SENT/실패 갱신은 PROCESSING+claim_token 일치 조건. 이전 작업자가 새 claim을 덮어쓰지 않음.
- 재시도1/5/30/120분, 마지막 실패 FAILED, 예외 클래스만 last_error/log 기록. SMTP 상세/주소/비밀번호 로그 노출 금지.
- 메일 제목/한국시각/분류 문구/내용/신고 snapshot 키(user_id,title,content,nickname)/replyTo 그대로.
- SMTP transport STARTTLS 필수/서버신원 확인/10초 timeout/헤더 검증, scheduler enabled 및20회 batch 유지.

## 목표 구조
- domain.support.controller.SupportController
- dto.request.InquiryRequest/ReportRequest, dto.response.SupportReceipt
- entity.SupportTicket/SupportMailOutbox, 순수 MailRetryPolicy
- repository.SupportTicketRepository/SupportMailOutboxRepository (JpaRepository)
- repository.query typed post snapshot, repository.jdbc 사용자 잠금/outbox claim/fencing 명령
- service.SupportService/SupportMailWorker 인터페이스와 impl
- client.SupportMailTransport, config.SupportMailProperties, scheduling.SupportMailScheduler
- HTTP DTO 의존 없는 엔티티와 typed snapshot. 잔여 JDBC는 사용자 current-read/게시글 snapshot 및 worker 원자 명령에 한정.

## 실행 및 검증
1. [x] 기준선67829 terminal/XML 확인 (기존 SupportIntegrationTest/SupportMailTransportTest).
2. [x] entity/재시도 규칙 RED→GREEN, legacy nullable/시간정밀도/unique 회귀.
3. [x] JPA 문의+outbox 저장, typed 조회와 atomic 명령 추출; 기존 동시성/rollback/lease 테스트 보존.
4. [x] 패키지/DTO/인터페이스 이동, 외부 계정삭제 호출 import 변경. 서비스 SQL/Map 행매핑 제거.
5. [x] 추가 시간/snapshot/fencing/query-cost/commit 검증, 관련 및 전체 테스트, 독립 최종 리뷰.
6. [x] MuMu 문의/신고/중복 제출/검증 오류/재실행. 실제 외부 SMTP는 QA 자격증명 없이 전송하지 않으며 transport mock 및 DBworker 계약 검증과 구분한다.
7. [ ] refactor : 문의 도메인 JPA 전환 및 메일 처리 분리 커밋/push/develop PR, 최신 head CI 후 squash.
8. [ ] 실제 merge SHA 재빌드/MuMu 기존+전체+공통/develop CI/log 확인 후 user 진행.

- 기준선67829:19/0/0/0,1분34초. 순수 엔티티/재시도 RED77961은 신규 타입3개 부재9오류로 실패. 구현 후99299:22/0/0/0,1분43초. 추가 DB 매핑2개 포함38050 실행 중.

## 구현 검증 증적
- 패키지 전환 및 계정삭제 호출부 테스트14121: 30 tests / 0 failures / 0 errors / 0 skipped, 1분51초.
- 신규 회귀: UTC/microseconds/nullable legacy, 요청 대소문자, 실패 fencing, 정확한 payload hash/snapshot, 2-query 및 연관 엔티티 추가 조회 없음.
- 독립 최종 backend 리뷰 support_review: no actionable findings.
- bootJar92356: 성공23초. Dart support_migration_test 분석: No issues found.
- 전체 backend31069 및 MuMu47927 진행 중. QA93315는 현재 support 빌드,18083,격리DB3318, SMTP/scheduler 비활성.

- 전체 backend31069: BUILD SUCCESSFUL8분, 100 suites / 489 tests / 0 failures / 0 errors / 0 skipped (최종 XML).
- MuMu 문의 validation/연결실패/동일requestId 재시도/접수시각은1201에서 통과. 신고 화면 및 전체 성공은 재실행88718 결과 대기.
- 테스트 보조 코드 수정: multipart 게시글 fixture, 실기기 SystemChannels 키보드 닫기, 지연 생성 ListView scroll 및 사유 미선택 버튼 비활성 검증. 프로덕션 동작 변경 없음.

- MuMu88718 전체 시나리오: SUPPORT_FULL_VERIFIED / All tests passed, 23초. 앱 재실행9194 진행 중.

- 앱 새 프로세스9194: SUPPORT_RESTART_VERIFIED / All tests passed, 4초. 기존 문의/삭제된 대상 신고의 동일 접수번호와 receivedAt 유지 확인. 브랜치 로컬 검증 완료.
