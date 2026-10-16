# 10. 회원 도메인 JPA 전환

## 기준 및 범위
- base develop c366cfbe4cba5d38b0898263211e1faaa5ea2c09 (문의 PR107 모든 머지 후 검증 완료).
- branch refactor/jpa-user; 선행5873e0c는 문의 완료 증적.
- 기존 com.formypet.user 전체와 auth.domain.User/auth.repository.UserRepository를 domain.user로 정리한다. 인증 SessionGuard/OAuthLifecycleGuard/recovery는 다음 도메인이므로 필요한 import만 변경한다.
- API/스키마/보안 및 데이터 삭제 범위를 유지한다. 이 단계에서 새로운 삭제 정책이나 외부 발송 정책을 추가하지 않는다.

## 보존 계약
- User의 DynamicUpdate 및 auth_version updatable=false 유지. 프로필 변경이 JDBC 인증 버전/미디어 사용량을 덮어쓰지 않음. created/updated 시간 기존 의미와 정밀도를 회귀 검증한다.
- 프로필: sessions.lockCurrent→findUser→nickname trim 또는 미디어 upload→JPA flush→이전 이미지 정리 순서.
- 차단: 본인400 SELF_USER_BLOCK, 대상없음404 USER_NOT_FOUND, 중복 차단 멱등 및 created_at 유지, 해제 멱등. 목록 created_at DESC/blocked_user_id DESC 및 현재 nickname. 기존 커뮤니티 양방향 노출 제한 유지.
- 탈퇴 LOCAL은 비밀번호만, KAKAO는 토큰만 허용; provider identity 외부 조회는 트랜잭션 밖. OAuthLifecycle lock→사용자 current lock→provider account FOR UPDATE 순서.
- 탈퇴 트랜잭션: 영향받는 다른 작성자 게시글/투표옵션 수집→미디어 cleanup 큐→필요 시 provider unlink job→문의/outbox 삭제→복구 제한 삭제→다른 작성자 답글 parent 분리→사용자 pending+authversion 증가→물리삭제→카운터 재계산. 모든 DB 작업 원자적 rollback.
- provider webhook 삭제는 MANDATORY; lifecycle lock 및 event current-read 후 삭제하고 event 제거. 이미 외부 unlink된 webhook은 provider API를 다시 호출하지 않음.
- 외부 unlink worker: AtomicBoolean + 동일 DB 연결 GET_LOCK을 provider I/O까지 유지. row lease만으로 대체하지 않음. RELEASE_LOCK 실패 시 connection.abort. 같은 SingleConnectionDataSource에서 claim/success/retry 수행.
- unlink job: due<=UTC_TIMESTAMP, locked_until<UTC_TIMESTAMP, next_attempt_at/id 정렬, lease5분. 성공delete, 실패 attempts+1, 30초 지수 backoff 기존 식 유지(shift 상한11로 실제 최대61440초), 클래스명만 last_error.
- webhook worker: 짧은 TransactionTemplate claim FOR UPDATE SKIP LOCKED; processor 별도 트랜잭션; 재시도 attempts최대30, 동일 backoff, 클래스명 로그.
- webhook auth constant-time admin key 비교, 정확한 appId, 숫자 provider ID, 허용 referrer 유지. 외부 HTTP timeout3/5초 및 응답 identity 검증 유지.
- 공개 탈퇴요청: enabled 확인→연락 이메일 정규화 rate limit→기존메일 전송→receipt. SMTP/카카오 실발송은 테스트 mock으로 검증.

## 목표 구조와 저장소 선택
- domain.user.entity.User 및 repository.UserRepository로 한 번만 이동.
- UserBlock 복합키 엔티티/Repository와 typed 목록 projection. 중복 insert의 timestamp/경합 보존은 명시적 repository 원자 명령으로 유지, 해제는 JPA bulk 계약 검증.
- controller, dto.request/response, service 인터페이스/impl, client, scheduling, security 책임별 배치.
- AccountDeletionCommands는 cross-domain bulk cleanup/current-read 전용 JDBC repository. 유스케이스가 순서를 조율하며 SQL/행 매핑은 service에서 제거.
- provider job repository는 동일 연결 advisory lock과 큐 SQL을 소유하고 typed job/session callback 제공; 외부 client 호출/재시도 정책은 서비스에 둔다.
- webhook queue repository는 멱등 삽입/claim/current-read/원자 삭제를 소유한다. DB시간 및 기존 unique/index 유지.
- retry 정책과 모니터링 결과는 순수 타입으로 분리. 불필요한 연관 엔티티 로딩을 추가하지 않는다.

