# 11. 전체 검증 계획

> 상태: 검증 계획 확정, 최근 cleanup 검증 반영
> 기준 문서: `08_BACKEND_IMPLEMENTATION_TASKS.md`, `09_FRONTEND_INTEGRATION_PLAN.md`, `10_DEAD_CODE_CLEANUP_PLAN.md`  
> 선행 단계: `08_BACKEND_IMPLEMENTATION_TASKS.md`, `09_FRONTEND_INTEGRATION_PLAN.md`, `10_DEAD_CODE_CLEANUP_PLAN.md`  
> 다음 단계: 완료 보고 또는 Handover 갱신  
> 변경 가능 여부: 실제 구현 결과와 환경 제약에 따라 가능

## 목적

지갑 지출 1차 백엔드 구현, Flutter 지갑 API 전환, 레거시 지갑 cleanup 판단 뒤 같은 기준으로 최종 검증한다. 이 문서는 구현자가 마지막에 어떤 명령을 어떤 순서로 실행하고, 실패를 어떻게 분류하며, 최종 보고에 무엇을 남겨야 하는지 고정한다.

## 적용 범위

- 백엔드: `wallet_expenses` migration, `init-test.sql`, `WalletExpenseIntegrationTest`, wallet controller/service/dto/error 처리.
- 프론트: `WalletExpense` 모델/service/provider, wallet add/detail/edit/list/report 화면, router `expenseId`, `ApiException.errorCode`.
- cleanup: `/records/expense/new` redirect 제거, `ActivityRecord.typeId == "expense"` 지갑 의존 제거, `expense_record_utils.dart` rename/delete 완료, 제거된 기록 타입은 과거 migration 검증만 유지.
- 문서: `docs/FRONTEND_STATUS.md`, roadmap 문서, Handover.

## 검증 순서

최종 검증은 아래 순서로 실행한다. 앞 단계가 컴파일 오류나 명확한 assertion 실패로 깨지면 다음 단계로 넘어가지 않고 원인을 수정한다.

1. 백엔드 선택 통합 테스트
2. 백엔드 전체 테스트
3. 프론트 선택 테스트
4. 프론트 전체 테스트, analyze, build
5. cleanup 역참조 검색
6. 문서/whitespace/변경 범위 확인

## 1. 백엔드 선택 검증

08번 구현이 끝난 직후 가장 먼저 wallet 통합 테스트만 실행한다.

```powershell
cd backend
.\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest --info
```

기대 결과:

- `createExpenseSucceeds`
- `createExpenseAllowsNullItemName`
- `updateExpenseClearsNullableFields`
- `deleteExpenseReturnsNoContentAndRemovesFromList`
- `listExpensesUsesCursorWithoutDuplicates`
- `summaryReturnsTotalAndCategoryBreakdown`
- `summaryReturnsEmptySummary`
- pet ownership, soft delete, cursor, date range, validation, JSON parse, category/currency 오류 테스트가 모두 통과한다.

실패 분류:

| 실패 | 분류 | 처리 |
|------|------|------|
| 컴파일 실패 | 코드 실패 | 누락 class/import/signature를 수정한다. |
| HTTP status/body/errorCode 불일치 | 계약 실패 | 04/06/07/08 중 어느 문서와 어긋났는지 확인하고 코드 또는 문서를 먼저 맞춘다. |
| Testcontainers/Docker 초기화 실패 | 환경 실패 후보 | Docker 상태와 동일 테스트 재시도 조건을 최종 보고에 남긴다. |

## 2. 백엔드 전체 검증

선택 통합 테스트가 통과한 뒤 백엔드 전체 회귀를 실행한다.

```powershell
cd backend
.\gradlew.bat test
```

기대 결과:

- 기존 record, pet, routine, community, auth 테스트가 지갑 변경 때문에 깨지지 않는다.
- 기존 Flyway migration은 수정되지 않았고 신규 migration 번호는 실제 마지막 번호 다음이다.
- 테스트 profile의 `init-test.sql`이 wallet DDL과 동작 옵션을 반영한다.

