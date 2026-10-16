# 07. 약관·동의 JPA 전환

## 상태와 기준

- 상태: 완료. PR #105 머지 (`7936cb8`), backend 468개, CI 및 실제 머지 버전 MuMu 검증 통과.
- 기준 develop: `9ef997043e767bc165192710d66f4b5e536a4726` (미디어 PR104 머지 후 모든 검사 완료)
- 브랜치: `refactor/jpa-policy`
- 선행 커밋 `0d3107f`: 미디어 완료 증적만 포함.
- 기준선: `gradlew.bat test --tests 'com.formypet.auth.Policy*' --tests 'com.formypet.auth.PublicPolicyIntegrationTest' --tests 'com.formypet.auth.KakaoConsentIntegrationTest' -PtestTimezone=Asia/Seoul --no-daemon`, 세션54633 성공1분38초. XML11개/실패0/오류0/스킵0.
- 현재 QA 서버60471/PID5072는 약관 merge7936cb8. 격리 DB3318/API18083/MuMu127.0.0.1:16384/mediatest 앱 사용.

## 조사한 계약

- 기존 Java7개: PolicyAcceptance, PolicyCatalog, PolicyConsentController/Service, PolicyGate, PolicyPublicationRegistry, PublicPolicyController.
- V35: policy_consents IDENTITY, user FK CASCADE, 사용자/종류/버전/action unique, recorded_at DATETIME(6) DB 기본값.
- V37: policy_publications 종류/버전 복합 PK, 본문·hash·게시/발효 시각; policy_runtime singleton1의 영구 enforcement 플래그.
- 가입 기록은 MANDATORY 트랜잭션. 기존 가입 흐름의 사용자 저장과 함께 rollback되어야 한다.
- 재동의는 SessionGuard.lockCurrent가 먼저 실행된다. 다른 사용자/폐기된 세션의 동의를 허용하지 않는다.
- 중복 동의는 INSERT IGNORE이며 기존 hash/시각을 바꾸지 않는다. ACCEPTED+AGE14_CONFIRMED 두 action을 acceptance_revision 기준으로 확인한다. privacy 안내 확인은 선택이다.
- enforcement=false이고 acceptance=null이면 허용한다. acceptance가 있으면 버전/필수 체크를 검증한다. 오류 코드·상태·문구 보존.
- publication은 runtime 행 FOR UPDATE로 직렬화한다. 기존 복합키의 content hash가 다르면 전체 publish rollback. 구버전 배포/빈 목록이 기존 게시 이력이나 활성 상태를 지우면 안 된다.
- 게시/발효 판단은 JVM 시간이 아닌 DB UTC_TIMESTAMP(6). 미래 게시물은 비공개, 게시됐지만 미래 발효인 버전은 이력으로 열람 가능. 정렬 effective_at,published_at,document_version 유지.
- 활성화는 유효한 terms/privacy 두 종류가 모두 있어야 한다. activate=false는 이미 활성화된 상태를 끄지 않는다.
- 공개 JSON/HTML 경로, HTML escape, 미게시503/게시 준비 중 문구 및 archived404 유지.
- 동의 이력은 recorded_at,id 순서와 snake_case(document_type/document_version/action/recorded_at)를 유지한다. 기존 JDBC DATETIME은 LocalDateTime JSON(시간대 접미사 없음/마이크로초)이다. 실제 비교 테스트로 확인했으며 typed DTO도 동일한 타입을 사용한다.
- PolicyGate의 auth/public/정책/내 정보 조회·탈퇴/문의/알림 해제 예외를 그대로 유지한다.

## 목표 구조와 구현 순서

`com.formypet.domain.policy` 아래:

- controller: 공개 정책 및 내 동의 컨트롤러
- dto/request: PolicyAcceptance
- dto/response: 정책 목록/문서/동의 상태/이력 DTO (현재 중첩 타입의 API JSON 동일)
- entity: PolicyConsent, PolicyPublication 및 복합 ID, PolicyRuntime. UTC DATETIME 직접 매핑, 엔티티의 HTTP DTO 의존 없음.
- repository: JPA 조회·저장·상태 접근. 중복 방지/DB 시계/명시적 잠금에 native/JDBC가 필요하면 전용 하위 저장소에 한정하고 근거 기록.
- service 및 service/impl: 동의, 카탈로그, publication 인터페이스/구현체. 카탈로그 파일 읽기·검증과 게시 등록 책임을 구분한다.
- config: PolicyGate 및 실제 필요한 초기화 설정.

