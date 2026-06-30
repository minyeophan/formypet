# 08. 백엔드 구현 작업

> 상태: 확정 초안  
> 기준 문서: `05_MIGRATION_PLAN.md`, `06_BACKEND_IMPLEMENTATION_PLAN.md`, `07_BACKEND_TEST_PLAN.md`  
> 선행 단계: `05_MIGRATION_PLAN.md`, `06_BACKEND_IMPLEMENTATION_PLAN.md`, `07_BACKEND_TEST_PLAN.md`  
> 다음 단계: `09_FRONTEND_INTEGRATION_PLAN.md`  
> 변경 가능 여부: 구현 중 계약 오류가 발견되면 4~7번 문서를 먼저 고친 뒤 수정 가능

## 목적

지갑 지출 1차 백엔드 구현을 테스트 우선 순서로 분해한다. 이 문서는 실제 구현자가 `wallet_expenses` migration, test schema, 통합 테스트, DTO, service, controller, 공통 예외 처리를 어떤 순서로 만들지 정한다.

## 구현 범위

- 신규 지갑 지출 API만 구현한다.
- `activity_records`, `activity_types.expense`, `record_expense`는 만들거나 수정하지 않는다.
- 영수증 사진, 통합 지갑 API, 프론트 연동, 기존 `/records/expense/new` cleanup은 이번 범위가 아니다.
- 문서 구현 단계에서는 `backend/`, `frontend/`, migration, test 파일을 수정하지 않는다. 실제 구현 단계에서만 아래 파일을 만든다.

## 파일 계획

### 생성

| 파일 | 책임 |
|------|------|
| `backend/src/test/java/com/petyilgi/wallet/WalletExpenseIntegrationTest.java` | 7번 문서의 통합 테스트 구현 |
| `backend/src/main/resources/db/migration/V16__create_wallet_expenses.sql` | 운영 Flyway migration |
| `backend/src/main/java/com/petyilgi/common/exception/ApiException.java` | `status/type/title/detail/errorCode` 공통 예외 기반 |
| `backend/src/main/java/com/petyilgi/common/exception/NotFoundException.java` | 404 thin exception |
| `backend/src/main/java/com/petyilgi/common/exception/ForbiddenException.java` | 403 thin exception |
| `backend/src/main/java/com/petyilgi/common/exception/InvalidInputException.java` | 400 thin exception |
| `backend/src/main/java/com/petyilgi/wallet/WalletExpenseController.java` | `/api/v1/pets/{petId}/wallet/expenses` endpoint |
| `backend/src/main/java/com/petyilgi/wallet/WalletExpenseService.java` | 소유권, soft delete, 검증, 조회, 요약, cursor 처리 |
| `backend/src/main/java/com/petyilgi/wallet/dto/WalletExpenseCreateRequest.java` | 생성 request DTO |
| `backend/src/main/java/com/petyilgi/wallet/dto/WalletExpenseUpdateRequest.java` | 전체 수정 request DTO |
| `backend/src/main/java/com/petyilgi/wallet/dto/WalletExpenseResponse.java` | 단건 response DTO |
| `backend/src/main/java/com/petyilgi/wallet/dto/WalletExpenseListResponse.java` | 목록 response DTO |
| `backend/src/main/java/com/petyilgi/wallet/dto/WalletExpenseSummaryResponse.java` | 요약 response DTO |
| `backend/src/main/java/com/petyilgi/wallet/dto/WalletExpenseCategorySummary.java` | 카테고리별 요약 DTO |

### 수정

| 파일 | 책임 |
|------|------|
| `backend/src/test/resources/init-test.sql` | 테스트 schema에 `wallet_expenses` 반영 |
| `backend/src/main/java/com/petyilgi/common/exception/GlobalExceptionHandler.java` | `ApiException`, body/query parse 오류, Bean Validation 오류 매핑 |

### 수정 금지

