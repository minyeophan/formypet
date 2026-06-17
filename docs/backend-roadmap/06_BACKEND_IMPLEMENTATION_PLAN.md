# 06. 백엔드 구현 계획

> 상태: 확정 초안  
> 기준 문서: `02_DOMAIN_DECISIONS.md`, `04_API_CONTRACT.md`, `05_MIGRATION_PLAN.md`  
> 선행 단계: `02_DOMAIN_DECISIONS.md`, `03_TARGET_ERD.md`, `04_API_CONTRACT.md`, `05_MIGRATION_PLAN.md`  
> 다음 단계: `07_BACKEND_TEST_PLAN.md`, `08_BACKEND_IMPLEMENTATION_TASKS.md`  
> 변경 가능 여부: 테스트 계획 확정 전까지 가능

## 목적

지갑 지출 1차 API의 패키지, DTO, service, controller 책임을 구현 전에 고정한다. 기존 기록 도메인과 분리하고, API 계약의 status/body/errorCode 정책을 구현 기준으로 삼는다.

## 입력 문서

- `02_DOMAIN_DECISIONS.md`
- `04_API_CONTRACT.md`
- `05_MIGRATION_PLAN.md`
- 기존 백엔드 패키지 구조
- 기존 `MockMvc + IntegrationTestSupport` 통합 테스트 패턴

## 적용 원칙

- Spring Boot / Java 21 / `JdbcTemplate` 중심 패턴을 따른다.
- DTO는 Java `record`를 우선 사용한다.
- 조회 transaction은 `@Transactional(readOnly = true)`를 사용한다.
- 변경 transaction은 기본 `@Transactional`을 사용한다.
- 소유권 검증은 controller가 아니라 service 계층에서 보장한다.
- 지갑 지출은 기록 도메인 `ActivityRecordService`에 넣지 않는다.
- 성공 응답은 DELETE를 제외하고 `ApiResponse<T>`를 사용한다.
- DELETE 성공은 `204 No Content`이며 body가 없다.
- 오류 응답은 `ProblemDetail`에 `errorCode` property를 추가한다.

## 구현 대상

| 항목 | 결정 |
|------|------|
| 대상 도메인 | 지갑 지출 |
| 패키지 | `com.petyilgi.wallet` |
| Controller | `WalletExpenseController` |
| Service | `WalletExpenseService` |
| Repository | 별도 repository 없이 service 내부 `JdbcTemplate` 사용 |
| DTO 패키지 | `com.petyilgi.wallet.dto` |
| 예외 | 공통 `ApiException` 추가, 필요하면 이를 상속한 `NotFoundException`, `ForbiddenException`, `InvalidInputException` 사용 |
| 만들지 않을 것 | JPA entity, `record_expense`, `activity_types.expense`, 영수증/사진 연결, 통합 지갑 API |

## DTO

| DTO | 용도 | 주요 필드 |
|-----|------|-----------|
| `WalletExpenseCreateRequest` | 생성 요청 | `expenseDate`, `expenseTime`, `amount`, `currency`, `category`, `itemName`, `note` |
| `WalletExpenseUpdateRequest` | 전체 수정 요청 | 생성 요청과 동일. `expenseDate`, `amount`, `category` 필수 |
| `WalletExpenseResponse` | 단건 응답 | `id`, `petId`, `expenseDate`, `expenseTime`, `amount`, `currency`, `category`, `categoryLabel`, `itemName`, `note` |
| `WalletExpenseListResponse` | 목록 응답 | `items`, `nextCursor`, `hasMore` |
| `WalletExpenseSummaryResponse` | 요약 응답 | `totalAmount`, `count`, `currency`, `from`, `to`, `categories` |
| `WalletExpenseCategorySummary` | 카테고리별 요약 | `category`, `categoryLabel`, `amount`, `count` |

`createdAt`, `updatedAt`은 1차 응답 DTO에 넣지 않는다.

## Controller 책임

- `/api/v1/pets/{petId}/wallet/expenses` 하위 endpoint를 매핑한다.
- 인증 principal에서 email을 얻어 service에 전달한다.
- `@Valid`로 request body 검증을 실행한다.
- POST는 `201 Created`와 `ApiResponse<WalletExpenseResponse>`를 반환한다.
- GET/PUT은 `200 OK`와 계약 DTO wrapper를 반환한다.
- DELETE는 service 호출 후 `204 No Content`만 반환한다.
- 소유권, 삭제 pet, expense 소속 검증을 controller에서 직접 하지 않는다.

