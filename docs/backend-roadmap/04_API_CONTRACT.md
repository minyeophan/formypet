# 04. API 계약

> 상태: 확정  
> 기준 문서: `02_DOMAIN_DECISIONS.md`, `03_TARGET_ERD.md`  
> 선행 단계: `02_DOMAIN_DECISIONS.md`, `03_TARGET_ERD.md`  
> 다음 단계: `05_MIGRATION_PLAN.md`, `06_BACKEND_IMPLEMENTATION_PLAN.md`, `07_BACKEND_TEST_PLAN.md`  
> 변경 가능 여부: 구현 직전 계약 오류 발견 시 가능

## 목적

선택된 도메인에 대해 프론트와 백엔드가 같은 endpoint, DTO 필드명, 응답 형태, 오류 상태를 쓰도록 계약을 작성한다. 이번 단계의 1차 상세 대상은 지갑 도메인의 지출 내역 API다.

## 입력 문서

- `docs/BACKEND_INVENTORY.md`
- `02_DOMAIN_DECISIONS.md`
- `03_TARGET_ERD.md`
- `docs/FRONTEND_STATUS.md`
- 현재 프론트 service/provider 호출 지점

## 전체 적용 기준

- 모든 endpoint는 `/api/v1/` prefix를 사용한다.
- 성공 응답은 기존 공통 `ApiResponse<T>` 형태를 따른다.
- 오류 응답은 기존 `ProblemDetail` 정책을 따른다.
- 오류 응답에는 앱 분기용 `errorCode` property를 포함한다.
- 소유권 검증은 controller가 아니라 service 계층에서 보장한다.
- request/response 필드명은 프론트 모델명과 충돌하지 않게 정한다.
- 페이지네이션이 필요한 목록은 커서 기반으로 한다. offset/page 방식은 쓰지 않는다.
- 날짜는 `YYYY-MM-DD`, 시간은 `HH:mm` 문자열을 사용한다.

## 1차 확정 도메인

| 도메인 | API 상태 | endpoint | request | response | 오류 기준 | 상태 |
|--------|----------|----------|---------|----------|-----------|------|
| 지갑 지출 | 신규 | `/api/v1/pets/{petId}/wallet/expenses` | `WalletExpenseCreateRequest`, `WalletExpenseUpdateRequest` | `WalletExpenseResponse`, `WalletExpenseListResponse`, `WalletExpenseSummaryResponse` | 아래 오류 기준 | 확정 |

## 지갑 API 경계

- 지갑 지출은 `activity_records`가 아니라 신규 `wallet_expenses` 테이블에 저장한다.
- `activity_records.type_id = 'expense'`는 새로 추가하지 않는다.
- 기존 프론트의 `/records/expense/new`는 `/wallet/expenses/new`로 redirect되는 레거시 진입점으로만 본다.
- 영수증/사진 첨부는 1차 범위에서 제외한다.
- 다둥이 통합 지갑은 1차 API에서 확정하지 않는다. 1차는 `petId` 하위의 반려동물별 지출만 다룬다.
- 삭제된 pet은 일반 지갑 API에서 없는 리소스처럼 처리한다.
- 삭제된 pet의 지출 row는 보존하되 일반 사용자 조회/요약/합계에는 포함하지 않는다.

