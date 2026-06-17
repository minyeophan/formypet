# 09. 프론트 연결 계획

> 상태: 확정 초안  
> 기준 문서: `04_API_CONTRACT.md`, `08_BACKEND_IMPLEMENTATION_TASKS.md`, `docs/FRONTEND_STATUS.md`  
> 선행 단계: `08_BACKEND_IMPLEMENTATION_TASKS.md` 백엔드 구현과 검증 통과  
> 다음 단계: `10_DEAD_CODE_CLEANUP_PLAN.md`  
> 변경 가능 여부: 백엔드 API 구현 결과가 4번 계약과 달라지면 4번 문서를 먼저 고친 뒤 수정 가능

## 목적

백엔드 지갑 지출 API가 검증된 뒤 Flutter 지갑 화면을 `ActivityRecord.typeId == "expense"` 기반 임시 흐름에서 신규 `/api/v1/pets/{petId}/wallet/expenses` API 기반 흐름으로 전환한다. 1차 범위는 반려동물별 지출 생성, 목록, 요약, 단건, 수정, 삭제 연결이며 영수증 사진, 다둥이 통합 지갑, 레거시 route 제거는 제외한다.

## 시작 조건

- `08_BACKEND_IMPLEMENTATION_TASKS.md`의 백엔드 wallet 통합 테스트가 통과했다.
- 백엔드 전체 테스트 또는 실패 원인 분리가 완료됐다.
- 4번 API 계약의 endpoint, DTO, errorCode가 구현과 일치한다.
- 프론트 연결 전에는 `DESIGN.md`를 다시 확인한다. 이번 계획은 기존 지갑 UI 구조를 유지하므로 신규 디자인 패턴을 만들지 않는다.

## 현재 프론트 상태

| 영역 | 현재 상태 | 전환 필요 |
|------|-----------|-----------|
| route | `/wallet`, `/wallet/report`, `/wallet/expenses/new`, `/wallet/expenses/:recordId`, `/wallet/expenses/:recordId/edit` 존재 | `recordId` parameter를 `expenseId`로 변경 |
| 저장 | `ExpenseAddScreen`이 `PetNotifier.addRecord(data.toRecordBody())` 호출 | 신규 wallet service/provider의 `createExpense` 호출 |
| 수정 | `ExpenseEditScreen`이 `PetNotifier.updateRecord()` 호출 | 신규 wallet service/provider의 `updateExpense` 호출 |
| 삭제 | `ExpenseDetailScreen`이 `PetNotifier.deleteRecord()` 호출 | 신규 wallet service/provider의 `deleteExpense` 호출 |
| 목록/요약 | `petProvider.records`에서 `typeId == "expense"` 필터 | `WalletExpenseListResponse`, `WalletExpenseSummaryResponse` 사용 |
| 모델 | `ActivityRecord.detail.amount/category/itemName`, `note` | `WalletExpense` 전용 모델 |
| 오류 | `ApiException`에 `errorCode` 없음 | `ProblemDetail.errorCode` 파싱 추가 |

## 파일 계획

### 생성

| 파일 | 책임 |
|------|------|
| `frontend/lib/models/wallet_expense.dart` | `WalletExpense`, `WalletExpenseList`, `WalletExpenseSummary`, `WalletExpenseCategorySummary` 모델 |
| `frontend/lib/services/wallet_expense_service.dart` | 지갑 지출 API 호출 |
| `frontend/lib/providers/wallet_expense_provider.dart` | active pet 기준 지갑 목록/요약/CRUD 상태 관리 |
| `frontend/test/services/wallet_expense_service_test.dart` | request/response 파싱 단위 테스트 |
| `frontend/test/providers/wallet_expense_provider_test.dart` | provider CRUD와 상태 갱신 테스트 |

### 수정