- 기존 `backend/src/main/resources/db/migration/V*.sql`
- `backend/src/main/java/com/petyilgi/record/ActivityRecordService.java`
- `frontend/`
- `DESIGN.md`

## 구현 순서

### 1. 테스트 골격과 첫 Red 확인

- [ ] `WalletExpenseIntegrationTest`를 만든다.
- [ ] 기존 통합 테스트 패턴을 따라 인증 사용자, pet 생성 helper를 둔다.
- [ ] 첫 테스트는 `createExpenseSucceeds`만 작성한다.
- [ ] 요청 payload는 `expenseDate`, `expenseTime`, `amount`, `currency`, `category`, `itemName`, `note`를 포함한다.
- [ ] 기대값은 `201 Created`, `ApiResponse.data`, `createdAt/updatedAt` 없음, 저장된 `itemName`, `note`다.
- [ ] 아래 명령으로 실패를 확인한다.

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: endpoint, controller, DTO, table 중 아직 없는 요소 때문에 실패한다. 이 실패는 구현 시작 기준으로 기록한다.

### 2. Migration과 test schema 반영

- [ ] `V16__create_wallet_expenses.sql`을 추가한다.
- [ ] `wallet_expenses.item_name`은 `NULL` 허용으로 둔다.
- [ ] `currency`, `category`는 `VARCHAR`로 두고 DB `ENUM/CHECK`를 추가하지 않는다.
- [ ] 인덱스에는 `expense_time`을 포함한다.
- [ ] FK는 `users(id)`, `pets(id)`에 `ON DELETE CASCADE`를 둔다.
- [ ] `init-test.sql`에도 같은 table과 index를 반영한다.
- [ ] 운영 migration과 `init-test.sql`의 `created_at DEFAULT CURRENT_TIMESTAMP(6)`, `updated_at DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)` 동작 옵션이 일치하는지 확인한다.

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: schema 관련 실패는 사라지고, 아직 없는 controller/service 동작 때문에 실패한다.

### 3. 공통 예외 계약 구현

- [ ] `ApiException`에 `HttpStatus status`, `URI type`, `String title`, `String detail`, `String errorCode`를 둔다.
- [ ] `NotFoundException`, `ForbiddenException`, `InvalidInputException`은 `ApiException`을 상속한 얇은 예외로 둔다.
- [ ] `GlobalExceptionHandler`에서 `ApiException`을 `ProblemDetail`로 변환하고 `errorCode` property를 넣는다.
- [ ] `HttpMessageNotReadableException`은 `INVALID_INPUT`으로 매핑한다.
- [ ] `MethodArgumentTypeMismatchException` 등 query parameter 타입 파싱 오류는 `INVALID_INPUT`으로 매핑한다.
- [ ] Bean Validation 실패는 `VALIDATION_FAILED`와 `fieldErrors`로 매핑한다.
- [ ] 기존 예외 핸들러는 기존 API 호환을 깨지 않는 범위에서 유지한다.

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: 아직 wallet endpoint가 없어서 테스트는 실패할 수 있지만, 공통 예외 코드 compile 오류는 없어야 한다.

### 4. DTO 작성

- [ ] DTO는 Java `record`로 작성한다.
- [ ] request DTO의 숫자/필수 필드는 primitive가 아니라 wrapper type을 사용한다.
- [ ] `expenseDate`는 `@NotNull LocalDate`로 둔다.
- [ ] `expenseTime`은 nullable `LocalTime`으로 둔다.
- [ ] `amount`는 `@NotNull`, 양수 범위 Bean Validation으로 검증해 실패 시 `VALIDATION_FAILED`가 되게 한다.
- [ ] `currency`는 nullable `String`으로 두고 service에서 누락 시 `KRW`, 허용값 위반 시 `INVALID_INPUT`으로 처리한다.
- [ ] `category`는 `@NotBlank String`으로 두고 허용값 위반은 service에서 `INVALID_INPUT`으로 처리한다.
- [ ] `itemName`은 nullable, 최대 100자로 둔다.
- [ ] `note`는 nullable, 최대 500자로 둔다.
- [ ] response DTO에는 `createdAt`, `updatedAt`을 넣지 않는다.

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: DTO compile 오류가 없어야 한다.

