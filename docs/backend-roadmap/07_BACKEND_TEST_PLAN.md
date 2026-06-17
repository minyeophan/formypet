# 07. 백엔드 테스트 계획

> 상태: 확정 초안  
> 기준 문서: `04_API_CONTRACT.md`, `06_BACKEND_IMPLEMENTATION_PLAN.md`  
> 선행 단계: `04_API_CONTRACT.md`, `06_BACKEND_IMPLEMENTATION_PLAN.md`  
> 다음 단계: `08_BACKEND_IMPLEMENTATION_TASKS.md`  
> 변경 가능 여부: 구현 직전까지 가능

## 목적

지갑 지출 1차 API 구현 전에 실패해야 하는 통합 테스트 목록과 기대 결과를 고정한다. 구현 코드는 테스트가 먼저 실패한 뒤 작성한다.

## 입력 문서

- `04_API_CONTRACT.md`
- `06_BACKEND_IMPLEMENTATION_PLAN.md`
- 기존 `ActivityRecordIntegrationTest`, `PetIntegrationTest` 패턴
- `backend/src/test/resources/init-test.sql`

## 적용 원칙

- 구현 코드보다 테스트 코드를 먼저 작성한다.
- 통합 테스트는 기존 `IntegrationTestSupport`와 `MockMvc` 패턴을 따른다.
- 테스트 클래스명은 `WalletExpenseIntegrationTest`로 한다.
- 테스트는 인증, 소유권, validation, 정상 CRUD, 목록, 요약, 삭제 pet 정책을 분리한다.
- 기존 테스트를 약화하거나 삭제하지 않는다.
- DELETE 성공은 `status().isNoContent()`와 빈 body를 검증한다.
- 오류 응답은 HTTP status와 `errorCode`를 함께 검증한다.
- request body의 Bean Validation 실패는 `VALIDATION_FAILED`와 `fieldErrors`를 검증한다.
- request body JSON 파싱 오류와 타입 불일치는 `INVALID_INPUT`을 검증한다.
- 서비스 계층의 계약 검증 실패와 query parameter 파싱/범위 오류는 `INVALID_INPUT` 계열을 검증한다.
- `from > to`는 일반 `INVALID_INPUT`이 아니라 `INVALID_DATE_RANGE`를 검증한다.
- cursor는 base64url opaque 형식 기준으로 검증하고, HMAC 서명 또는 서버 저장소 기반 발급 여부 검증은 테스트하지 않는다.

## 필수 테스트 목록

| 테스트명 | API | 준비 데이터 | 기대 결과 | 우선순위 |
|----------|-----|-------------|-----------|----------|
| `createExpenseSucceeds` | POST `/api/v1/pets/{petId}/wallet/expenses` | 인증 사용자와 pet | `201`, wrapper, `itemName`, `note` 저장 | 필수 |
| `createExpenseAllowsNullItemName` | POST | `itemName` 누락 또는 빈 문자열 | `201`, `itemName: null` | 필수 |
| `getExpenseReturnsSingleExpense` | GET 단건 | 생성된 지출 | `200`, `createdAt/updatedAt` 없음 | 필수 |
| `updateExpenseReplacesFields` | PUT | 생성된 지출 | `200`, 금액/카테고리/메모 변경 | 필수 |
| `updateExpenseClearsNullableFields` | PUT | `itemName`, `note`가 있는 기존 지출 | 요청에서 `itemName: null`, `note: null`을 보내면 응답과 재조회 결과가 모두 `null` | 필수 |
| `deleteExpenseReturnsNoContentAndRemovesFromList` | DELETE + 목록 | 생성된 지출 | DELETE `204` body 없음, 목록 제외 | 필수 |
| `listExpensesReturnsNewestFirst` | GET 목록 | 날짜/시간/null 시간 혼합 | `expenseDate desc`, `expenseTime nulls last`, `id desc` | 필수 |
| `listExpensesFiltersByDateAndCategory` | GET 목록 | 여러 날짜/카테고리 | 조건에 맞는 항목만 반환 | 필수 |
| `listExpensesReturnsOpaqueNextCursor` | GET 목록 | `limit`보다 많은 데이터 | `hasMore: true`, `nextCursor` 존재, 다음 요청 성공 | 필수 |
| `listExpensesUsesCursorWithoutDuplicates` | GET 목록 | `limit`보다 많은 정렬 대상 데이터 | 1페이지와 2페이지의 expense id가 겹치지 않고 정렬 순서가 유지됨 | 필수 |
| `listExpensesReturnsEmptyList` | GET 목록 | 지출 없음 | `items: []`, `nextCursor: null`, `hasMore: false` | 필수 |
| `summaryReturnsTotalAndCategoryBreakdown` | GET summary | 여러 카테고리 지출과 `from/to` query | 합계, 건수, 카테고리별 합계, `currency: KRW`, 요청한 `from/to` echo | 필수 |
| `summaryReturnsEmptySummary` | GET summary | 지출 없음, query 없음 | `totalAmount: 0`, `count: 0`, `currency: KRW`, `from: null`, `to: null`, `categories: []` | 필수 |
| `unknownPetReturnsNotFound` | GET 목록 | 존재하지 않는 petId | `404`, `PET_NOT_FOUND` | 필수 |
| `createExpenseForOtherUsersPetReturnsForbidden` | POST | 다른 사용자 pet | `403`, `PET_FORBIDDEN` | 필수 |
| `listExpensesForOtherUsersPetReturnsForbidden` | GET 목록 | 다른 사용자 pet | `403`, `PET_FORBIDDEN` | 필수 |
| `updateExpenseForOtherUsersPetReturnsForbidden` | PUT | 다른 사용자 pet과 임의 expenseId | `403`, `PET_FORBIDDEN` | 필수 |
| `deleteExpenseForOtherUsersPetReturnsForbidden` | DELETE | 다른 사용자 pet과 임의 expenseId | `403`, `PET_FORBIDDEN` | 필수 |
| `deletedPetReturnsNotFoundOrDeleted` | GET 목록 | soft deleted pet | `404`, `PET_NOT_FOUND_OR_DELETED` | 필수 |
| `expenseOutsidePetReturnsNotFound` | GET 단건 | 같은 사용자 다른 pet의 expenseId | `404`, `WALLET_EXPENSE_NOT_FOUND` | 필수 |
| `unknownExpenseReturnsNotFound` | GET 단건 | 없는 expenseId | `404`, `WALLET_EXPENSE_NOT_FOUND` | 필수 |
| `invalidCursorReturnsBadRequest` | GET 목록 | 잘못된 cursor | `400`, `INVALID_CURSOR` | 필수 |
| `invalidDateRangeReturnsBadRequest` | GET 목록 또는 summary | `from > to` | `400`, `INVALID_DATE_RANGE` | 필수 |
| `invalidDateFormatReturnsInvalidInput` | GET 목록 또는 summary | 잘못된 `from`/`to` 형식 | `400`, `INVALID_INPUT` | 필수 |
| `invalidLimitReturnsInvalidInput` | GET 목록 | `limit` 타입 오류 또는 `1..50` 밖 값 | `400`, `INVALID_INPUT` | 필수 |
| `validationFailureReturnsFieldErrors` | POST | `amount: 0`, 필수값 누락, 길이 초과 | `400`, `VALIDATION_FAILED`, `fieldErrors` | 필수 |
| `malformedJsonReturnsInvalidInput` | POST | 깨진 JSON 또는 필드 타입 불일치 | `400`, `INVALID_INPUT` | 필수 |
| `unsupportedCategoryReturnsInvalidInput` | POST | 허용되지 않은 category | `400`, `INVALID_INPUT` | 필수 |
| `unsupportedCurrencyReturnsInvalidInput` | POST | `KRW`가 아닌 currency | `400`, `INVALID_INPUT` | 필수 |
| `unauthenticatedRequestReturnsUnauthorized` | GET 목록 | Authorization 없음 | `401`, `UNAUTHORIZED` | 필수 |

