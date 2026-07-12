# 10. 죽은 코드 제거 계획

> 상태: 대부분 정리 완료, legacy redirect 보류
> 기준 문서: `02_DOMAIN_DECISIONS.md`, `04_API_CONTRACT.md`, `09_FRONTEND_INTEGRATION_PLAN.md`  
> 선행 단계: `09_FRONTEND_INTEGRATION_PLAN.md` 완료 및 프론트 wallet API 전환 검증 통과  
> 다음 단계: `11_VERIFICATION_PLAN.md`  
> 변경 가능 여부: 대체 기능 연결 완료 뒤 실제 검색 결과에 따라 수정 가능

## 목적

지갑 지출이 신규 `/api/v1/pets/{petId}/wallet/expenses` API와 `WalletExpense` 모델로 전환된 뒤, 기록 도메인에 남은 지출 저장 흔적과 레거시 route를 안전하게 제거한다. 이 단계는 새 기능을 만들지 않고, 이미 대체된 코드의 사용처를 검색해 삭제 또는 보류를 판단한다.

## 현재 코드 대조: 2026-07-12

- wallet 화면과 테스트에서 `ActivityRecord(typeId: 'expense')`, `typeId == 'expense'`, `toRecordBody()`, `PetNotifier.addRecord/updateRecord/deleteRecord` 지갑 호출은 검색되지 않는다.
- wallet helper는 `wallet_expense_utils.dart` 이름을 사용하고, wallet 화면들이 해당 helper를 import한다.
- `/wallet/expenses/:expenseId`와 edit route는 `expenseId` 기준으로 존재한다.
- `/records/expense/new` redirect와 router 테스트 기대는 아직 남아 있다. 이 redirect는 현재 사용자 진입 호환용 legacy 경로로 보류한다.
- 따라서 지금 당장 삭제할 backend 항목은 없고, 프론트 cleanup은 UI 작업 재개 또는 legacy URL 제거 결정이 있을 때만 진행한다.

## 시작 조건

- 09번 프론트 전환이 끝나 있고 wallet service/provider/screen/router 테스트가 통과한다.
- `/wallet`, `/wallet/report`, `/wallet/expenses/new`, `/wallet/expenses/{expenseId}`, `/wallet/expenses/{expenseId}/edit`가 신규 wallet provider로 동작한다.
- 지출 저장/수정 payload에 `typeId`, `detail`, `ActivityRecord` 전용 키가 남아 있지 않다.
- `/records/expense/new`는 legacy redirect로만 남아 있으며 새 지출 저장 진입점으로 직접 쓰지 않는다.

## 입력 문서

- `02_DOMAIN_DECISIONS.md`
- `04_API_CONTRACT.md`
- `09_FRONTEND_INTEGRATION_PLAN.md`
- `docs/FRONTEND_STATUS.md`
- 실제 `rg` 검색 결과
- 관련 Flutter 테스트 결과

## 전체 적용 기준

- 대체 기능 연결 전에는 삭제하지 않는다.
- 사용처 검색 없이 파일이나 route를 삭제하지 않는다.
- 테스트를 삭제하거나 기대값을 약화해서 통과시키지 않는다.
- 지갑 지출과 무관한 `bath`, `groom`, `mock`, `준비중` 정리는 이번 단계에서 하지 않는다.
- backend migration, backend API, DB schema는 이 단계에서 수정하지 않는다.

## 제거 후보

| 후보 | 처리 | 조건 | 검증 |
|------|------|------|------|
| `/records/expense/new` route | 삭제 | `/wallet/expenses/new` 저장 경로가 검증되고 외부 링크/테스트가 redirect를 기대하지 않음 | router 테스트에서 `/records/expense/new` 기대 제거 |
| `ExpenseFormData.toRecordBody()` | 삭제 | add/edit 저장 경로가 `toWalletExpenseBody()` 또는 동등 mapper만 사용 | `rg "toRecordBody\\(" frontend/lib frontend/test` 결과가 지갑 외 기록 경로만 남거나 빈 결과 |
| `ActivityRecord.typeId == "expense"` 지갑 필터 | 삭제 | wallet/report가 `WalletExpense` 목록과 summary만 사용 | `rg "typeId == ['\\\"]expense" frontend/lib frontend/test` 빈 결과 |
| `expense_record_utils.dart` | rename 또는 삭제 | 내부 타입이 `WalletExpense`로 바뀌고 파일명만 레거시 의미를 가짐 | import 경로와 테스트 fixture가 `wallet_expense_utils.dart` 기준으로 통과 |
| wallet 테스트의 `ActivityRecord(typeId: 'expense')` fixture | 삭제 | `WalletExpense` fixture가 add/detail/list/report 테스트를 대체 | `rg "ActivityRecord\\(" frontend/test/screens/wallet` 빈 결과 |
| `PetNotifier.addRecord/updateRecord/deleteRecord` 지갑 호출 | 삭제 | wallet 화면이 `walletExpenseProvider`만 호출 | `rg "addRecord|updateRecord|deleteRecord" frontend/lib/screens/wallet frontend/test/screens/wallet` 빈 결과 |

## 보류 후보