### 5. Controller route 골격 연결

- [ ] `WalletExpenseController`에 `@RequestMapping("/api/v1/pets/{petId}/wallet/expenses")`를 둔다.
- [ ] POST는 `201 Created`와 `ApiResponse<WalletExpenseResponse>`를 반환한다.
- [ ] GET 목록은 `items`, `nextCursor`, `hasMore`를 반환한다.
- [ ] GET summary는 `totalAmount`, `count`, `currency`, `from`, `to`, `categories`를 반환한다.
- [ ] GET 단건은 `WalletExpenseResponse`를 반환한다.
- [ ] PUT은 전체 수정으로 동작한다.
- [ ] DELETE는 `204 No Content`와 빈 body를 반환한다.
- [ ] 인증 principal의 email만 service로 넘기고, 소유권 판단은 service에서 한다.

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: `createExpenseSucceeds`가 service 미구현 또는 DB insert 미구현 이유로 실패한다.

### 6. Service 최소 CRUD 구현

- [ ] `JdbcTemplate` 기반으로 구현한다.
- [ ] email로 user id를 조회한다.
- [ ] pet 검증은 `petId로 row 조회 -> 없음이면 PET_NOT_FOUND -> 소유자 불일치면 PET_FORBIDDEN -> soft deleted면 PET_NOT_FOUND_OR_DELETED` 순서로 처리한다.
- [ ] `itemName`, `note`는 trim 후 빈 문자열이면 `null`로 저장한다.
- [ ] `currency` 누락은 `KRW`로 저장하고, `KRW` 외 값은 `INVALID_INPUT`으로 처리한다.
- [ ] `category`는 4번 계약의 허용값만 받으며, 위반 시 `INVALID_INPUT`으로 처리한다.
- [ ] expense가 없거나 요청 pet에 속하지 않으면 `WALLET_EXPENSE_NOT_FOUND`로 처리한다.
- [ ] soft deleted pet의 지출 row는 보존하되 일반 목록/요약/합계에서는 제외한다.
- [ ] 첫 단계에서는 `createExpenseSucceeds`, `getExpenseReturnsSingleExpense`, `updateExpenseReplacesFields`, `deleteExpenseReturnsNoContentAndRemovesFromList`가 통과할 만큼만 구현한다.

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: 기본 CRUD 테스트가 통과하고, 아직 작성하지 않은 목록/cursor/요약/error 테스트는 다음 단계에서 추가한다.

### 7. 목록, cursor, 요약 구현

- [ ] 정렬은 `expense_date desc, expense_time desc nulls last, id desc`로 고정한다.
- [ ] cursor는 클라이언트가 해석하지 않는 base64url opaque payload로 발급한다.
- [ ] payload에는 `expenseDate`, `expenseTime`, `id` 정렬키를 담는다.
- [ ] HMAC 서명이나 서버 저장소 기반 발급 여부 검증은 구현하지 않는다.
- [ ] base64url payload 형식이 아니거나, payload 파싱이 안 되거나, 정렬키가 유효하지 않으면 `INVALID_CURSOR`로 처리한다.
- [ ] 다음 페이지가 없으면 `nextCursor: null`, `hasMore: false`를 반환한다.
- [ ] 요약은 조건에 맞는 전체 합계와 카테고리별 합계를 반환한다.
- [ ] 빈 요약은 `totalAmount: 0`, `count: 0`, `currency: KRW`, `categories: []`로 반환한다.
- [ ] query가 없으면 summary의 `from`, `to`는 `null`이고, query가 있으면 요청 값을 echo한다.

