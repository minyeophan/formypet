# 11. 인증 및 계정 복구 도메인 전환

## 기준 및 범위
- base develop f4039a37f43035bda46f7b765385c39f66059692: 회원 PR108 및 머지 후 모든 검증 완료.
- branch refactor/jpa-auth; 선행51cdf7b는 회원 완료 증적만 포함.
- com.formypet.auth 전체를 domain.auth로 이동한다. User는 domain.user에 유지한다.
- API/JSON/권한/JWT/비밀번호 정책/DB/Flyway 이력과 인증 실패 의미를 유지한다.

## 반드시 보존할 계약
- register: 정책 검증→이메일 중복 확인→User JPA 저장→동의 기록→세션 version current-read→토큰 발급.
- login: 현재 ACTIVE 사용자 row lock 후 LOCAL 및 password 검증. 이메일 대소문자/공백 처리 기존 의미 유지. 로그인 admission은 HTTP 경계에서 업무 트랜잭션 전에 수행.
- Kakao: 외부 fetchUser는 트랜잭션 밖. lifecycle bucket lock→cleanup 부재 current-read→OAuth 조회/가입 동의→사용자 lock→토큰 발급. OAuthSignupService MANDATORY 및 이메일 자동 연결 금지 유지.
- refresh: 소유자 preliminary read→사용자 row lock→refresh 존재 FOR UPDATE 재검증→JPA 조회/expiry→delete/flush→새 토큰. 이전 REPEATABLE READ snapshot에서 삭제된 토큰을 되살리지 않는다.
- SessionGuard는 엔티티 캐시가 아닌 최신 인증 snapshot을 읽는다. ACTIVE만 허용하고 lockCurrent는 SecurityContext principal의 id/version을 대조한다.
- OAuthLifecycleGuard는 MANDATORY, floorMod(providerId.hashCode(),64) bucket. user/oauth/job locks보다 먼저 획득. cleanup job 또는 webhook event가 존재하면 KAKAO_CLEANUP_PENDING.
- SignupIntent begin/validate/complete MANDATORY. TTL60..3600, UUID 두 개 연결 토큰, 저장은 SHA256, DB UTC 만료. cancel: preliminary provider lookup→lifecycle→토큰 current lock→기존 OAuth current read→없는 경우만 unlink enqueue→intent 삭제. expire 최대50개, 동일 취소 처리.
- JWT uid와 subject 일치/정수 양수, av 정수 비음수, 만료/서명 처리 및 공개 경로 필터 skip 유지.
- RecoveryService NEVER: IP/subject admission을 업무 트랜잭션 밖에서 마친다. limiter REQUIRES_NEW 단일 연결, 원자 insert+lock+update. pool size1 회귀 유지.
- Recovery request: 기존 사용자 lock; LOCAL만 recipient/userId, unknown/OAuth는 같은 envelope의 검증 불가 challenge. 동일 subject PENDING만 invalidate, VERIFIED capability 유지. Clock UTC microseconds, code600초/resend60초.
- verify: preliminary owner lookup→user lock→challenge current lock. 실패 attempts 최대5를 noRollbackFor=ApiException으로 커밋. 같은 requestId/code로 VERIFIED 재시도 시 같은 reset token, expiry300초. 타 requestId 거부.
- confirm: 같은 user→challenge 잠금 순서. 재시도는 requestId/password fingerprint 동일하고 completed+600초 이내만 허용. password/auth_version+1/refresh 삭제/device 비활성/다른 challenge invalidate/현재 COMPLETED가 하나의 트랜잭션.
- Mail: transaction afterCommit만 bounded single-worker queue에 제출. rollback 때 발송 없음. code는 전송 직전 PENDING+unexpired 재확인. 실패/overflow는 class명/요청ID만 로그. SMTP TLS/주소 검증/타임아웃 및 secret redaction 유지.
- Cleanup: challenge expiry/reset expiry 경과 및 completed10분 보존; limit last_request2시간 이후 삭제. strict comparison 유지.

## 구조와 저장 방식
- domain.auth/{controller,entity,dto/request,dto/response,repository,service,service/impl,security,client,config,scheduling,validation}.
- RefreshToken/OAuthAccount JPA 및 EntityGraph를 보존. 기본 저장/조회는 JPA 중심으로 유지한다.
- 서비스와 보안 guard에서 SQL/row mapping을 제거하고 전용 repository로 옮긴다. Session snapshot/current lock, lifecycle/queue, 여러 테이블의 원자 변경은 명시적 저장소 명령으로 보존한다.
- Recovery challenge의 생성/상태 타입/시간 정책과 저장 책임을 분리한다. JPA 도입 시 관리 엔티티의 stale 상태가 current-read를 대체하지 않도록 JDBC/native bulk와의 동기화 검증을 선행한다. 복잡한 상태 전이 명령은 repository에 유지 가능하며 근거를 기록한다.
- DTO를 controller nested record에서 분리하여 서비스가 controller 타입에 의존하지 않게 한다. row map과 JDBC 시간 변환은 repository 밖으로 나오지 않는다.
- 스케줄러는 scheduling에서 유스케이스를 호출한다. 보안 필터/principal/crypto는 security, 외부 Kakao/메일은 client, 설정은 config에 배치한다.