| 후보 | 보류 이유 |
|------|----------|
| `ActivityRecord` 모델 자체 | 일반 기록 도메인에서 계속 사용한다. |
| `RecordService`와 `PetNotifier.records` | 일반 기록 목록/생성/수정/삭제에서 계속 사용한다. |
| `expenseCategoryOptions`와 표시 라벨 | `WalletExpense` helper로 이동하거나 이름만 바꿀 수 있으나, 카테고리 UI 자체는 유지한다. |
| 영수증 사진 관련 placeholder | 1차 지갑 API 범위 밖이다. 삭제하지 않고 미구현 상태를 유지한다. |
| 일정, 커뮤니티, 기타 기록의 `준비중`/mock | 지갑 지출 전환과 직접 관련이 없으므로 이번 cleanup 대상이 아니다. |

## 검색 명령

```powershell
rg -n 'records/expense|/wallet/expenses/:recordId|recordId' frontend/lib frontend/test
rg -n 'typeId == [''"]expense|typeId: [''"]expense|ActivityRecord\(' frontend/lib/screens/wallet frontend/test/screens/wallet
rg -n 'toRecordBody\(|addRecord\(|updateRecord\(|deleteRecord\(' frontend/lib/screens/wallet frontend/test/screens/wallet
rg -n 'expense_record_utils|expenseRecords\(|totalExpenseLabel\(|expenseTitle\(' frontend/lib frontend/test
```

## 작업 순서

### 1. Route cleanup

- [ ] `frontend/lib/router/app_router.dart`에서 `/records/expense/new` redirect를 제거한다.
- [ ] `frontend/test/router/app_router_test.dart`에서 legacy redirect 기대를 제거하고 `/wallet/expenses/new` 직접 진입 기대만 남긴다.
- [ ] `/wallet/expenses/:expenseId`와 `/wallet/expenses/:expenseId/edit` 기대가 유지되는지 확인한다.

검증:

```powershell
cd frontend
flutter test test/router/app_router_test.dart
```

### 2. Form legacy mapper cleanup

- [ ] `ExpenseFormData.toRecordBody()` 사용처를 검색한다.
- [ ] 지갑 저장/수정에서 더 이상 쓰지 않으면 method를 삭제한다.
- [ ] 테스트에서 `typeId`, `detail` payload 기대를 제거하고 wallet request body 기대만 남긴다.

검증:

```powershell
cd frontend
flutter test test/screens/wallet/expense_add_screen_test.dart
rg -n 'toRecordBody\(' lib test
```

### 3. Wallet ActivityRecord fixture cleanup

- [ ] wallet 화면 테스트의 `ActivityRecord(typeId: 'expense')` fixture를 `WalletExpense` fixture로 바꾼다.
- [ ] `ExpenseWalletScreen`, `ExpenseReportScreen`, `ExpenseDetailScreen`, `ExpenseEditScreen` 테스트가 `WalletExpense` 기준으로 기대값을 검증하게 한다.
- [ ] `PetNotifier.records` 기반 지갑 테스트 double을 제거한다.

검증:

```powershell
cd frontend
flutter test test/screens/wallet/expense_add_screen_test.dart test/screens/wallet/expense_wallet_screen_test.dart
rg -n 'ActivityRecord\(' test/screens/wallet
```

### 4. Helper rename/delete

- [ ] `expense_record_utils.dart`가 `ActivityRecord`를 더 이상 받지 않으면 `wallet_expense_utils.dart`로 rename한다.
- [ ] 함수 이름도 `expenseRecords`처럼 기록 모델을 암시하는 이름이면 `walletExpenseTitle`, `walletExpenseAmountLabel`처럼 지갑 모델 기준으로 바꾼다.
- [ ] import를 모두 새 파일명으로 바꾼다.

검증:

```powershell
cd frontend
flutter test test/screens/wallet/expense_add_screen_test.dart test/screens/wallet/expense_wallet_screen_test.dart
rg -n 'expense_record_utils|expenseRecords\(' lib test
```

### 5. FRONTEND_STATUS 정리

- [ ] `docs/FRONTEND_STATUS.md`의 Wallet 항목에서 `ActivityRecord.typeId == "expense"` 기반 설명을 제거한다.
- [ ] `/records/expense/new` redirect를 제거했다면 해당 legacy 진입점 설명도 제거한다.
- [ ] 영수증 사진, 다둥이 통합 지갑, 비용 항목 추가가 아직 범위 밖이면 별도 미구현/보류 항목으로 남긴다.

검증:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
git diff --check -- docs\FRONTEND_STATUS.md
```

## 최종 검증

```powershell
cd frontend
flutter test test/router/app_router_test.dart test/screens/wallet/expense_add_screen_test.dart test/screens/wallet/expense_wallet_screen_test.dart
flutter test
flutter analyze --no-fatal-infos
cd ..
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
git diff --check
git status --short frontend docs
```

## 중단 기준

- `/records/expense/new`를 제거하면 기존 외부 진입 또는 테스트가 깨지는데 대체 경로가 명확하지 않다.
- wallet 화면 중 하나라도 여전히 `ActivityRecord`에서만 필요한 값을 얻는다.
- `WalletExpense` API 전환이 완료되지 않아 `PetNotifier.records` fallback이 필요하다.
- cleanup 중 일반 기록 도메인의 `ActivityRecord` 동작까지 바꾸게 된다.

## 다음 단계로 넘길 수 있는 조건

- [x] 제거 후보별 검색어와 사용처 확인 방법이 명시되어 있다.
- [x] 삭제 후보와 보류 후보가 분리되어 있다.
- [x] route, mapper, helper, fixture cleanup 순서가 정해져 있다.
- [x] 제거 후 실행할 router, wallet 화면, 전체 프론트 검증 명령이 명시되어 있다.
- [x] 11번 최종 검증 계획으로 넘길 영향 범위가 정리되어 있다.