| 파일 | 책임 |
|------|------|
| `frontend/lib/core/api_client.dart` | `ApiException.errorCode` 파싱 추가 |
| `frontend/lib/router/app_router.dart` | 지갑 route path parameter를 `expenseId`로 변경 |
| `frontend/lib/screens/wallet/expense_record_utils.dart` | `ActivityRecord` helper를 `WalletExpense` helper로 전환하거나 파일명을 후속 정리 대상으로 표시 |
| `frontend/lib/screens/wallet/expense_form.dart` | `WalletExpenseCreateRequest`/`WalletExpenseUpdateRequest` body 생성 |
| `frontend/lib/screens/wallet/expense_add_screen.dart` | 신규 provider create 호출 |
| `frontend/lib/screens/wallet/expense_wallet_screen.dart` | 신규 provider 목록/요약 사용 |
| `frontend/lib/screens/wallet/expense_report_screen.dart` | 신규 provider 요약과 목록 사용 |
| `frontend/lib/screens/wallet/expense_detail_screen.dart` | 신규 provider 단건/삭제 사용, `expenseId` 사용 |
| `frontend/lib/screens/wallet/expense_edit_screen.dart` | 신규 provider 단건/수정 사용, `expenseId` 사용 |
| `frontend/test/screens/wallet/expense_add_screen_test.dart` | `addRecord/updateRecord/deleteRecord` 기대 제거, wallet provider 기대 추가 |
| `frontend/test/screens/wallet/expense_wallet_screen_test.dart` | `ActivityRecord` fixture 제거, `WalletExpense` fixture 사용 |
| `frontend/test/router/app_router_test.dart` | route parameter 이름과 legacy redirect 기대 갱신 |
| `docs/FRONTEND_STATUS.md` | 지갑 저장/조회가 API 연동됨으로 바뀐 뒤 상태 갱신 |

### 수정하지 않음

- `backend/`
- `backend/src/main/resources/db/migration/`
- `DESIGN.md`
- `/records/expense/new` redirect 제거
- 영수증 사진 UI/API 연결

## 모델 계약

`frontend/lib/models/wallet_expense.dart`는 4번 API 계약의 response 이름을 그대로 따른다.

| 모델 | 필드 |
|------|------|
| `WalletExpense` | `id`, `petId`, `expenseDate`, `expenseTime`, `amount`, `currency`, `category`, `categoryLabel`, `itemName`, `note` |
| `WalletExpenseList` | `items`, `nextCursor`, `hasMore` |
| `WalletExpenseSummary` | `totalAmount`, `count`, `currency`, `from`, `to`, `categories` |
| `WalletExpenseCategorySummary` | `category`, `categoryLabel`, `amount`, `count` |

프론트 내부 id는 기존 모델 관례처럼 `String`으로 둔다. 백엔드 Long 값은 `toString()`으로 변환한다.

요청 body는 아래 키만 보낸다.

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

`itemName`과 `note`가 빈 문자열이면 `null`로 보내거나 키를 생략한다. PUT에서 사용자가 명시적으로 지운 경우에는 `null`을 보내 실제 값이 지워지게 한다.

## 구현 순서

### 1. API errorCode 파싱

- [ ] `frontend/test/core/api_client_test.dart` 또는 기존 API client 테스트에 `ProblemDetail.errorCode` 파싱 실패 테스트를 먼저 추가한다.
- [ ] `frontend/lib/core/api_client.dart`의 `ApiException`에 `String? errorCode`를 추가한다.
- [ ] `_parseError`에서 `data['errorCode']?.toString()`을 읽는다.
- [ ] 기존 `statusCode`, `title`, `detail`, `fieldErrors` 동작은 유지한다.
- [ ] wallet 화면에서는 1차로 공통 inline 오류 문구를 유지하고, `PET_NOT_FOUND_OR_DELETED`와 `WALLET_EXPENSE_NOT_FOUND`만 빈/없음 상태 분기에 사용한다.

검증:

```powershell
cd frontend
flutter test test/core/api_client_test.dart
```

예상 결과: `ApiException.errorCode`가 아직 없어서 실패한 뒤, 구현 후 `ProblemDetail.errorCode`가 예외 객체에 보존된다.

### 2. WalletExpense 모델과 service 작성

- [ ] `WalletExpense.fromJson`은 `id`, `petId`를 문자열로 변환한다.
- [ ] `expenseTime`, `itemName`, `note`, `nextCursor`, `from`, `to`는 nullable로 둔다.
- [ ] `WalletExpenseService.listExpenses(petId, {cursor, limit, from, to, category})`는 `GET /api/v1/pets/{petId}/wallet/expenses`를 호출한다.
- [ ] `WalletExpenseService.getExpense(petId, expenseId)`는 단건 endpoint를 호출한다.
- [ ] `WalletExpenseService.createExpense(petId, body)`는 POST를 호출한다.
- [ ] `WalletExpenseService.updateExpense(petId, expenseId, body)`는 PUT을 호출한다.
- [ ] `WalletExpenseService.deleteExpense(petId, expenseId)`는 DELETE를 호출하고 body를 기대하지 않는다.
- [ ] `WalletExpenseService.getSummary(petId, {from, to, category})`는 summary endpoint를 호출한다.