## Endpoint

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/v1/pets/{petId}/wallet/expenses` | 특정 반려동물의 지출 생성 |
| GET | `/api/v1/pets/{petId}/wallet/expenses` | 특정 반려동물의 지출 목록 조회 |
| GET | `/api/v1/pets/{petId}/wallet/expenses/summary` | 특정 반려동물의 지출 합계와 카테고리 요약 조회 |
| GET | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | 특정 지출 단건 조회 |
| PUT | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | 특정 지출 전체 수정 |
| DELETE | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | 특정 지출 삭제 |

## 성공 응답 기준

| 메서드 | 경로 | HTTP | body |
|--------|------|------|------|
| POST | `/api/v1/pets/{petId}/wallet/expenses` | `201 Created` | `ApiResponse<WalletExpenseResponse>` |
| GET | `/api/v1/pets/{petId}/wallet/expenses` | `200 OK` | `ApiResponse<WalletExpenseListResponse>` |
| GET | `/api/v1/pets/{petId}/wallet/expenses/summary` | `200 OK` | `ApiResponse<WalletExpenseSummaryResponse>` |
| GET | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | `200 OK` | `ApiResponse<WalletExpenseResponse>` |
| PUT | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | `200 OK` | `ApiResponse<WalletExpenseResponse>` |
| DELETE | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | `204 No Content` | 없음 |

## Query

### 목록 조회

`GET /api/v1/pets/{petId}/wallet/expenses`

| query | 필수 | 형식 | 기본값 | 설명 |
|-------|------|------|--------|------|
| `cursor` | 아니오 | string | 없음 | 이전 응답의 `nextCursor` |
| `limit` | 아니오 | number | `20` | `1..50` |
| `from` | 아니오 | `YYYY-MM-DD` | 없음 | 시작일 포함 |
| `to` | 아니오 | `YYYY-MM-DD` | 없음 | 종료일 포함 |
| `category` | 아니오 | string | 없음 | 카테고리 단일 필터 |

정렬은 `expenseDate desc, expenseTime desc nulls last, id desc`로 고정한다. `expenseTime`이 `null`인 row는 같은 날짜 안에서 시간이 있는 row 뒤에 온다.

### 요약 조회

`GET /api/v1/pets/{petId}/wallet/expenses/summary`

| query | 필수 | 형식 | 기본값 | 설명 |
|-------|------|------|--------|------|
| `from` | 아니오 | `YYYY-MM-DD` | 없음 | 시작일 포함 |
| `to` | 아니오 | `YYYY-MM-DD` | 없음 | 종료일 포함 |
| `category` | 아니오 | string | 없음 | 카테고리 단일 필터 |

목록의 `limit`과 무관하게 조건에 맞는 전체 합계를 반환한다.

## DTO

이 섹션의 JSON 예시는 `ApiResponse.data`에 들어가는 DTO 본문이다. 실제 HTTP 응답은 삭제 API를 제외하고 모두 `{"data": ..., "message": "success"}` wrapper를 사용한다.

### WalletExpenseCreateRequest

```json
{
  "expenseDate": "2026-06-12",
  "expenseTime": "14:30",
  "amount": 35000,
  "currency": "KRW",
  "category": "hospital",
  "itemName": "정기 검진",
  "note": "예방접종 포함"
}
```

| 필드 | 필수 | 정책 |
|------|------|------|
| `expenseDate` | 예 | `YYYY-MM-DD` |
| `expenseTime` | 아니오 | `HH:mm`, 모르면 생략 또는 `null` |
| `amount` | 예 | 원 단위 정수, `1` 이상 |
| `currency` | 아니오 | 생략 시 `KRW`, 1차는 `KRW`만 허용 |
| `category` | 예 | 아래 카테고리 enum 중 하나 |
| `itemName` | 아니오 | trim 후 100자 이하, 빈 문자열은 `null` 처리 |
| `note` | 아니오 | trim 후 500자 이하, 빈 문자열은 `null` 처리 |

### WalletExpenseUpdateRequest

`PUT`은 전체 수정이다. 생성 요청과 같은 필드를 받으며 `expenseDate`, `amount`, `category`는 필수다. `itemName`과 `note`는 선택값이다.

```json
{
  "expenseDate": "2026-06-12",
  "expenseTime": null,
  "amount": 42000,
  "currency": "KRW",
  "category": "medicine",
  "itemName": null,
  "note": null
}
```

### WalletExpenseResponse

```json
{
  "id": 17,
  "petId": 3,
  "expenseDate": "2026-06-12",
  "expenseTime": "14:30",
  "amount": 35000,
  "currency": "KRW",
  "category": "hospital",
  "categoryLabel": "병원",
  "itemName": "정기 검진",
  "note": "예방접종 포함"
}
```

### WalletExpenseListResponse

```json
{
  "items": [
    {
      "id": 17,
      "petId": 3,
      "expenseDate": "2026-06-12",
      "expenseTime": "14:30",
      "amount": 35000,
      "currency": "KRW",
      "category": "hospital",
      "categoryLabel": "병원",
      "itemName": "정기 검진",
      "note": "예방접종 포함"
    }
  ],
  "nextCursor": "eyJkIjoiMjAyNi0wNi0xMiIsInQiOiIxNDozMCIsImlkIjoxN30",
  "hasMore": true
}
```

`nextCursor`는 서버가 생성한 opaque 문자열로 취급한다. 클라이언트는 파싱하거나 직접 생성하지 않고, 다음 요청의 `cursor` query에 그대로 전달한다.

빈 목록:

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false
}
```