추가 확인:

```powershell
cd ..
git status --short backend/src/main/resources/db/migration backend/src/test/resources/init-test.sql
git diff -- backend/src/main/resources/db/migration
git diff -- backend/src/test/resources/init-test.sql
```

기대 결과:

- 기존 `V1`~`V15` 파일의 diff가 없다.
- `git status --short`에서 신규 migration은 `?? backend/src/main/resources/db/migration/V16__create_wallet_expenses.sql`로 보이고, 기존 migration 수정은 없다.
- `init-test.sql`에는 `created_at DEFAULT CURRENT_TIMESTAMP(6)`와 `updated_at DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)` 동작 옵션이 운영 migration과 일치한다.

## 3. 프론트 선택 검증

09번 전환이 끝난 뒤 wallet 관련 테스트를 좁게 실행한다.

```powershell
cd frontend
flutter test test/core/api_client_test.dart
flutter test test/services/wallet_expense_service_test.dart
flutter test test/providers/wallet_expense_provider_test.dart
flutter test test/screens/wallet/expense_add_screen_test.dart
flutter test test/screens/wallet/expense_wallet_screen_test.dart
flutter test test/router/app_router_test.dart
```

기대 결과:

- `ApiException.errorCode`가 `ProblemDetail.errorCode`를 보존한다.
- wallet service가 wrapper `data`를 풀고 list/detail/create/update/delete/summary endpoint를 호출한다.
- provider가 create/update/delete 후 wallet state와 summary를 갱신한다.
- add/edit/delete 화면은 `PetNotifier.addRecord/updateRecord/deleteRecord`가 아니라 wallet provider를 호출한다.
- wallet/report 화면은 `ActivityRecord` fixture 없이 렌더링된다.
- router는 `/wallet/expenses/:expenseId`와 `/wallet/expenses/:expenseId/edit`를 사용한다.
- `/records/expense/new` legacy redirect는 제거됐고, 지갑 생성은 `/wallet/expenses/new` 직접 진입만 유지한다.

## 4. 프론트 전체 검증

선택 테스트가 통과한 뒤 전체 프론트 검증을 실행한다.

```powershell
cd frontend
flutter test
flutter analyze --no-fatal-infos
flutter build web
```

기대 결과:

- 전체 widget/provider/router 테스트가 통과한다.
- analyze는 error/warning 없이 종료한다. 기존 info가 있으면 최종 보고에 기존 항목이라고 구분한다.
- web build가 성공한다. `flutter_secure_storage_web` wasm dry-run 경고처럼 기존 환경성 경고는 별도로 기록한다.

## 5. Cleanup 검증

10번 cleanup 판단을 수행한 뒤 지갑 레거시 역참조 검색을 실행한다.

```powershell
cd frontend
rg -n 'records/expense|/wallet/expenses/:recordId|recordId' lib test
rg -n 'typeId == [''"]expense|typeId: [''"]expense|ActivityRecord\(' lib/screens/wallet test/screens/wallet
rg -n 'toRecordBody\(|addRecord\(|updateRecord\(|deleteRecord\(' lib/screens/wallet test/screens/wallet
rg -n 'expense_record_utils|expenseRecords\(|totalExpenseLabel\(|expenseTitle\(' lib test
```

기대 결과:

- 지갑 화면과 지갑 테스트에는 `ActivityRecord(typeId: 'expense')` fixture가 남지 않는다.
- `ExpenseFormData.toRecordBody()`가 지갑 저장/수정 경로에서 호출되지 않는다.
- `/wallet/expenses/:recordId` route가 남지 않는다.
- `/records/expense/new`는 호환용으로 유지하지 않는다. router 테스트도 redirect 기대를 제거한 상태를 기준으로 한다.
- `bath`/`groom` quick/detail 잔재는 제거 완료 상태다. 관련 검색 결과가 남으면 wallet/care schedule의 `grooming`처럼 다른 도메인 값인지 먼저 구분한다.