검증:

```powershell
cd frontend
flutter test test/services/wallet_expense_service_test.dart
```

예상 결과: service가 wrapper `data`를 풀고 DTO를 정확히 파싱한다.

### 3. Wallet provider 분리

- [ ] `walletExpenseServiceProvider`를 만든다.
- [ ] `walletExpenseProvider`는 active pet id를 직접 보관하지 않고, screen에서 현재 active pet id를 전달해 load/create/update/delete를 호출하는 형태로 둔다.
- [ ] state에는 `isLoading`, `isMutating`, `items`, `summary`, `nextCursor`, `hasMore`, `errorText`를 둔다.
- [ ] `loadFirstPage(petId)`는 목록과 요약을 함께 조회한다.
- [ ] `loadMore(petId)`는 `nextCursor`가 있을 때만 다음 페이지를 붙인다.
- [ ] `createExpense(petId, data)` 성공 후 새 지출을 목록 앞에 반영하거나 `loadFirstPage(petId)`를 재호출한다.
- [ ] `updateExpense(petId, expenseId, data)` 성공 후 목록의 해당 항목을 교체한다.
- [ ] `deleteExpense(petId, expenseId)` 성공 후 목록에서 제거하고 summary를 재조회한다.
- [ ] active pet이 바뀌면 지갑 화면 진입 시 `loadFirstPage(newPetId)`를 다시 호출한다.

검증:

```powershell
cd frontend
flutter test test/providers/wallet_expense_provider_test.dart
```

예상 결과: create/update/delete 후 provider state가 wallet 모델 기준으로 갱신된다.

### 4. Form body 전환

- [ ] `ExpenseFormData.toRecordBody()`를 더 이상 저장 경로에서 사용하지 않는다.
- [ ] `ExpenseFormData.toWalletExpenseBody({bool includeNulls = false})`를 추가하거나 동등한 mapper를 만든다.
- [ ] 생성 요청은 `expenseDate`, `expenseTime`, `amount`, `currency: KRW`, `category`, `itemName`, `note`를 보낸다.
- [ ] 수정 요청은 전체 수정이므로 `itemName`, `note`가 비어 있으면 `null`을 보낸다.
- [ ] 기존 날짜/시간/금액/카테고리 입력 UI는 유지한다.
- [ ] 영수증, 사진, 항목 추가 버튼은 1차 범위에 추가하지 않는다.

검증:

```powershell
cd frontend
flutter test test/screens/wallet/expense_add_screen_test.dart
```

예상 결과: 저장 payload에 `typeId`, `detail`, `ActivityRecord` 전용 키가 없다.

### 5. Add/Edit/Delete 연결

- [ ] `ExpenseAddScreen`은 active pet이 없으면 기존 안내를 유지한다.
- [ ] active pet이 있으면 `walletExpenseProvider.createExpense(activePet.id, body)`를 호출한다.
- [ ] 생성 성공 후 `/wallet`로 이동한다.
- [ ] `ExpenseEditScreen`은 `recordId`가 아니라 `expenseId`를 받는다.
- [ ] 수정 화면은 provider 또는 service로 단건을 조회해 초기값을 채운다.
- [ ] 수정 성공 후 `/wallet/expenses/{expenseId}`로 이동한다.
- [ ] `ExpenseDetailScreen`은 `expenseId`로 단건을 조회한다.
- [ ] 삭제 성공은 `204 No Content` 기준으로 처리하고 `/wallet`로 이동한다.

검증:

```powershell
cd frontend
flutter test test/screens/wallet/expense_add_screen_test.dart
```

예상 결과: add/edit/delete 테스트가 wallet provider 호출을 검증한다.

### 6. Wallet 목록과 report 전환

- [ ] `ExpenseWalletScreen`은 `petProvider.records`를 읽지 않는다.
- [ ] 화면 진입 시 active pet 기준으로 wallet 목록과 summary를 불러온다.
- [ ] 최근 지출은 `WalletExpenseList.items.take(3)`를 사용한다.
- [ ] 누적 지출과 건수는 summary를 우선 사용한다.
- [ ] `ExpenseReportScreen`은 summary의 `categories`를 사용한다.
- [ ] report의 지출 내역은 wallet 목록을 사용한다.
- [ ] 빈 목록은 기존 문구 `아직 지출 기록이 없어요`를 유지한다.
- [ ] `itemName`이 없으면 `itemName -> note -> 지출 기록` 순서로 제목을 표시한다.