### WalletExpenseSummaryResponse

```json
{
  "totalAmount": 92000,
  "count": 3,
  "currency": "KRW",
  "from": "2026-06-01",
  "to": "2026-06-30",
  "categories": [
    {
      "category": "hospital",
      "categoryLabel": "병원",
      "amount": 50000,
      "count": 1
    },
    {
      "category": "food",
      "categoryLabel": "사료",
      "amount": 42000,
      "count": 2
    }
  ]
}
```

`from`과 `to`는 요청 query가 없으면 `null`이다.

빈 요약:

```json
{
  "totalAmount": 0,
  "count": 0,
  "currency": "KRW",
  "from": null,
  "to": null,
  "categories": []
}
```

## 카테고리

1차 카테고리는 현재 프론트 지갑 UI 기준을 따른다.

| 값 | 표시 |
|----|------|
| `food` | 사료 |
| `snack` | 간식 |
| `hospital` | 병원 |
| `medicine` | 약 |
| `grooming` | 미용 |
| `supplies` | 용품 |
| `etc` | 기타 |

서버는 모르는 카테고리를 400 `INVALID_INPUT` 오류로 거절한다. 응답에는 `category` 코드와 `categoryLabel`을 함께 내려준다.

## 응답 래퍼

단건 생성/조회/수정:

```json
{
  "data": {
    "id": 17,
    "petId": 3,
    "expenseDate": "2026-06-12",
    "expenseTime": "14:30",
    "amount": 35000,
    "currency": "KRW",
    "category": "hospital",
    "categoryLabel": "병원",
    "itemName": "정기 검진",
    "note": "예방접종 포함"
  },
  "message": "success"
}
```

삭제 성공은 `204 No Content`이며 응답 body가 없다.

## 오류 기준

지갑 API의 404는 공통 `ApiException`의 하위 예외인 `NotFoundException`으로 처리한다. `GlobalExceptionHandler`는 `ApiException` 계열 예외를 `ProblemDetail`로 변환하고, `NotFoundException`은 status 404, type `https://petyilgi.com/errors/not-found`를 사용한다.

| 상황 | HTTP | type | detail 기준 |
|------|------|------|-------------|
| 인증 없음 또는 만료 | 401 | `https://petyilgi.com/errors/unauthorized` | 인증 실패 메시지 |
| 다른 사용자의 `petId` | 403 | `https://petyilgi.com/errors/forbidden` | 접근 권한 없음 |
| 존재하지 않는 `petId` | 404 | `https://petyilgi.com/errors/not-found` | 존재하지 않는 반려동물입니다. |
| 삭제된 `petId` | 404 | `https://petyilgi.com/errors/not-found` | 존재하지 않거나 삭제된 반려동물입니다. |
| 존재하지 않는 `expenseId` | 404 | `https://petyilgi.com/errors/not-found` | 지출 내역을 찾을 수 없습니다. |
| `expenseId`가 해당 `petId` 소속이 아님 | 404 | `https://petyilgi.com/errors/not-found` | 지출 내역을 찾을 수 없습니다. |
| request body JSON 파싱 오류 또는 타입 불일치 | 400 | `https://petyilgi.com/errors/invalid-input` | 요청 본문이 올바르지 않습니다. |
| request body Bean Validation 실패 | 400 | `https://petyilgi.com/errors/validation-failed` | `fieldErrors` 포함 |
| 허용되지 않은 `category` 또는 `currency` | 400 | `https://petyilgi.com/errors/invalid-input` | 입력값이 올바르지 않습니다. |
| 날짜 형식 오류 또는 `limit` 타입/범위 오류 | 400 | `https://petyilgi.com/errors/invalid-input` | 입력값이 올바르지 않습니다. |
| `from > to` | 400 | `https://petyilgi.com/errors/invalid-input` | 날짜 범위가 올바르지 않습니다. |
| 잘못된 `cursor` | 400 | `https://petyilgi.com/errors/invalid-input` | 커서가 올바르지 않습니다. |