JPA 영속성 컨텍스트의 오래된 runtime/publication 값이 기존 current-read 잠금 의미를 바꾸지 않도록 검증한다. unique 위반을 catch하여 트랜잭션 rollback-only 상태에서 계속 진행하는 방식은 사용하지 않는다. 스키마/운영 catalog는 변경하지 않는다.

## 검증 체크리스트

- [x] 기존11개 기준선 결과 확인
- [x] 엔티티/복합키/UTC 매핑 RED → GREEN
- [x] 기존 JDBC 기록의 JSON 날짜/필드/정렬 호환성 회귀
- [x] 동의 중복·부분 동의·선택 privacy·가입 전체 rollback·다른 사용자 접근/세션 폐기
- [x] publication immutable hash/부분 batch rollback/동시 게시 및 activate=false 보존
- [x] 미래 게시/발효·마이크로초·동일 시각 버전 정렬·DB 시계
- [x] 서비스 SQL/Map 행 매핑 제거, 인터페이스/패키지/호출부 정리
- [x] 관련/전체 backend 테스트 및 대표 조회 비용, 독립 리뷰
- [x] MuMu 실제 격리 테스트용 정책: 열람·동의·이력·재동의 제한·앱 재실행
- [x] PR develop 최신 head CI 전체 통과 후 squash merge
- [x] 실제 merge SHA 재빌드, MuMu 기존/전체/공통 및 develop CI/로그 확인

실제 운영 약관 동의 대신 `TEST FIXTURE ONLY` 문서만 격리 QA에 사용한다. 정책 게시/개정 fixture는 테스트 DB에만 넣고 실제 배포 catalog는 유지한다. Kakao 외부 계정 연결은 기존 mock 통합 테스트 결과와 단말 정책 UI 검증을 구분한다.

## 구현 중 검증

- 저장소/엔티티 RED19405: 새 타입 부재만으로 컴파일 실패 확인. PolicyPublication 복합키/immutable hash, PolicyConsent DB 시각, PolicyRuntime 단방향 활성화 매핑 및 저장소 추가.
- PolicyHistoryContractIntegrationTest로 기존 JDBC 이력 JSON 필드/UTC Timestamp 표현/동일 시각 id 정렬을 고정했다. 서비스는 아직 JDBC이므로 이전 동작 기준으로 실행한다.
- GREEN35568 실행 중: 기존11 + 저장소3 + 이력1. 서비스 연결/패키지 이동은 아직 하지 않았다.

- GREEN35568 성공1분49초, XML15/0/0/0. 기존 JDBC 이력 계약 테스트도 통과. 이어 동의 저장/상태/이력 조회를 JPA 저장소에 연결하고 Timestamp 호환 typed DTO를 적용했다. 연결 검증95381 실행 중.
- 연결95381에서 이력 계약1개 실패: 기존 recorded_at은 2026-01-01T23:59:59.123456, Timestamp DTO는 2026-01-01T23:59:59.123+00:00. 실제 JDBC getObject 결과는 LocalDateTime이므로 DTO를 LocalDateTime으로 수정했다. 나머지14개 통과. 재검증85907 실행 중.
- 동의 연결 재검증85907 성공1분57초. JDBC JSON과 typed LocalDateTime 응답이 일치한다. publication DB시각 조회/현재읽기·runtime scalar 조회 테스트2개를 추가하고 RED12484 실행 중.
- publication/runtime RED12484는 신규 메서드 부재로만 실패. JPA 게시/발효 조회 및 현재읽기, runtime scalar/단방향 update, PolicyDatabaseAccess(DB clock·singleton 잠금) 구현. publication 저장은 runtime 잠금 → current-read 기존 hash 확인 → 신규 saveAndFlush로 변경. 서비스 SQL/Map 행 매핑 검색 결과 없음. GREEN72955 실행 중.
- publication 연결 GREEN72955 성공1분52초. XML17개/실패0/오류0/스킵0. 다음은 batch rollback/동시 게시 검증 및 패키지·서비스 인터페이스 분리다.
- 동시 게시/기존 snapshot/배치 rollback/불완전 활성화 회귀4개 추가 후67127 성공1분56초. 이어 domain.policy 이동, 서비스 인터페이스3개+impl, 응답 DTO, catalog loader를 분리했다. 호출부는 타입 경로만 갱신. 패키지 검증87301 실행 중.
- 패키지87301 성공1분58초. loader5/가입 MANDATORY 및 rollback1/조회비용1 추가 후48025 성공1분52초, XML28/0/0/0. 독립 소스 리뷰 지적 없음. 전체60418 실행 중. bootJar96195 성공27초, QA48081/PID31324/schema43에서 테스트 전용 v1 catalog+enforcement=true 기동. 신규 policy_migration_test.dart analyzer49372 통과.