검증:

```powershell
cd frontend
flutter test test/screens/wallet/expense_wallet_screen_test.dart
```

예상 결과: wallet/report 화면이 `ActivityRecord` fixture 없이 렌더링된다.

### 7. Route parameter 정리

- [ ] `app_router.dart`에서 `/wallet/expenses/:recordId`를 `/wallet/expenses/:expenseId`로 바꾼다.
- [ ] edit route도 `/wallet/expenses/:expenseId/edit`로 바꾼다.
- [ ] `ExpenseDetailScreen` 생성자 parameter를 `expenseId`로 바꾼다.
- [ ] `ExpenseEditScreen` 생성자 parameter를 `expenseId`로 바꾼다.
- [ ] `/records/expense/new -> /wallet/expenses/new` redirect는 유지한다.
- [ ] `/records/expense/new` 제거 여부는 10번 cleanup에서 결정한다.

검증:

```powershell
cd frontend
flutter test test/router/app_router_test.dart
```

예상 결과: wallet CRUD route가 `expenseId` 기준으로 열리고 legacy redirect는 유지된다.

### 8. FRONTEND_STATUS 갱신

- [ ] `docs/FRONTEND_STATUS.md`의 Wallet 상태를 실제 연결 결과로 갱신한다.
- [ ] 지갑 저장/수정/삭제가 연결되면 `🔌 연동됨`으로 바꾼다.
- [ ] 영수증 사진, 비용 항목 추가, 다둥이 통합 지갑은 계속 1차 제외 또는 부분 구현으로 둔다.
- [ ] 기존 `ActivityRecord.typeId == "expense"` 기반 설명을 제거한다.

검증:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
git diff --check -- docs\FRONTEND_STATUS.md
```

예상 결과: 문서 한글과 whitespace 오류가 없다.

### 9. 최종 프론트 검증

- [ ] wallet 관련 widget/provider/service/router 테스트를 실행한다.
- [ ] 프론트 전체 테스트를 실행한다.
- [ ] 정적 분석을 실행한다.
- [ ] 한글 깨짐 검사를 실행한다.
- [ ] 변경 범위를 확인한다.

검증 명령:

```powershell
cd frontend
flutter test test/services/wallet_expense_service_test.dart test/providers/wallet_expense_provider_test.dart test/screens/wallet/expense_add_screen_test.dart test/screens/wallet/expense_wallet_screen_test.dart test/router/app_router_test.dart
flutter test
flutter analyze --no-fatal-infos
cd ..
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
git diff --check
git status --short frontend docs scripts
```

## 구현 중 중단 기준

- 백엔드 4번 계약과 실제 응답 필드가 다르면 프론트 코드를 맞추기 전에 4번 문서를 먼저 고친다.
- 기존 `RecordService`나 `PetNotifier.records`를 지갑 저장/조회에 계속 쓰게 되면 중단하고 provider 분리부터 다시 한다.
- 영수증 사진이나 다둥이 통합 지갑 요구가 나오면 1차 범위 밖으로 분리한다.
- `/records/expense/new` redirect를 제거해야 할 것처럼 보이면 10번 cleanup 전에는 제거하지 않는다.

## 10번 지갑 cleanup으로 넘길 후보

| 후보 | 조건 |
|------|------|
| `/records/expense/new` redirect | 새 `/wallet/expenses/new` 흐름이 실제 저장까지 검증된 뒤 제거 여부 판단 |
| `ExpenseFormData.toRecordBody()` | 저장/수정 경로에서 더 이상 사용하지 않으면 제거 |
| `expense_record_utils.dart` 이름 | `ActivityRecord` 의존이 사라진 뒤 `wallet_expense_utils.dart`로 rename 검토 |
| wallet 테스트의 `ActivityRecord(typeId: expense)` fixture | 신규 `WalletExpense` fixture로 대체 완료 후 제거 |

## 다음 단계로 넘길 수 있는 조건

- [x] 프론트에서 만들 파일과 수정할 파일이 구분되어 있다.
- [x] `ActivityRecord.typeId == "expense"` 제거 작업이 각 화면별로 분해되어 있다.
- [x] route parameter `recordId -> expenseId` 전환이 명시되어 있다.
- [x] API service, provider, screen, test, 문서 갱신 순서가 명시되어 있다.
- [x] 10번 지갑 cleanup으로 넘길 후보가 분리되어 있다.