다른 사용자의 리소스 존재 여부를 노출하지 않기 위해, `expenseId`가 요청 `petId`에 속하지 않는 경우는 404로 처리한다. `petId` 자체가 인증 사용자 소유가 아니면 403으로 처리한다.

### 오류 코드

`ProblemDetail`에는 `errorCode` property를 추가한다. 프론트는 사용자 분기나 로깅이 필요할 때 `errorCode`를 우선 사용한다.

| 상황 | errorCode |
|------|-----------|
| 인증 없음 또는 만료 | `UNAUTHORIZED` |
| 다른 사용자의 `petId` | `PET_FORBIDDEN` |
| 존재하지 않는 `petId` | `PET_NOT_FOUND` |
| 삭제된 `petId` | `PET_NOT_FOUND_OR_DELETED` |
| 존재하지 않는 `expenseId` | `WALLET_EXPENSE_NOT_FOUND` |
| `expenseId`가 해당 `petId` 소속이 아님 | `WALLET_EXPENSE_NOT_FOUND` |
| request body JSON 파싱 오류 또는 타입 불일치 | `INVALID_INPUT` |
| Bean Validation 실패 | `VALIDATION_FAILED` |
| 허용되지 않은 `category` 또는 `currency` | `INVALID_INPUT` |
| 날짜 형식 오류 또는 `limit` 타입/범위 오류 | `INVALID_INPUT` |
| `from > to` | `INVALID_DATE_RANGE` |
| 잘못된 `cursor` | `INVALID_CURSOR` |

삭제된 pet 예시:

```json
{
  "type": "https://petyilgi.com/errors/not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "존재하지 않거나 삭제된 반려동물입니다.",
  "errorCode": "PET_NOT_FOUND_OR_DELETED"
}
```

## 검증 규칙

| 필드 | 규칙 |
|------|------|
| `expenseDate` | 필수, ISO date, 미래 날짜 허용 여부는 프론트와 동일하게 허용 |
| `expenseTime` | 선택, `HH:mm`, `00:00..23:59` |
| `amount` | 필수, 정수, `1..999999999`. DTO Bean Validation으로 검증하며 실패 시 `VALIDATION_FAILED` |
| `currency` | 선택, `KRW`만 허용 |
| `category` | 필수, 허용 enum만 |
| `itemName` | 선택, trim 후 100자 이하 |
| `note` | 선택, trim 후 500자 이하 |
| `limit` | 선택, `1..50` |
| `cursor` | 선택, 서버가 발급한 base64url payload 형식이 아니거나 정렬 키를 파싱할 수 없으면 400 |

## 프론트 전환 요구

- 지갑 저장/수정/삭제는 `RecordService`가 아니라 신규 지갑 service에서 호출한다.
- `/wallet`과 `/wallet/report`는 `ActivityRecord.typeId == "expense"` 필터를 사용하지 않는다.
- `/wallet/expenses/{expenseId}`와 edit route의 path parameter 이름은 프론트 내부에서 `recordId`가 아니라 `expenseId`로 바꾼다.
- `itemName`이 없으면 화면 제목은 `itemName -> note -> 지출 기록` 순서로 fallback한다.
- `/records/expense/new` redirect는 10번 cleanup 단계에서 제거 여부를 결정한다.
- 영수증 사진 버튼은 1차 API에 연결하지 않는다.

## 이번 단계에서 결정하지 않는 것

- Flyway 파일 번호
- Java 구현 클래스명
- 테스트 구현 코드
- 프론트 화면 레이아웃
- 죽은 코드 삭제 목록
- 다둥이 통합 지갑 API
- 영수증/사진 첨부 API

## 금지

- 2번에서 보류한 도메인의 API를 확정하지 않는다.
- 현재 프론트 route가 있다는 이유만으로 백엔드 API를 확정하지 않는다.
- request/response 예시 없이 테스트 계획으로 넘기지 않는다.
- 지갑 지출을 `activity_records` 또는 `record_*` 테이블에 저장하지 않는다.
- `activity_types`에 `expense`를 추가하지 않는다.

## 다음 단계로 넘길 수 있는 조건

- [x] 선택된 도메인의 endpoint가 모두 확정되어 있다.
- [x] request/response 필드명이 확정되어 있다.
- [x] 401, 403, 404, validation/input 오류 기준이 정리되어 있다.
- [x] 7번 테스트 계획이 그대로 참조할 예시 payload가 있다.