## 순서 및 검증
1. [x] user.* 기준선17795 terminal/XML 및 auth.AccountDeletionIntegrationTest 추가 기준선.
2. [x] 차단 엔티티/복합키/조회/삭제와 retry 정책 RED→GREEN. UTC/legacy/중복시각/순서/쿼리 수 검증.
3. [x] 탈퇴/worker 저장소 추출, 기존 락/외부호출/rollback/카운터 계약 보존. 신규 회귀 테스트 먼저 작성.
4. [x] User 및 전체 user 패키지 이동, DTO/서비스 인터페이스 분리, 외부 참조 수정. 기존 테스트 assertion 보존.
5. [x] 관련 suite와 전체 backend Asia/Seoul, 독립 최종 리뷰, Dart분석.
6. [x] MuMu 프로필/이미지/차단·해제/재실행/로컬 탈퇴·토큰 무효화. 외부 Kakao·메일은 mock 계약으로 검증.
7. [x] refactor : 회원 도메인 구조 및 계정 처리 정리 commit/push/develop PR, 모든head CI후 squash.
8. [x] 실제 mergeSHA 빌드 및 MuMu 기존/전체/재실행/공통, develop CI/log 검증 후 auth 진행.

## Review focus
JPA persistence-context와 JDBC bulk 삭제의 상호작용, auth_version/media counters의 stale overwrite, OAuth lock 순서, 동일연결 advisory lock 해제, provider I/O와 DB트랜잭션 경계, cross-domain cascade/카운터/cleanup 원자성, 차단 멱등과 정렬, 공개 요청 rate-limit/메일 보안.



## 진행 증적
- 패키지 이동 전 40개, 이동 후 시간 저장 검증 포함 44개 테스트 성공(86616, 1분54초).
- 프로필 stale entity flush의 인증 버전/미디어 카운터 보존 테스트 추가. 전체 backend92691 실행 중.
- 독립 리뷰 user_review: actionable finding 없음. 외부 provider 실호출/connection.abort 실패 경로는 별도 실환경 검증하지 않음.
- MuMu 신규 테스트 Dart 분석84791 통과. 기존 support 병합 서버에서 시나리오 기준선44707 실행 중; 사용자 빌드 검증은 아직 미수행.

- 전체 backend92691: 499/0/0/0 성공(9분29초). 독립리뷰 완료.
- MuMu 기준선 전체47457(23초), 재실행27076(8초) 성공. 초기 탈퇴 준비계정의 온보딩 누락은 테스트 fixture 보완으로 해결.
- 사용자 bootJar10577 성공(59초), QA3017 정상 기동. 기존 fixture8915 검증 실행 중; 아직 사용자 빌드 MuMu 통과로 집계하지 않음.

- 사용자 빌드 기존 데이터8915(6초), 전체32021(23초) MuMu 성공. 새 fixture 재실행61951 진행 중.

- 사용자 새 fixture 재실행61951 성공(7초). 서버 ERROR/Exception 없음. PR 전 검증 완료.

- PR108: head9e65815, CI6개 성공 후 f4039a3으로 squash merge. 실제 merge 강제 bootJar72354 성공(1분31초), QA21262 정상.
- 머지 후 기존 데이터6487 검증 성공(10초). 전체35159 진행 중, 재실행·공통·develop CI 확인은 남음.

- 완료: 머지 후 재실행89883(5초), 공통13316(51초) 성공. develop CI38836638760 3개 모두 성공. 서버 ERROR/Exception 없음. 회원 도메인 10/12 완료.