## Service 책임

- email로 사용자 id를 찾는다.
- `petId` 검증은 `petId`로 row 조회, 없음이면 `PET_NOT_FOUND`, 소유자 불일치면 `PET_FORBIDDEN`, soft deleted면 `PET_NOT_FOUND_OR_DELETED` 순서로 판정한다.
- `expenseId`가 없거나 요청 `petId`에 속하지 않으면 `WALLET_EXPENSE_NOT_FOUND`로 처리한다.
- `itemName`, `note`는 trim 후 빈 문자열이면 `null`로 저장한다.
- `amount` 범위는 DTO Bean Validation으로 검증하고 실패 시 `VALIDATION_FAILED`로 처리한다.
- `currency`는 생략 시 `KRW`, 제공 시 `KRW`만 허용한다.
- `category`는 4번 문서의 enum만 허용한다.
- 목록 cursor는 opaque 문자열로 발급하고, 잘못된 cursor는 `INVALID_CURSOR`로 처리한다.
- `from > to`는 `INVALID_DATE_RANGE`로 처리한다.
- query parameter의 날짜 형식 오류, `limit` 타입 오류, `limit` 범위 오류는 `INVALID_INPUT` 계열로 처리한다.
- 목록 정렬은 `expense_date desc, expense_time desc nulls last, id desc`를 보장한다.
- 요약은 조건에 맞는 전체 합계를 반환하고, 빈 결과는 `totalAmount: 0`, `count: 0`, `categories: []`로 반환한다.

## 오류 처리

- 공통 `ApiException`은 `status`, `type`, `title`, `detail`, `errorCode`를 가진다.
- `GlobalExceptionHandler`는 `ApiException`을 해당 status의 `ProblemDetail`로 변환하고 `errorCode` property를 추가한다.
- `NotFoundException`, `ForbiddenException`, `InvalidInputException`은 필요하면 `ApiException`을 상속한 얇은 예외로 둔다.
- request body의 Bean Validation 오류는 `VALIDATION_FAILED`로 처리한다.
- request body JSON 파싱 오류나 타입 불일치는 `HttpMessageNotReadableException` 등을 핸들링해 `INVALID_INPUT`으로 처리한다.
- query parameter 파싱/범위 오류는 `INVALID_INPUT` 계열로 처리한다.
- query parameter 타입 오류는 `MethodArgumentTypeMismatchException` 등을 핸들링해 `INVALID_INPUT`으로 처리한다.
- 최소 errorCode는 4번 문서 표와 일치해야 한다.
- 기존 `AccessDeniedException`, `IllegalArgumentException` 핸들러는 기존 API 호환을 위해 유지하되, 지갑 API의 계약 오류는 `ApiException` 계열을 우선 사용한다.

## Cursor 구현 기준

- 클라이언트가 해석하지 않는 opaque 문자열로 취급한다.
- 1차 구현은 base64url로 인코딩한 opaque payload를 사용한다.
- 내부 payload는 `expenseDate`, `expenseTime`, `id`를 담을 수 있다.
- HMAC 서명이나 서버 저장소 기반 발급 여부 검증은 1차 범위에 포함하지 않는다.
- 서버가 발급한 base64url payload 형식이 아니거나 디코딩/파싱 실패, 정렬 키 누락이 있으면 `INVALID_CURSOR`로 처리한다.
- 다음 페이지가 없으면 `nextCursor`는 `null`, `hasMore`는 `false`다.

## 이번 단계에서 결정하지 않는 것

- 프론트 파일명과 provider/service 구현
- 영수증/사진 첨부 API
- 통합 지갑 API
- 기존 `/records/expense/new` cleanup
- 운영 배포 절차

## 다음 단계로 넘어갈 수 있는 조건

- [x] 패키지와 클래스명이 확정되어 있다.
- [x] DTO 이름과 필드가 API 계약과 일치한다.
- [x] service 책임과 controller 책임이 분리되어 있다.
- [x] 만들지 않을 구조가 명시되어 있다.
