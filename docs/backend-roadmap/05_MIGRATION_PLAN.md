# 05. 마이그레이션 계획

> 상태: 확정 초안  
> 기준 문서: `03_TARGET_ERD.md`  
> 선행 단계: `03_TARGET_ERD.md`  
> 다음 단계: `06_BACKEND_IMPLEMENTATION_PLAN.md`, `08_BACKEND_IMPLEMENTATION_TASKS.md`  
> 변경 가능 여부: 실제 구현 직전 migration 번호 재확인 전까지 가능

## 목적

지갑 지출 1차 API를 위한 `wallet_expenses` 테이블 추가 계획을 고정한다. 기존 Flyway 파일은 수정하지 않고, 새 migration과 테스트 스키마만 추가한다.

## 입력 문서

- `03_TARGET_ERD.md`
- `backend/src/main/resources/db/migration/`
- `backend/src/test/resources/init-test.sql`

## 적용 원칙

- 기존 `V*.sql` 파일은 수정하지 않는다.
- 현재 마지막 migration은 `V15__allow_pet_birth_date_nullable.sql`이므로 신규 파일은 `V16__create_wallet_expenses.sql`로 추가한다.
- 테스트 프로필은 Flyway disabled, `init-test.sql` 기반이므로 `wallet_expenses` DDL을 `init-test.sql`에도 반영한다.
- 운영 데이터 이관은 없다. 1차 범위는 신규 테이블 생성이며 기존 `activity_records` 기반 지출 흔적은 옮기지 않는다.
- 삭제된 pet의 지출 row 보존은 soft delete 기준이다. pet soft delete 시 `wallet_expenses`에는 별도 soft delete flag를 전파하지 않고 row를 보존한다.
- 실제 pet row를 hard delete하면 FK의 `ON DELETE CASCADE` 정책에 따라 연결된 지출 row도 함께 삭제된다.
- 일반 조회/요약/합계에서는 `pets.is_deleted = false` 조인을 통해 soft deleted pet의 지출을 제외한다.

## 신규 Migration

| 파일 | 목적 | 대상 테이블 | 데이터 이관 | 테스트 스키마 반영 |
|------|------|-------------|-------------|--------------------|
| `V16__create_wallet_expenses.sql` | 반려동물별 지갑 지출 저장소 생성 | `wallet_expenses` | 없음 | 필요 |

## `wallet_expenses` DDL 기준

```sql
CREATE TABLE wallet_expenses (
    id           BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id      BIGINT NOT NULL,
    pet_id       BIGINT NOT NULL,
    expense_date DATE NOT NULL,
    expense_time TIME NULL,
    amount       BIGINT NOT NULL,
    currency     VARCHAR(3) NOT NULL DEFAULT 'KRW',
    category     VARCHAR(40) NOT NULL,
    item_name    VARCHAR(100) NULL,
    note         VARCHAR(500) NULL,
    created_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at   DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    CONSTRAINT fk_wallet_expense_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_wallet_expense_pet FOREIGN KEY (pet_id) REFERENCES pets (id) ON DELETE CASCADE,
    INDEX idx_wallet_expenses_pet_date (pet_id, expense_date, expense_time, id),
    INDEX idx_wallet_expenses_user_date (user_id, expense_date, expense_time, id),
    INDEX idx_wallet_expenses_pet_category_date (pet_id, category, expense_date, expense_time, id),
    INDEX idx_wallet_expenses_user_category_date (user_id, category, expense_date, expense_time, id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;
```

## 구현 시 주의

- `item_name`은 nullable이다. 빈 문자열은 애플리케이션 계층에서 `null`로 정규화한다.
- `amount`는 원 단위 정수이며 음수, 0, 소수 금액을 허용하지 않는다.
- `currency`는 1차 범위에서 `KRW`만 허용한다.
- `currency`와 `category`는 DB `ENUM`이나 `CHECK`로 묶지 않고 `VARCHAR`로 유지한다. 허용 값 검증은 서비스 계층에서 처리한다.
- `expense_time`은 선택값이다. 정렬은 `expense_date desc, expense_time desc nulls last, id desc`를 서비스/쿼리에서 보장한다.
- `activity_types`에 `expense`를 추가하지 않는다.
- `record_expense` 테이블을 만들지 않는다.
- 영수증/사진 연결 테이블은 1차 범위에서 만들지 않는다.

## 검증 조건

- `backend/src/main/resources/db/migration/`의 마지막 번호 다음으로 `V16__create_wallet_expenses.sql`이 추가되어 있다.
- `init-test.sql`에 동일한 `wallet_expenses` 테이블과 인덱스가 반영되어 있다.
- 기존 migration 파일은 변경되지 않았다.
- `wallet_expenses.item_name`은 `NULL` 허용이다.
- 인덱스에는 `expense_time`이 포함되어 있다.
- 운영 migration과 `init-test.sql`은 byte-for-byte로 같을 필요는 없지만, `created_at DEFAULT CURRENT_TIMESTAMP(6)`과 `updated_at DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)`처럼 동작에 영향을 주는 DDL 옵션은 동일하다.
- `currency`와 `category`는 `VARCHAR`이며, 허용 값은 DB 제약이 아니라 서비스 검증으로 제한한다.

## 이번 단계에서 결정하지 않는 것

- 운영 데이터 이관 SQL
- 영수증/사진 첨부 스키마
- 통합 지갑 전용 테이블
- 일정 도메인 테이블
- 기존 `activity_records` 지출 흔적 삭제

## 다음 단계로 넘어갈 수 있는 조건

- [x] 실제 migration 디렉터리 기준 다음 번호가 확인되어 있다.
- [x] 신규 SQL 파일명과 목적이 확정되어 있다.
- [x] `init-test.sql` 반영 범위가 확정되어 있다.
- [x] 데이터 이관이 1차 범위에 없다는 점이 명시되어 있다.
