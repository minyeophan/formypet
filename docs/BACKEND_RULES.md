# 백엔드 규칙

Java 21 / Spring Boot 백엔드 작업을 시작할 때만 이 문서를 읽는다.

## 백엔드 시작 순서

1. `docs/CONTEXT.md`에서 현재 상태, 마지막 검증, 다음 행동을 확인한다.
2. `docs/AI_MISTAKES.md`에서 반복 실수와 필수 검증을 확인한다.
3. `docs/FRONTEND_STATUS.md`에서 프론트가 요구하는 API 계약을 확인한다.
4. 현재 변경 범위를 `git status --short backend docs scripts`로 확인한다.
5. 테스트 또는 재현 조건을 먼저 만든 뒤 구현한다.

## TDD 강제

구현 코드보다 테스트 코드가 반드시 먼저 작성된다.

1. Red: 실패하는 테스트를 먼저 작성한다. 컴파일 실패도 허용된다.
2. Green: 테스트를 통과하는 최소 코드만 작성한다.
3. Refactor: 동작을 유지하면서 정리한다.

이 순서를 건너뛰었으면 즉시 구현을 멈추고 테스트 작성으로 되돌아간다.

## Java 21 / Spring

- `synchronized` 블록과 메서드는 금지한다. Virtual Thread pinning 위험이 있으므로 `ReentrantLock` 또는 lock-free 패턴을 사용한다.
- DTO는 `record`를 우선 사용한다.
- Entity -> DTO 변환은 DTO record 내부의 `of(Entity)` 또는 `from(Request)` 정적 팩토리에 둔다.
- Service에는 DTO 변환 코드를 흩뿌리지 않는다.
- 조회 트랜잭션은 `@Transactional(readOnly = true)`를 사용한다.
- 변경 트랜잭션은 기본 `@Transactional`을 사용한다.
- Testcontainers 컨테이너는 `@Container`와 `static` 필드로 선언해 클래스 내에서 재사용한다.

## API 표준

- 모든 엔드포인트는 `/api/v1/` 접두사를 사용한다.
- 성공 응답은 공통 래퍼 `record ApiResponse<T>(T data, String message)`를 사용한다.
- 오류 응답은 RFC 7807 `ProblemDetail`을 사용한다.
- `ProblemDetail`에는 `type`, `title`, `status`, `detail`, `instance`를 일관되게 채운다.
- 페이지네이션은 커서 기반으로 한다. `?cursor=&limit=20` 형식을 사용하고 offset 방식은 쓰지 않는다.
- 소유권 검증은 컨트롤러가 아니라 서비스 계층에서 보장한다.

## Flyway 마이그레이션

- Entity 필드 추가, 변경, 삭제 시 반드시 새 `V{n+1}__describe_change.sql` 파일을 만든다.
- 기존 `V*.sql` 파일은 절대 수정하지 않는다. checksum 오류로 앱 시작이 실패할 수 있다.
- 프로덕션과 스테이징에서는 `ddl-auto: create` 또는 `ddl-auto: update`를 사용하지 않는다.
- 프로덕션과 스테이징은 `validate` 또는 `none`만 허용한다.
- 테스트 프로파일은 Flyway disabled, `ddl-auto: none`, `init-test.sql` 기준을 유지한다.
- 새 마이그레이션을 추가하면 `init-test.sql`도 테스트 스키마와 일치하는지 확인한다.

## 테스트 격리

- 통합 테스트 클래스에는 `@Transactional`을 적용해 각 테스트 종료 후 롤백되게 한다.
- 외부 상태가 있으면 `@BeforeEach`에서 명시적으로 정리한다.
- 파일, 메시지큐, 로컬 저장소처럼 트랜잭션 롤백이 닿지 않는 상태를 방치하지 않는다.
- `maxParallelForks = 1`을 유지한다. Testcontainers 병렬 실행 시 포트 충돌을 피하기 위함이다.
- 테스트를 통과시키려고 검증을 삭제하거나 약화하지 않는다.

## 프론트 수정 금지 기준

- 백엔드 Phase가 완료되기 전까지 `frontend/`를 수정하지 않는다.
- 백엔드 API 계약이 바뀌면 먼저 문서와 테스트로 계약을 고정한다.
- 프론트 연동이 필요한 경우 `docs/FRONTEND_STATUS.md`를 갱신하고 별도 프론트 작업으로 진행한다.
- 문서 정리 작업에서는 백엔드 구현 파일, 테스트 파일, 마이그레이션 파일을 수정하지 않는다.

## 필수 확인

- 기존 통과 테스트가 깨지면 즉시 수정한 뒤 진행한다.
- Flyway 파일 번호는 실제 `backend/src/main/resources/db/migration` 목록과 맞춘다.
- 미디어 저장, 커뮤니티 확장, 사용자 프로필처럼 이미 배포된 구조는 새 마이그레이션으로만 확장한다.
- 수동 검증이 필요한 Expo 연동은 백엔드 테스트 통과와 별도로 남은 일에 기록한다.
