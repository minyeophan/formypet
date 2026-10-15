# 06. 미디어 JPA 전환

## 상태와 기준

- 상태: JPA/저장소 추출, 서비스 책임 분리와 domain.media 패키지 이동 완료. 전체 회귀 및 MuMu 검증 중.
- 기준 develop: `607299ef2ac662173b62d7d16d49392817ec70a8` (커뮤니티 PR103 머지 후 모든 gate 완료)
- 브랜치: `refactor/jpa-media`
- 현재 HEAD `c0ad961`은 커뮤니티 완료 증적만 포함한다.
- 기준선: `gradlew.bat test --tests 'com.formypet.media.*' -PtestTimezone=Asia/Seoul --no-daemon`, 세션62950 성공1분53초. XML42 tests/0 failures/0 errors/0 skipped.
- PR/head/merge SHA: 아직 없음.

## 파일 및 책임

`com.formypet.domain.media`로 이동한다. API/스토리지 설정 이름은 유지한다.

| 기존 | 목표 |
|---|---|
| MediaController | controller/MediaController, API 경로·키 기반 재생·rate limit 호출 위치 유지 |
| dto/MediaResponse | dto/response/MediaResponse, 기존 URL/JSON 유지 |
| MediaService | service/MediaService 인터페이스 및 service/impl 파사드, 업로드·조회·삭제 유스케이스로 분리 |
| media_resources INSERT 및 조회/삭제 | entity/MediaResource, repository/MediaResourceRepository의 JPA CRUD/조건부 삭제/잠금 |
| users 용량 산술 및 소유자 잠금 | repository/jdbc/MediaQuotaRepository, 원자 조건 UPDATE 및 owner-first 순서 유지 |
| 프로필 join·기록 접근·반려로그 복합 조회/정리 | repository/query 또는 jdbc의 명시적 projection/복합 연산. 서비스의 SQL/Map row mapping 제거 |
| MediaStorageAttempts | service 인터페이스/impl, 별도 트랜잭션 intent 생성 및 회복 조율. SQL은 repository/jdbc의 작업 큐 저장소 |
| OrphanMediaCleanup | service 인터페이스/impl, REQUIRES_NEW 큐 등록. 실패 로그에 경로/인증 정보 미노출 |
| MediaCleanupRunner | scheduling/MediaCleanupRunner, 겹침 방지·실패 재시도 조율. 조회/큐 삭제 SQL은 저장소 |
| 파일 삭제/롤백 동기화 | storage의 전용 협력 객체로 분리하여 업로드 유스케이스에서 명시적으로 호출 |
| MediaFileValidation/크기 읽기 | validation 및 storage의 파일 검증/이미지 크기 읽기 책임으로 분리 |
| storage/* | domain/media/storage, local/R2 선택 설정 및 IOException 계약 보존 |

메타데이터는 기존 scalar user/pet/record ID와 FK cascade를 그대로 사용한다. 기존 DATETIME(6)는 UTC LocalDateTime 직접 JDBC 타입으로 매핑한다. 스키마 변경 및 자동 DDL은 하지 않는다. status STORED, visibility, media_kind와 URL 의미를 유지한다.

## 보존할 계약

1. 일반 업로드 검증과 keyed upload의 magic-byte 검증은 서로 다르다. 일반 업로드의 기존 400/500 계약을 임의로 강화하거나 바꾸지 않는다. 5MiB, jpg/jpeg/png/webp, 확장자 기반 MIME을 보존한다.
2. 업로드는 소유권/대상 확인 → 파일 검증 → 원자 용량 예약 → 미리 정한 저장 키의 REQUIRES_NEW intent 커밋 → intent 행 잠금 → 파일 I/O → 메타데이터 INSERT/flush → rollback cleanup 등록 → intent 삭제 순서다.
3. 파일 I/O 실패 및 메타데이터 INSERT/flush 실패는 즉시 파일 정리를 시도한다. 정리 실패는 별도 커밋 큐에 남기며 큐마저 실패해도 durable intent로 복구 가능해야 한다.
4. 외부 트랜잭션 rollback 시 메타데이터/용량/intent 삭제가 롤백되고 파일 삭제 동기화가 실행된다. JPA 저장 지연으로 실패가 cleanup try/catch 밖에 발생하지 않게 saveAndFlush한다.
5. 프로필 교체는 기존 파일의 bytes 차액과 item delta로 한도를 검사한다. 교체된 파일 삭제 때 용량을 두 번 차감하지 않는다.
6. record/반려로그 삭제와 draft 만료 정리는 users owner 잠금 → media 잠금 순서를 유지한다. 중복 삭제는 row count에 따라 용량을 한 번만 차감한다. 기존 24시간 UTC 만료와 pet log 연결 정리 조건을 유지한다.
7. cleanup 큐는 DB commit 이후 관측되는 행만 정리한다. 현재 참조된 파일은 삭제하지 않는다. 파일 삭제 성공 후 큐 행을 제거하고 실패는 다음 실행에 재시도한다. 한 프로세스의 cleanup 중복 실행 방지를 유지한다.
8. intent 회복은 1시간 이전 intent 100개, created_at 순서, FOR UPDATE SKIP LOCKED로 진행한다. 살아 있는 writer를 건너뛰고 참조가 없는 키만 정리 큐에 넣는다.
9. private media는 소유자만, public endpoint는 PUBLIC만, 프로필 이미지는 현재 users.profile_media_id를 조회한다. 기존 not-found/403/400 코드와 상세 메시지를 유지한다. repository AOP가 입력 IllegalArgumentException을500으로 바꾸지 않게 검증은 밖에서 한다.
10. PET_LOG_DRAFT/PET_LOG 이미지 크기 읽기는 소유권/status와 최대5천만 화소 규칙 및 WEBP 크기 fallback을 보존한다.
11. Rate limiter는 요청 경계에서 실행되고 실패한 업로드도 budget을 소비한다. idempotency 및 여러 파일 한 번의 용량 예약을 보존한다.

## 호출부와 범위

- pet/record/community 서비스 및 커뮤니티 controller, user 프로필 서비스/controller, petlog 서비스/만료 job, 공통 idempotency가 호출한다. 이번 PR에서 이들의 업무 규칙은 바꾸지 않고 필요한 import/인터페이스 연결만 갱신한다.
- 로컬/R2 storage와 설정의 패키지 참조, 테스트의 MockitoBean/SpyBean, 직접 생성하는 CleanupRunner 테스트를 함께 이동한다.
- 반려로그 소유 데이터 삭제 SQL은 현재 media가 수행하는 계약을 보존한 전용 저장소로 옮긴다. petlog 전체 패키지 정리는 최종 잔여 Java 점검 범위로 유지한다.

## 실행 단계 및 완료 조건

- [x] 서비스 전체, 큐/intent/스토리지, 호출부, 마이그레이션 V7/V10/V20/V38/V42/V43 조사
- [x] 기존 media/storage 기준선 통과
- [x] MediaResource 규칙/매핑 테스트 RED → GREEN
- [x] metadata JPA CRUD/명시적 flush/조건부 삭제 및 대표 조회 비용 검증
- [x] 용량/큐/intent/복합 SQL 저장소 추출, 서비스 SQL 및 row mapping 제거
- [x] 업로드/조회/삭제/롤백 정리 책임 분리, 인터페이스와 패키지 정리
- [x] 기존 media, user/profile, pet, record, community, petlog/idempotency 회귀 통과
- [x] 용량 경쟁·중복 삭제·교체 차액·외부 rollback·쓰기/삭제/큐 실패 회귀 보강
- [x] backend 전체 Asia/Seoul 통과 및 독립 리뷰 해결
- [x] MuMu 프로필/펫/기록/게시글 업로드·교체·삭제와 실제 사진 decode, 재실행 보존 검증. 반려로그 draft/commit/삭제 경로도 포함
- [ ] refactor : 커밋/PR develop, 최신 head 전체 CI 통과
- [ ] squash merge 후 실제 develop SHA 재빌드/기동
- [ ] 머지 SHA MuMu 기존/전체/공통 smoke, develop CI 및 로그 확인
- [ ] 증적 기록 후 policy 시작

QA는 기존 격리 DB3318/API18083/mediatest 앱/MuMu127.0.0.1:16384를 사용한다. 커뮤니티 서버51889를 종료하고 미디어 구현 bootJar63701(29초 성공)로 서버98746/PID25556을 기동했다. schema43/health 정상. Flutter 실행은 `--no-uninstall`로 기존 인증/데이터를 보존한다.

## 구현 중 검증 기록

- 엔티티 RED67150 → GREEN25333: 기존42 + 엔티티3 통과.
- JPA 저장소 RED96722 → GREEN30629: UTC 기존 데이터 읽기, 실제 INSERT/flush, 소유자 조건부 삭제 포함48개 통과(2분6초).
- 용량 저장소 RED33458 → GREEN60655: 한도 초과 시 두 카운터 원자적 거절, 프로필 차액, 음수 하한, 차감 zero floor 및 owner 잠금 포함50개/실패0/오류0/스킵0(2분8초). 기존 동시 중복 삭제와 파일 실패/외부 rollback 회귀 포함.
- 위 50개 테스트 시점에는 서비스의 복합 조회/큐 SQL이 남아 있었다. 아래 후속 단계에서 제거했다.
- 큐/intent 저장소 RED1513 → GREEN1193: 52개/실패0/오류0(2분7초). 기존 활성 writer SKIP LOCKED 및 외부 rollback 복구 검증 포함.
- 이후 복합 조회를 `MediaAttachmentRepository`, 단순 조회를 JPA `MediaFile`/`MediaLocation` projection으로 이동했다. 현재 legacy media 서비스/정리 작업의 SQL·Map 행 매핑 검색 결과 없음. 새 조회/만료 테스트 RED70143 확인 후 구현, 미디어+반려로그 통합 검증 중.
- 결정: 소유자 잠금 이후의 media 현재 읽기는 JDBC의 명시적 `FOR UPDATE`를 유지한다. 기존 영속성 컨텍스트에 들어온 entity의 이전 값으로 잠금 결과를 대신하지 않도록 typed projection을 사용한다. 단순 저장/조회/조건부 및 기록 일괄 삭제는 JPA가 담당한다.
- 조회/잠금 추출 GREEN53896 성공2분12초. 패키지/인터페이스 분리 GREEN3269 성공2분24초,64개/실패0/오류0/스킵0.
- 일반 파일 검증/이미지 크기 분리 RED31518 → GREEN99864 성공2분19초,70개/실패0/오류0/스킵0. 마지막 슬롯 동시 예약 및 한도 도달 프로필 교체도 포함.
- 독립 소스 리뷰 pet_review: 미해결 actionable finding 없음. 실제 전체 테스트61173 실행 중. 단건 entity/projection 각1문장 및 관계 entity 미로딩 검증 추가 포함.
- MuMu 통합 시나리오 `media_migration_test.dart`: 실제 앱 서비스 업로드·교체, private/public 접근, 기록 삭제, 반려로그 draft/중복 요청/등록/사진 제거/화면 삭제, 각 화면 decode 및 재실행 fixture 검증. 갤러리 선택 UI를 자동화한 것은 아니며 실제 HTTP 업로드와 화면 표시·삭제를 검증한다. Analyzer16320 통과. 첫 MuMu44749 실행 중.
- MuMu44749 전체 시나리오26초 통과(`MEDIA_API_UPLOAD_REPLACE_IDEMPOTENCY_VERIFIED`, `MEDIA_UI_VERIFIED`),61628 새 프로세스 기존 fixture11초 통과(`MEDIA_RESTART_VERIFIED`). 서버98746 로그에 추가 오류 없음. 미디어 테스트와 조회비용 테스트의 독립 후속 리뷰도 지적 없음. 전체61173은 계속 실행 중이므로 아직 커밋/PR하지 않는다.
- 전체61173 최종 성공8분16초. XML451개/실패0/오류0/스킵0, Asia/Seoul. 대표 메타데이터 entity/projection 조회 각각1 SQL, projection 엔티티 로딩0 검증 포함.
- 게시글 사진 삭제 및 펫 삭제 시 초안/등록 반려로그 사진 제거를 MuMu 시나리오에 보강했다. Analyzer80146 통과. 확장 전체22022 실행 중이며 통과 전 PR하지 않는다.
- 확장 전체22022도19초 통과. backend451/0, 독립 리뷰, Flutter analyzer, MuMu 전체·재실행 및 추가 삭제 경로의 로컬 gate를 모두 통과했다. 이제 구현 커밋/PR 후 최신 head CI 및 실제 머지 SHA 재검증이 남는다.