## 진행 및 검증
1. [x] auth.* 기준선7613 terminal/XML 확인.
2. [x] Session/current refresh 저장소 계약 테스트 RED→GREEN 후 연결. 동시 reset/refresh와 stale principal 회귀 포함(106 tests 성공). lifecycle은 3번과 함께 검증.
3. [x] Signup intent 저장소 및 토큰/만료/취소/기존 계정 보존 테스트 RED→GREEN(112 tests 포함 성공).
4. [x] Recovery 상태/typed 저장소/limiter/cleanup/mail 분리. UTC, 잘못된 시도 커밋, 같은 요청 재시도, rollback 메일 미전송, 단일 pool, 경쟁 confirm 회귀(116 tests 성공).
5. [x] 전체 auth 패키지/서비스 인터페이스/DTO/설정/클라이언트/스케줄러 이동 및 외부 참조/시간 모델 reflection 갱신(120 tests 성공).
6. [x] 전체 backend Asia/Seoul 512 tests, 독립 최종 리뷰(수정 사항 없음), MuMu 기존 세션/전체/재실행 통과. 가입/로그인/로그아웃/갱신/복구 비활성 UI 계약 검증. 활성 복구·외부 카카오·SMTP는 mock 계약으로 검증.
7. [x] refactor : 인증 및 계정 복구 도메인 JPA 접근 정리 commit/push/develop PR. exact head 모든 CI 성공 후 squash.
8. [x] 실제 merge SHA 강제 빌드, MuMu 기존/전체/재실행/공통과 develop CI/로그 성공 후 global 단계로 진행.

## 리뷰 중점
트랜잭션 전파/락 순서, JPA persistence-context와 current-read 충돌, 토큰 회전 단일 사용, 복구 실패 횟수 커밋, unknown/OAuth 비노출, 제한기 연결 점유, afterCommit/메일 유효성 확인, state machine 재시도 경계, schema/UTC/annotation 및 scheduler 중복 여부.


## 복구 저장 방식 상세 결정
- Ruling: 복구 challenge는 단일 JPA 엔티티로 매핑하고 생성 및 attempts/VERIFIED/COMPLETED 전이를 JPA로 처리한다. 세션/복구 테이블 간 일괄 변경은 전용 명령 저장소로 유지한다.
- current read는 사용자 잠금 이후 native FOR UPDATE 조회 및 EntityManager.refresh(PESSIMISTIC_WRITE)로 관리 엔티티를 갱신한다. 이전 persistence-context/snapshot을 재사용하지 않음을 회귀 테스트로 증명한다. 추가 조회 비용은 인증 correctness를 위해 허용한다.
- confirm의 일괄 invalidate 이후 현재 challenge를 refresh한 다음 COMPLETED로 전이하여 JDBC bulk와 dirty checking의 충돌을 피한다. request의 bulk invalidation 후 다음 검증에서도 current refresh를 적용한다.
- 날짜는 DATETIME(6) direct LocalDateTime JDBC 매핑 및 UTC 변환을 사용하고 microsecond 정밀도를 유지한다. 스키마 변경 없이 기존 DB 값 왕복을 검증한다.
- Session/Signup 저장소 분리 검증 후 위 설계의 RED 테스트를 먼저 추가하며, 기존 동시 복구/시도 횟수/멱등/메일 tests로 검증한다.

## MuMu 인증 검증 범위
- 기존 세션 fixture를 먼저 읽어 프로필/보호 API 및 refresh 단일 사용을 확인한다.
- synthetic 신규 계정 가입→로그아웃→잘못된 비밀번호 거부→정상 로그인→토큰 갱신→앱 재실행 후 인증 유지 순서로 검증한다.
- 기존 QA에서는 복구 비활성(503) UI 응답을 실제 API로 검증한다. 활성 복구의 메일/검증/확정·동시성은 backend mock SMTP 통합 tests로 증명하며 외부 실제 메일/카카오 호출 성공으로 보고하지 않는다.
- merged SHA에서 기존/전체/재실행/공통 검증을 다시 실행한다.



## 완료 증적
- PR #109: https://github.com/minyeophan/formypet/pull/109
- 실제 merge: 6b83f4af9f2257cbf8ffd06a6ab91637835cb245; forced bootJar23885 34s/4 tasks 성공.
- exact head push38842587605 및 PR38842768642 각 3개 검사 성공; develop38843245621도 3개 성공.
- 실제 merge QA70632/18083: MuMu 기존97028(10s), 전체4908(18s), 재실행49772(3s), 공통82972(51s) 모두 성공. 서버 ERROR/Exception 없음.
- 인증 단계 완료. 실제 외부 Kakao/SMTP 전송은 성공으로 주장하지 않으며 위 mock 계약 범위를 유지한다.