## 실제 패키지/저장 결정

- controller: PolicyConsentController/PublicPolicyController, config: PolicyGate/PolicyCatalogLoader.
- service: PolicyCatalog/PolicyConsentService/PolicyPublicationRegistry 인터페이스와 각 service/impl 구현체.
- dto/request/PolicyAcceptance; dto/response/PolicyDocumentResponse, PolicyCatalogResponse, PolicyConsentStatusResponse, PolicyConsentHistoryResponse.
- entity/PolicyPublication(immutable)+PolicyPublicationId, PolicyConsent(immutable/DB timestamp), PolicyRuntime.
- repository/PolicyPublicationRepository, PolicyConsentRepository, PolicyRuntimeRepository; repository/jdbc/PolicyDatabaseAccess.
- native 유지: 동의 INSERT IGNORE(원자적 중복 억제), 게시 UTC_TIMESTAMP(6) 경계와 current FOR UPDATE 조회. DB 시계와 singleton 잠금만 JDBC. 기본 게시 신규 저장·동의 이력/집계·runtime 상태는 JPA.
- 서비스/컨트롤러 직접 SQL 및 이전 com.formypet.policy 참조 없음. 외부 auth/notification은 타입 경로만 변경.
- MuMu23225 signup 성공17초. v1 전용 문서 열람/필수 체크/가입/이력·중복·stale409 검증. v2 새 revision으로 QA25144/PID26760 재기동, reaccept57809 실행 중. 전체60418 아직 실행 중.

- MuMu reaccept57809 성공20초. 신규 r2에서 기존 기능403/정책화면 이동, 취소 후 제한 유지, 실제 전문 열람·체크 후 재동의, 기능 해제, v1/v2 각2개 이력 및 구버전 전문 보존 확인. 기존 계정 새 프로세스45755 실행 중. Analyzer64811 통과. QA25144 로그 추가 오류 없음.
- 전체60418 최종 성공7분42초. MuMu 기존 계정 새 프로세스45755 성공8초(POLICY_EXISTING_VERIFIED). v1/v2 전문·이력·동의 상태 유지. 마지막 소스 변경 이후 backend 회귀 완료, MuMu 테스트만 이력 복귀 탐색을 보강했고 analyzer64811/reaccept57809/existing45755로 검증했다.
- 전체 XML468 tests/0 failures/0 errors/0 skipped 확인. 로컬 검사·독립 리뷰·MuMu signup/reaccept/existing 완료. PR CI 및 실제 머지 SHA 검증은 아직 미완료.
- 구현1640298923da0571502835983479968addff1734 push 완료. develop PR105 생성·채팅 연결 완료: https://github.com/minyeophan/formypet/pull/105. 현재 CI 실행 중, 아직 머지하지 않았다.
- PR105 head1640298의 push38801663953/PR38801815887 CI6개 모두 성공. 리뷰/코멘트 없음. squash merge7936cb86cd95a8a6cb2884d01d865b17adf7b032 완료. 검사한 head와 merge tree 동일. 실제 merge SHA bootJar29585 재빌드 중.

- 실제 merge7936cb8의 bootJar29585 성공46초. 기존계정46575 성공9초, 신규 v2 가입21247 성공16초, v3 개정 재동의72909 성공20초. develop CI38802609143 세 검사 모두 성공. QA5880/PID29080은 동일 머지 jar/v3로 동작 중. 마지막 재실행 및 공통 smoke 남음.

- 최종 merge 검증: 재실행91924 성공8초, 공통28544 성공52초. QA11848/PID37784 로그 신규 오류 없음. 합성 QA enforcement만 false로 복원하고 게시·동의 이력 유지. develop CI38802609143 전체 성공. 약관 단계7/12 완료.
- 최종 감사 추가 검증60762: domain.policy 전체 25개 성공(1m25s). 부분 동의 거절/선택 privacy 생략/타 사용자 이력 격리/폐기 JWT401을 명시적으로 추가 검증했다. 기존 게시 DB 시계·미래 발효·마이크로초·동일 시각 정렬 테스트도 함께 통과했다.
