# 12. Global 및 잔여 Java 정리

Base: 6b83f4af9f2257cbf8ffd06a6ab91637835cb245
Branch: refactor/jpa-global
상태: 구현·로컬 회귀·독립 리뷰·branch MuMu 완료, PR 준비

## 범위와 계약
- common의 exception/response/time/ratelimit/idempotency와 HealthController를 global의 해당 책임 패키지로 이동한다. config 및 monitoring도 global 하위로 이동한다. 테스트와 모든 Java 참조, reflection 문자열, CI 필터를 함께 갱신한다.
- 공통 IdempotencyService의 직접 SQL/row mapping을 repository로 분리한다. 사용자 잠금 → receipt current read → callback → receipt insert의 동일 트랜잭션 순서와 fingerprint, 결과 ID/version만 저장, rollback 및 삭제 후 replay 계약을 유지한다.
- RequestRateLimiter의 SQL과 JDBC 시간 매핑을 typed repository로 분리한다. REQUIRES_NEW, 정렬된 잠금 순서, 토큰/슬라이딩 윈도우 계산, 실패 시 전체 rollback, 429 retryAfter 및 DB 실패503은 그대로 유지한다.
- 잔여 petlog 8개 파일을 domain.petlog로 이동한다. controller, dto/request, dto/response, entity, repository, service/impl, scheduling으로 분리한다. PetLogService 인터페이스를 제공한다.
- PetLog의 생성/갱신/삭제는 JPA 중심으로 전환한다. pet_logs의 id, pet_id/user_id, entry_at(DATETIME6 현지 시각), note, version, created_at/updated_at(UTC)을 그대로 매핑한다. 사진 연결/승격/정리 및 preference upsert와 timeline projection은 전용 repository에서 처리한다.
- API URL/JSON/검증/오류 코드, 기록 낙관적 버전 충돌, 사진 권한 및 순서/크기, 미디어 용량 반환, 연월/동일시간 커서 정렬, idempotent appliedVersion, 사용자/펫 소유권을 보존한다. 스키마 변경은 계획하지 않는다.
- Ruling: 원자적 limiter 및 receipt current-read, 사진 연결 일괄 재배치와 preference upsert SQL은 repository에 유지한다. 이유는 기존 잠금/원자성 계약을 보존하기 위해서다. JPA persistence context와 혼합되는 지점은 테스트로 검증한다.

## 순서 및 증거
1. [x] common/config/petlog 기준선26726 완료 확인.
2. [x] Idempotency typed 저장소 RED→GREEN 및 기존 동시 replay/rollback tests.
3. [x] Limiter typed 저장소 RED→GREEN 및 기존 경계/경쟁 tests.
4. [x] PetLog 엔티티/저장소 RED→GREEN, 서비스 연결 및 사진/버전/UTC 회귀.
5. [x] 패키지/인터페이스/DTO 이동, 모든 Java SQL 및 의존성 감사.
6. [x] 전체 backend/Flutter/monitoring 검증, 독립 리뷰와 branch MuMu.
7. [ ] refactor : 커밋, develop PR 및 exact-head 모든 CI 통과 후 squash.
8. [ ] 실제 merge SHA 강제 빌드, develop CI, MuMu 전체 도메인 회귀 및 재실행, 서버 로그 검증.
9. [ ] 마스터 계획 전체 완료 조건에 대한 파일/PR/테스트/런타임 증거 감사.

## 테스트와 MuMu
- 기존 PetLogIntegrationTest, PetLogRequestValidationTest, IdempotencyIntegrationTest, RequestRateLimiterIntegrationTest/Test, OpenApiIntegrationTest, TimeModelTest와 전체 backend suite.
- 새 저장소 tests는 실제 MySQL에서 receipt nullable version 및 rollback/current read, limiter UTC/fractional token/current read, PetLog 버전/시간/삭제/사진 원자성을 검증한다.
- MuMu 127.0.0.1:16384, isolated com.formypet.frontend.mediatest, API18083/DB3318. pet_log_media_test 및 기존 domain migration tests와 공통 android_ux_test를 실제 머지 버전에서 실행한다. 기존 fixture 검증은 전체 테스트로 계정이 교체되기 전에 수행한다.
- 실제 외부 Kakao/SMTP/FCM 성공은 주장하지 않는다. 기존 mock 계약과 단말 내부 UI/API 범위를 구분하여 보고한다.

## PetLog 버전 결정
- Ruling: 기존 API version은 성공한 수정마다(내용이 같아도) 1 증가한다. 사용자 잠금 다음 현재 pet_log FOR UPDATE+refresh를 사용하고, 엔티티 revise에서 명시적으로 version을 증가시킨다. 자동 @Version만으로 무변경 수정이 생략되는 위험을 피한다. 모든 변경은 이 잠금 경로를 거치며 JPA flush를 사진 처리/응답 전에 수행한다. 생성 시 DB created_at/updated_at 기본값은 유지한다. 기존 엔티티 캐시보다 최신 DB version이 우선임을 테스트한다.

## 현재 검증 증거
- 기준선 47개 → receipt 49개 → limiter 51개 → PetLog 엔티티 53개 → 조회/연결 55개 → API 경쟁/사진 rollback 56개 통과.
- 이동 후 global/petlog/monitoring 및 구조 검사 70개 통과. 전체 Java 386개, 직접 DB 접근 또는 명시적 쿼리 51개 파일은 모두 repository 아래에 있다. 전체 목록: java-inventory.md.
- 독립 global_review: actionable Critical/Important/Minor 없음. 런타임 검증은 별도 수행한다.
- 실제 auth merge 백엔드 기준 MuMu: 사진 업로드/생성/replay/커서/UI 수정/충돌/UI 삭제 54229(20s), 재실행 26272(8s) 통과. 신규 테스트의 lazy ListView 스크롤 문제를 수정했다.
- 전체 backend 첫 실행 53473: 524개 중 UserProfileIntegrationTest의 이전 파일 정리 확인 1개 실패. 같은 클래스 단독 45004는 변경 없이 7개 모두 통과.
- Ruling: Spring 테스트 컨텍스트는 DB를 공유하지만 서로 다른 파일 경로 또는 mock 저장소를 사용한다. 다른 컨텍스트의 주기적 정리 작업이 공유 큐를 소비할 수 있으므로 test profile의 media cleanup 주기를 1시간으로 통일했다. 기존 profile/rollback 테스트와 같은 설정이며 명시적 cleanup 호출과 파일 삭제 검증은 유지한다. 실제 환경의 30초 주기는 변경하지 않는다. 전체 재검증 6402 진행 중.
- 전체 backend 재검증6402: 524/0/0/0, 13m46s 성공. 추가 약관 감사60762: 25/0/0/0, 1m25s 성공(추가 테스트 포함). Flutter analyze99073 no issues, unit88228 1,197개 통과. branch bootJar63903 성공14s, QA14071 health200. MuMu 기존 데이터57124 성공5s.
- branch MuMu 전체48172 성공18s, 새 fixture 재실행15617 성공4s. 기존57124/전체/재실행 모두 통과하고 QA14071 로그 ERROR/Exception 없음. 실제 merge SHA 검증은 PR 머지 후 수행한다.