## 보조 테스트

- `currency` 생략 시 `KRW` 저장
- `note` 빈 문자열은 `null` 저장
- `itemName`이 없을 때 화면 제목 fallback은 프론트 테스트 범위이므로 백엔드에서는 저장 값만 검증
- cursor 테스트는 1페이지와 2페이지를 합쳤을 때 기대한 정렬 앞부분이 누락 없이 이어지는지 확인한다.

## 오류 검증 세부 기준

- `PET_NOT_FOUND`, `PET_FORBIDDEN`, `PET_NOT_FOUND_OR_DELETED`가 섞이지 않도록 pet 검증 순서를 테스트로 고정한다.
- `petId`가 없으면 소유권을 판단하지 않고 `PET_NOT_FOUND`를 반환한다.
- `petId`가 다른 사용자 소유이면 삭제 여부와 무관하게 `PET_FORBIDDEN`을 반환한다.
- `petId`가 인증 사용자 소유이지만 soft deleted이면 `PET_NOT_FOUND_OR_DELETED`를 반환한다.
- `expenseId`가 요청 `petId`에 속하지 않으면 존재 여부 노출을 피하기 위해 `WALLET_EXPENSE_NOT_FOUND`를 반환한다.
- `INVALID_CURSOR` 테스트는 base64url이 아니거나, 디코딩은 되지만 정렬 키가 없거나, 날짜/시간/id 파싱에 실패하는 값을 포함한다.
- `INVALID_INPUT` 테스트는 body JSON 파싱 오류, body 타입 불일치, 날짜 형식 오류, limit 타입 오류, limit 범위 오류, 지원하지 않는 `currency`/`category`를 포함한다.
- `VALIDATION_FAILED` 테스트는 request body의 필수값 누락, 숫자 범위, 문자열 길이처럼 `fieldErrors`로 내려줄 수 있는 Bean Validation 오류를 대상으로 한다.

## 삭제 pet 정책 검증

- pet soft delete 후 `wallet_expenses` row는 DB에 남아 있어야 한다.
- 일반 지갑 목록/요약/합계 API는 삭제된 pet을 404로 처리한다.
- hard delete cascade는 migration/FK 동작 범위이며, 이 API 통합 테스트에서는 pet soft delete 정책만 검증한다.
- 통합 조회 API는 1차 범위에 없으므로 별도 테스트를 만들지 않는다.

## 이번 단계에서 결정하지 않는 것

- 실제 구현 코드
- 프론트 테스트
- 영수증/사진 첨부 테스트
- 통합 지갑 API 테스트
- dead code cleanup 테스트

## 다음 단계로 넘어갈 수 있는 조건

- [x] 1차 테스트 클래스명이 확정되어 있다.
- [x] 각 테스트의 API, request, expected response가 확정되어 있다.
- [x] 권한 실패와 validation 실패 테스트가 포함되어 있다.
- [x] 2차 기능 테스트가 보류로 분리되어 있다.