검색 결과가 남아도 되는 경우:

| 결과 | 허용 여부 |
|------|-----------|
| 일반 기록 도메인의 `ActivityRecord` | 허용 |
| 일반 기록 route의 `recordId` | 허용 |
| 지갑과 무관한 `grooming`, 병원 방문 사유 `checkup` | 기록 타입이 아닌 다른 도메인 값이므로 허용 |
| `docs/backend-roadmap`의 과거 상태 설명 | 구현 완료 뒤 현재 상태 문서라면 정리, 역사 설명이면 허용 |

## 6. 문서 검증

프론트 전환 또는 cleanup 뒤 `docs/FRONTEND_STATUS.md`를 갱신했으면 문서 검증을 실행한다.

```powershell
cd ..
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
git diff --check -- docs\FRONTEND_STATUS.md docs\CONTEXT.md docs\backend-roadmap
```

기대 결과:

- 한글 mojibake findings가 0건이다.
- whitespace 오류가 없다.
- `docs/FRONTEND_STATUS.md`의 Wallet 상태가 실제 코드 연결 결과와 일치한다.

## 7. 최종 변경 범위 확인

마지막으로 변경 범위가 요청 범위 안에 있는지 확인한다.

```powershell
git status --short backend frontend docs scripts DESIGN.md
git diff --check
```

기대 결과:

- 백엔드 구현 단계에서는 `backend/`, 관련 `docs/`만 변경된다.
- 프론트 전환 단계에서는 `frontend/`, `docs/FRONTEND_STATUS.md`, 관련 roadmap 문서만 변경된다.
- cleanup 단계에서는 지갑 전환과 직접 관련된 frontend/docs 파일만 변경된다.
- `DESIGN.md`는 UI 디자인 규칙 변경이 실제로 필요할 때만 변경된다.
- 기존 dirty 변경은 되돌리지 않는다.

## 최종 보고 형식

완료 보고에는 아래 항목을 포함한다.

```text
완료:
- 백엔드 wallet expense API 구현/검증
- 프론트 wallet API 전환
- 레거시 지갑 cleanup

검증:
- cd backend; .\gradlew.bat test --tests com.petyilgi.wallet.WalletExpenseIntegrationTest
- cd backend; .\gradlew.bat test
- cd frontend; flutter test ...
- cd frontend; flutter test
- cd frontend; flutter analyze --no-fatal-infos
- cd frontend; flutter build web
- check-korean-mojibake.ps1
- git diff --check

남은 위험:
- 실행하지 못한 명령이 있으면 이유와 재시도 조건
- 환경 실패가 있으면 실패 명령과 핵심 오류
- cleanup 보류 후보
```

## 중단 기준

- 백엔드 선택 통합 테스트가 깨진 상태에서 프론트 전환을 시작해야 하는 상황.
- 04번 API 계약과 실제 구현 응답이 달라졌는데 문서 수정 없이 프론트가 구현에 맞춰지는 상황.
- cleanup 검색에서 지갑 화면이 여전히 `ActivityRecord`를 필요로 하는 상황.
- 테스트 실패를 기대값 삭제나 검증 약화로 해결하려는 상황.
- 한글 깨짐 검사 실패 원인을 복구하지 못한 상황.

## 완료 조건

- [x] 백엔드 선택/전체 검증 명령이 확정되어 있다.
- [x] 프론트 선택/전체 검증 명령이 확정되어 있다.
- [x] cleanup 역참조 검색 명령과 허용/불허 기준이 확정되어 있다.
- [x] 문서, whitespace, 변경 범위 검증 명령이 확정되어 있다.
- [x] 최종 보고에 포함할 검증 결과와 남은 위험 형식이 정해져 있다.