검증 대상 테스트:

- [ ] `listExpensesReturnsNewestFirst`
- [ ] `listExpensesFiltersByDateAndCategory`
- [ ] `listExpensesReturnsOpaqueNextCursor`
- [ ] `listExpensesUsesCursorWithoutDuplicates`
- [ ] `listExpensesReturnsEmptyList`
- [ ] `summaryReturnsTotalAndCategoryBreakdown`
- [ ] `summaryReturnsEmptySummary`

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: 목록, cursor, 요약 정상 흐름 테스트가 통과한다.

### 8. 오류 케이스 테스트 확장

- [ ] `unknownPetReturnsNotFound`는 `404`, `PET_NOT_FOUND`를 검증한다.
- [ ] 다른 사용자 pet은 POST/GET/PUT/DELETE 각각 `403`, `PET_FORBIDDEN`을 검증한다.
- [ ] soft deleted pet은 `404`, `PET_NOT_FOUND_OR_DELETED`를 검증한다.
- [ ] 다른 pet의 expense 또는 없는 expense는 `404`, `WALLET_EXPENSE_NOT_FOUND`를 검증한다.
- [ ] 잘못된 cursor는 `400`, `INVALID_CURSOR`를 검증한다.
- [ ] `from > to`는 `400`, `INVALID_DATE_RANGE`를 검증한다.
- [ ] 날짜 형식 오류, `limit` 타입 오류, `limit` 범위 오류는 `400`, `INVALID_INPUT`을 검증한다.
- [ ] 깨진 JSON 또는 body 타입 불일치는 `400`, `INVALID_INPUT`을 검증한다.
- [ ] `@NotNull`, `@NotBlank`, 금액 범위, 길이 초과 같은 Bean Validation 오류는 `400`, `VALIDATION_FAILED`, `fieldErrors`를 검증한다.
- [ ] 지원하지 않는 `category`, `currency`는 `400`, `INVALID_INPUT`을 검증한다.
- [ ] 인증 없는 요청은 `401`, `UNAUTHORIZED`를 검증한다.

검증:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

예상 결과: 7번 문서의 필수 테스트가 모두 통과한다.

### 9. 전체 백엔드 회귀 검증

- [ ] wallet 통합 테스트를 단독 실행한다.
- [ ] 전체 백엔드 테스트를 실행한다.
- [ ] 한글 깨짐 검사를 실행한다.
- [ ] whitespace 검사를 실행한다.
- [ ] `git status --short backend docs scripts`로 변경 범위가 요청 범위 안인지 확인한다.

검증 명령:

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest
.\gradlew.bat test
cd ..
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
git diff --check
git status --short backend docs scripts
```

## 구현 중 중단 기준

- API 계약과 테스트 기대값이 충돌하면 구현을 멈추고 4번/7번 문서를 먼저 수정한다.
- migration 번호가 실제 `backend/src/main/resources/db/migration/`의 마지막 번호와 다르면 5번 문서와 새 migration 파일명을 먼저 맞춘다.
- 기존 `activity_records` 기반 지출 구현을 고쳐야 할 것처럼 보이면 멈추고 범위를 재확인한다.
- 프론트 변경이 필요해지면 9번 문서로 넘기고 이번 백엔드 구현에서는 건드리지 않는다.

## 다음 단계로 넘어갈 수 있는 조건

- [x] 구현 대상 파일과 수정 금지 파일이 분리되어 있다.
- [x] Red-Green 순서가 테스트 단위로 나뉘어 있다.
- [x] migration과 `init-test.sql` 검증 조건이 명시되어 있다.
- [x] `INVALID_INPUT`, `VALIDATION_FAILED`, `INVALID_CURSOR`, pet/expense errorCode 검증이 구현 작업에 포함되어 있다.
- [x] 전체 백엔드 회귀 검증 명령이 명시되어 있다.
