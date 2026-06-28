# ERD — 펫일기 백엔드

> Mermaid.js 렌더링. GitHub / Notion에서 바로 확인 가능.  
> SRID 4326 (WGS84) 준수. 공간 컬럼은 `POINT` 타입으로 표기.

---

## 전체 ERD

```mermaid
erDiagram
    USERS {
        BIGINT id PK "AUTO_INCREMENT"
        VARCHAR(100) email UK "NOT NULL"
        VARCHAR(255) password_hash "NOT NULL"
        VARCHAR(50) nickname "NOT NULL"
        VARCHAR(20) registration_source "NOT NULL DEFAULT LOCAL"
        BIGINT profile_media_id FK "nullable"
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    OAUTH_ACCOUNTS {
        BIGINT id PK "AUTO_INCREMENT"
        BIGINT user_id FK "NOT NULL"
        VARCHAR(20) provider "NOT NULL e.g. KAKAO"
        VARCHAR(100) provider_user_id "NOT NULL"
        DATETIME created_at "NOT NULL"
    }

    PETS {
        BIGINT id PK
        BIGINT user_id FK "NOT NULL"
        VARCHAR(50) name "NOT NULL"
        VARCHAR(30) species "NOT NULL"
        DATE birth_date "NOT NULL"
        ENUM gender "male|female|NULL"
        DECIMAL weight "5,2"
        VARCHAR(20) animal_registration_number
        BOOLEAN neutered
        TEXT diseases
        TEXT special_notes
        VARCHAR(7) accent_color "NOT NULL"
        VARCHAR(7) bg_light "NOT NULL"
        BOOLEAN is_deleted "DEFAULT false"
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    ACTIVITY_TYPES {
        VARCHAR(30) id PK "meal|water|walk|..."
        VARCHAR(50) name "NOT NULL 표시명"
        VARCHAR(200) icon_url
        INT display_order "DEFAULT 0"
    }

    MEDIA_RESOURCES {
        BIGINT id PK "AUTO_INCREMENT"
        BIGINT user_id FK "NOT NULL — 직접 소유권 확인"
        BIGINT pet_id FK "nullable — 펫 프로필 사진"
        BIGINT record_id FK "nullable — 기록 첨부 사진"
        VARCHAR(500) storage_key "NOT NULL UNIQUE"
        VARCHAR(255) original_name "NOT NULL"
        VARCHAR(100) content_type "NOT NULL"
        VARCHAR(10) extension "NOT NULL"
        BIGINT file_size "NOT NULL bytes"
        ENUM status "STORED"
        VARCHAR(20) visibility "DEFAULT PRIVATE"
        DATETIME created_at "NOT NULL"
    }

    MEDIA_CLEANUP_QUEUE {
        BIGINT id PK "AUTO_INCREMENT"
        VARCHAR(500) storage_key UK "삭제 재시도 대상"
        DATETIME created_at "NOT NULL"
    }

    ACTIVITY_RECORDS {
        BIGINT id PK
        BIGINT pet_id FK "NOT NULL"
        VARCHAR(30) type_id FK "NOT NULL → ACTIVITY_TYPES"
        DATE date "NOT NULL"
        TIME time
        TEXT note
        BIGINT routine_id FK
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    RECORD_MEAL {
        BIGINT record_id PK FK
        ENUM food_type "dry|wet|treat|prescription|raw|freezeDried|other"
        ENUM feeding_method "hand|free|autoFeeder|other"
        DECIMAL served_amount "7,2"
        DECIMAL consumed_amount "7,2"
        DECIMAL consumed_percent "5,2"
        VARCHAR(100) brand
        VARCHAR(100) product
        TEXT ingredients
    }

    RECORD_WATER {
        BIGINT record_id PK FK
        DECIMAL amount "7,2"
    }

    RECORD_MEDICINE {
        BIGINT record_id PK FK
        VARCHAR(100) medicine_name
        VARCHAR(200) ingredients
        VARCHAR(100) dosage
    }

    RECORD_POOP {
        BIGINT record_id PK FK
        ENUM poop_shape "normal|soft|hard|liquid|thin|pellet"
        ENUM poop_color "yellow|lightBrown|brown|darkBrown|black|red|green|other"
        ENUM poop_amount "small|normal|large"
        ENUM poop_smell "none|mild|strong|veryStrong"
    }

    RECORD_WALK {
        BIGINT record_id PK FK
        DECIMAL distance "8,2"
        INT duration
        POINT start_location "SRID 4326"
        POINT end_location "SRID 4326"
    }

    RECORD_WEIGHT {
        BIGINT record_id PK FK
        DECIMAL weight "5,2"
    }

    RECORD_VET {
        BIGINT record_id PK FK
        VARCHAR(100) vet_clinic_name
        POINT clinic_location "SRID 4326"
        ENUM vet_visit_reason "checkup|vaccination|treatment|surgery|other"
        TEXT vet_diagnosis
        TEXT vet_treatment
        INT vet_cost
        DATE vet_next_visit_date
    }

    ROUTINES {
        BIGINT id PK
        BIGINT pet_id FK "NOT NULL"
        VARCHAR(100) label "NOT NULL"
        VARCHAR(30) type_id FK "NOT NULL → ACTIVITY_TYPES"
        ENUM repeat_type "daily|weekly|biweekly|monthly"
        JSON days "요일 배열 [0-6]"
        INT monthly_interval "DEFAULT 1"
        DATE start_date "NOT NULL"
        DATE end_date "nullable — 종료 날짜"
        JSON times "HH:MM 배열"
        TEXT note
        JSON detail
        BOOLEAN is_active "DEFAULT true"
        BOOLEAN notification_enabled "DEFAULT false"
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    ROUTINE_COMPLETIONS {
        BIGINT id PK "AUTO_INCREMENT"
        BIGINT routine_id FK "NOT NULL"
        BIGINT pet_id FK "NOT NULL"
        BIGINT activity_record_id FK "nullable — 완료 시 생성된 기록"
        DATE scheduled_date "NOT NULL"
        ENUM status "PENDING|COMPLETED|SKIPPED DEFAULT PENDING"
        DATETIME completed_at "nullable"
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    CARE_SCHEDULES {
        BIGINT id PK "AUTO_INCREMENT"
        BIGINT pet_id FK "NOT NULL"
        VARCHAR(40) category_id "NOT NULL, FK 없음"
        VARCHAR(100) title "NOT NULL"
        DATE start_date "NOT NULL"
        TIME start_time
        DATE end_date "NOT NULL"
        TIME end_time
        BOOLEAN all_day "NOT NULL DEFAULT false"
        VARCHAR(200) place
        VARCHAR(500) memo
        VARCHAR(100) reminder "NOT NULL"
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    WALLET_EXPENSES {
        BIGINT id PK "AUTO_INCREMENT"
        BIGINT user_id FK "NOT NULL"
        BIGINT pet_id FK "NOT NULL"
        DATE expense_date "NOT NULL"
        TIME expense_time
        BIGINT amount "NOT NULL"
        VARCHAR(3) currency "NOT NULL DEFAULT KRW"
        VARCHAR(40) category "NOT NULL"
        VARCHAR(100) item_name
        VARCHAR(500) note
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    POSTS {
        BIGINT id PK
        BIGINT user_id FK "NOT NULL"
        VARCHAR(120) title "NOT NULL"
        VARCHAR(30) category "DEFAULT FREE"
        VARCHAR(30) pet_species
        TEXT content "NOT NULL"
        INT likes_count "DEFAULT 0"
        INT comments_count "DEFAULT 0"
        DATETIME created_at "NOT NULL"
    }

    POST_MEDIA {
        BIGINT post_id PK FK
        BIGINT media_id PK FK
        INT sort_order "DEFAULT 0"
    }

    POST_POLLS {
        BIGINT id PK
        BIGINT post_id FK "UNIQUE"
        VARCHAR(200) question "NOT NULL"
    }

    POST_POLL_OPTIONS {
        BIGINT id PK
        BIGINT poll_id FK
        VARCHAR(100) label "NOT NULL"
        INT votes_count "DEFAULT 0"
        INT sort_order "DEFAULT 0"
    }

    POST_POLL_VOTES {
        BIGINT poll_id PK FK
        BIGINT user_id PK FK
        BIGINT option_id FK
        DATETIME created_at "NOT NULL"
        DATETIME updated_at "NOT NULL"
    }

    POST_LIKES {
        BIGINT user_id PK FK
        BIGINT post_id PK FK
        DATETIME created_at "NOT NULL"
    }

    POST_COMMENTS {
        BIGINT id PK "AUTO_INCREMENT"
        BIGINT post_id FK "NOT NULL"
        BIGINT user_id FK "NOT NULL"
        BIGINT parent_comment_id FK "nullable, self reference"
        TEXT content "NOT NULL"
        DATETIME created_at "NOT NULL"
    }

    REFRESH_TOKENS {
        BIGINT id PK
        BIGINT user_id FK "NOT NULL"
        VARCHAR(512) token_hash UK "NOT NULL"
        DATETIME expires_at "NOT NULL"
        DATETIME created_at "NOT NULL"
    }

    USERS ||--o{ OAUTH_ACCOUNTS : "linked via"
    USERS ||--o{ PETS : "owns"
    USERS ||--o{ POSTS : "writes"
    USERS ||--o{ POST_LIKES : "likes"
    USERS ||--o{ POST_COMMENTS : "comments"
    USERS ||--o{ REFRESH_TOKENS : "has"
    USERS ||--o{ MEDIA_RESOURCES : "owns"
    PETS ||--o{ ACTIVITY_RECORDS : "has"
    PETS ||--o{ ROUTINES : "has"
    PETS ||--o{ CARE_SCHEDULES : "has"
    USERS ||--o{ WALLET_EXPENSES : "owns"
    PETS ||--o{ WALLET_EXPENSES : "has"
    PETS ||--o{ MEDIA_RESOURCES : "profile photos"
    ACTIVITY_TYPES ||--o{ ACTIVITY_RECORDS : "classifies"
    ACTIVITY_TYPES ||--o{ ROUTINES : "classifies"
    ACTIVITY_RECORDS ||--o{ MEDIA_RESOURCES : "attached photos"
    MEDIA_CLEANUP_QUEUE }o..|| MEDIA_RESOURCES : "storage key only; FK 없음"
    ACTIVITY_RECORDS ||--o| RECORD_MEAL : "1:0..1"
    ACTIVITY_RECORDS ||--o| RECORD_WATER : "1:0..1"
    ACTIVITY_RECORDS ||--o| RECORD_MEDICINE : "1:0..1"
    ACTIVITY_RECORDS ||--o| RECORD_POOP : "1:0..1"
    ACTIVITY_RECORDS ||--o| RECORD_WALK : "1:0..1"
    ACTIVITY_RECORDS ||--o| RECORD_WEIGHT : "1:0..1"
    ACTIVITY_RECORDS ||--o| RECORD_VET : "1:0..1"
    ROUTINES ||--o{ ACTIVITY_RECORDS : "generates"
    ROUTINES ||--o{ ROUTINE_COMPLETIONS : "tracks"
    ROUTINE_COMPLETIONS }o--o| ACTIVITY_RECORDS : "completed record"
    PETS ||--o{ ROUTINE_COMPLETIONS : "daily tasks"
    POSTS ||--o{ POST_LIKES : "receives"
    POSTS ||--o{ POST_COMMENTS : "has comments"
    POST_COMMENTS ||--o{ POST_COMMENTS : "has replies"
    POSTS ||--o{ POST_MEDIA : "has media"
    MEDIA_RESOURCES ||--o{ POST_MEDIA : "attached to posts"
    POSTS ||--o| POST_POLLS : "has poll"
    POST_POLLS ||--o{ POST_POLL_OPTIONS : "has options"
    POST_POLLS ||--o{ POST_POLL_VOTES : "receives votes"
    POST_POLL_OPTIONS ||--o{ POST_POLL_VOTES : "selected option"
```

---

## 인덱스 설계

### 복합 인덱스

```sql
-- ACTIVITY_RECORDS: 특정 반려동물의 날짜별 조회 최적화 (가장 빈번한 쿼리)
ALTER TABLE activity_records
  ADD INDEX idx_pet_date (pet_id, date);

-- ACTIVITY_RECORDS: typeId 필터 조회 최적화
ALTER TABLE activity_records
  ADD INDEX idx_pet_type (pet_id, type_id);

-- ROUTINE_COMPLETIONS: 루틴별 날짜 조회 + 오늘 할 일 목록
ALTER TABLE routine_completions
  ADD UNIQUE INDEX uq_routine_date (routine_id, scheduled_date),
  ADD INDEX idx_pet_scheduled (pet_id, scheduled_date);

-- CARE_SCHEDULES: 반려동물별 일정 날짜/카테고리 조회
ALTER TABLE care_schedules
  ADD INDEX idx_care_schedules_pet_date (pet_id, start_date, end_date, id),
  ADD INDEX idx_care_schedules_pet_category_date (pet_id, category_id, start_date, id);

-- PETS: 소프트 딜리트 필터
ALTER TABLE pets
  ADD INDEX idx_user_active (user_id, is_deleted);

-- MEDIA_RESOURCES: 소유자 직접 조회
ALTER TABLE media_resources
  ADD INDEX idx_user (user_id),
  ADD INDEX idx_pet (pet_id),
  ADD INDEX idx_record (record_id);
```

### 공간 인덱스

```sql
-- RECORD_WALK: 산책 시작/종료 위치
ALTER TABLE record_walk
  ADD SPATIAL INDEX idx_start_location (start_location),
  ADD SPATIAL INDEX idx_end_location (end_location);

-- RECORD_VET: 병원 위치 반경 검색
ALTER TABLE record_vet
  ADD SPATIAL INDEX idx_clinic_location (clinic_location);

-- 포인트 삽입 예시 (SRID 4326 강제)
INSERT INTO record_vet (record_id, clinic_location)
VALUES (1, ST_GeomFromText('POINT(127.0276 37.4979)', 4326));

-- 반경 1km 내 병원 검색
SELECT r.* FROM record_vet r
WHERE ST_Distance_Sphere(
  r.clinic_location,
  ST_GeomFromText('POINT(127.0276 37.4979)', 4326)
) <= 1000;
```

---

## Flyway 마이그레이션 구조

```
backend/src/main/resources/db/migration/
├── V1__create_spatial_test.sql
├── V2__add_users_and_tokens.sql
├── V3__add_pets.sql
├── V4__add_activity_records.sql
├── V5__add_routines.sql
├── V6__add_community.sql
├── V7__add_media_resources.sql
├── V8__add_routine_record_template.sql
├── V9__add_user_profile_media.sql
├── V10__extend_community_posts.sql
├── V11__add_oauth_accounts.sql
├── V12__add_diary_activity_type.sql
├── V13__add_etc_activity_type.sql
├── V14__extend_pet_profile_fields.sql
├── V15__allow_pet_birth_date_nullable.sql
├── V16__create_wallet_expenses.sql
├── V17__create_post_comments.sql
├── V18__create_care_schedules.sql
└── V19__add_post_comment_replies.sql
```

> **규칙:** 한번 배포된 `V*.sql`은 절대 수정 금지. 변경 시 `V{n+1}__alter_xxx.sql` 신규 파일 작성.

---

## 테이블 설계 결정 사항

### ACTIVITY_TYPES — 확장 가능한 타입 마스터

`VARCHAR(30)` 자연 키 사용 — 코드값 자체가 의미를 지니므로 BIGINT 서로게이트 키 불필요.

```sql
CREATE TABLE activity_types (
  id            VARCHAR(30) PRIMARY KEY,
  name          VARCHAR(50)  NOT NULL,
  icon_url      VARCHAR(200),
  display_order INT DEFAULT 0
) ENGINE=InnoDB;

-- 초기 시드 데이터 (V4__add_activity_records.sql 상단에 포함)
INSERT INTO activity_types (id, name, display_order) VALUES
  ('meal',      'meal',     1),
  ('water',     'water',    2),
  ('walk',      'walk',     3),
  ('medicine',  'medicine', 4),
  ('poop',      'poop',     5),
  ('weight',    'weight',   6),
  ('vet',       'vet',      7),
  ('diary',     'diary',    8),
  ('etc',       'etc',      9);

```

`diary`와 `etc`는 전용 detail 테이블 없이 `activity_records.note`만 사용한다.

유지 타입은 `meal`, `water`, `poop`, `walk`, `medicine`, `weight`, `vet`, `diary`, `etc` 9개 기준으로 관리한다. 일정·지갑의 `grooming`과 `record_vet.vet_visit_reason = 'checkup'`은 활동 기록 타입과 별개다.

**새 타입 추가 시:** DB seed, 백엔드 지원 목록과 detail 처리, 필요한 프론트 진입점/라벨을 함께 확인한다.  
**JPA:** `@ManyToOne(fetch = LAZY)` + `@JoinColumn(name = "type_id")` — 타입 조회 시 캐시 활용.

---

### 활동 기록 분리 전략 (슈퍼타입-서브타입)

`activity_records`를 슈퍼타입으로, typeId별 상세 컬럼을 별도 서브타입 테이블로 분리.

**이유:**
- 단일 테이블에 모든 컬럼을 넣으면 컬럼 40개 이상 — NULL이 너무 많아짐
- 각 typeId 조회 시 JOIN 1회로 필요한 컬럼만 로드
- typeId 추가 시 서브타입 테이블만 추가 (기존 테이블 무수정)

**JPA 전략:** `@Inheritance(strategy = InheritanceType.JOINED)` + `@DiscriminatorColumn(name = "type_id")`

---

### 루틴 생명 주기 (end_date + is_active)

| 컬럼 | 용도 |
|------|------|
| `start_date` | 루틴 시작일. 이 날 이전에는 PENDING 생성 안 함 |
| `end_date` | 종료일 (nullable). 약 복용처럼 기간이 정해진 루틴에 사용 |
| `is_active` | 일시 정지 플래그. `false`이면 PENDING 생성 중단, 삭제는 아님 |

**상태 조합:**

| is_active | end_date | 동작 |
|-----------|----------|------|
| true | NULL | 무기한 진행 |
| true | 미래 날짜 | 해당 날까지 진행 후 자동 종료 |
| false | any | 일시 정지 (데이터 유지) |

**ROUTINE_COMPLETIONS 생성 조건:** `is_active = true AND (end_date IS NULL OR end_date >= today)`

---

### 미디어 관리 전략 (MEDIA_RESOURCES)

`PETS` 프로필 사진, `ACTIVITY_RECORDS` 첨부 사진, 커뮤니티 게시글 첨부 사진을 단일 테이블로 관리한다. 게시글 첨부는 `post_media` 조인 테이블로 연결한다.

**user_id 직접 보유:** `pet_id` → `pets.user_id` 조인 없이 `WHERE user_id = :currentUserId`로 즉시 소유권 확인.

```sql
CREATE TABLE media_resources (
  id            BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id       BIGINT       NOT NULL,
  pet_id        BIGINT,
  record_id     BIGINT,
  storage_key   VARCHAR(500) NOT NULL UNIQUE,
  original_name VARCHAR(255) NOT NULL,
  content_type  VARCHAR(100) NOT NULL,
  extension     VARCHAR(10)  NOT NULL,
  file_size     BIGINT       NOT NULL,
  status        ENUM('STORED') NOT NULL,
  visibility    VARCHAR(20) NOT NULL DEFAULT 'PRIVATE',
  created_at    DATETIME     NOT NULL,
  FOREIGN KEY (user_id)   REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (pet_id)    REFERENCES pets(id) ON DELETE CASCADE,
  FOREIGN KEY (record_id) REFERENCES activity_records(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

**연결 방식:**

| 용도 | 연결 |
|------|------|
| 펫 프로필 사진 | `media_resources.pet_id` |
| 기록 첨부 사진 | `media_resources.record_id` |
| 커뮤니티 게시글 사진 | `post_media(post_id, media_id, sort_order)` |

현재 로컬 저장소 구현에서는 업로드 완료 파일만 DB에 저장하므로 `status`는 `STORED`만 사용한다. 게시글 공개 이미지는 `visibility = 'PUBLIC'`, 펫/기록 이미지는 기본값 `PRIVATE`를 사용한다.

제거 대상 미디어가 생기는 cleanup migration은 `storage_key`를 FK 없는 `media_cleanup_queue`에 먼저 복사한 뒤 DB 행을 cascade 삭제하는 방식으로 작성한다. 앱 시작 `MediaCleanupRunner`는 파일 삭제 성공 뒤 queue 행을 삭제하며, 파일/DB 삭제 실패는 queue를 보존해 다음 시작에 재시도한다.

```sql
CREATE TABLE post_media (
  post_id    BIGINT NOT NULL,
  media_id   BIGINT NOT NULL,
  sort_order INT    NOT NULL DEFAULT 0,
  PRIMARY KEY (post_id, media_id),
  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (media_id) REFERENCES media_resources(id) ON DELETE CASCADE
);
```

**로컬 저장 키:** `storage_key`는 로컬 저장소 내부 파일 식별자다. S3/MinIO 같은 객체 저장소와 `{env}/{userId}/{petId}/{yyyyMM}/{uuid}.{ext}` 키 설계는 배포/클라우드 단계에서 다시 결정한다.

---

### 루틴 이행 추적 (ROUTINE_COMPLETIONS)

루틴이 활성화된 날 서버에서 `PENDING` 레코드를 생성. 클라이언트 요청 시 lazy 생성도 가능.

**상태 전이:**
```
PENDING → COMPLETED  (사용자가 완료 체크 → activity_record 자동 생성)
PENDING → SKIPPED    (사용자가 건너뜀 또는 다음날 자동 처리)
COMPLETED → PENDING  (완료 취소 → 연결된 activity_record 함께 삭제)
```

**`activity_record_id` 연결의 이점:**
- 완료 취소 시 `routine_completions.activity_record_id` → 해당 기록 즉시 삭제 (조인 불필요)
- "기록 없이 완료 체크만 한 경우"(activity_record_id = NULL) vs "기록까지 생성한 경우" 명확히 구분
- 기록이 나중에 수동 삭제되면 `activity_record_id = NULL`로 SET (ON DELETE SET NULL)

```sql
FOREIGN KEY (activity_record_id)
  REFERENCES activity_records(id)
  ON DELETE SET NULL   -- 기록 삭제 시 연결만 끊기, 완료 이력은 유지
```

**오늘 이행률 계산 쿼리:**
```sql
SELECT
  COUNT(*)                                          AS total,
  SUM(status = 'COMPLETED')                         AS done,
  ROUND(SUM(status = 'COMPLETED') / COUNT(*) * 100, 1) AS rate
FROM routine_completions
WHERE pet_id = ? AND scheduled_date = CURDATE();
```

**유니크 제약:** `(routine_id, scheduled_date)` — 같은 날 같은 루틴 중복 생성 방지.

**Range 파티셔닝 (서비스 성장 후 적용):**

매일 반려동물당 N개씩 생성되어 가장 빠르게 커지는 테이블.  
`scheduled_date` 기준 연간 파티션으로 "오늘 할 일" 조회를 항상 최신 파티션에서만 수행.

```sql
-- V6에서 파티션 테이블로 생성 (나중에 ALTER로 추가도 가능)
CREATE TABLE routine_completions (
  id             BIGINT AUTO_INCREMENT,
  routine_id     BIGINT       NOT NULL,
  pet_id         BIGINT       NOT NULL,
  scheduled_date DATE         NOT NULL,
  status         ENUM('PENDING','COMPLETED','SKIPPED') DEFAULT 'PENDING',
  completed_at   DATETIME,
  created_at     DATETIME     NOT NULL,
  PRIMARY KEY (id, scheduled_date),           -- 파티션 키는 PK에 포함 필수
  UNIQUE KEY uq_routine_date (routine_id, scheduled_date)
)
PARTITION BY RANGE (YEAR(scheduled_date)) (
  PARTITION p2025 VALUES LESS THAN (2026),
  PARTITION p2026 VALUES LESS THAN (2027),
  PARTITION p2027 VALUES LESS THAN (2028),
  PARTITION pmax  VALUES LESS THAN MAXVALUE
);

-- 연말 파티션 추가 (운영 중 무중단)
ALTER TABLE routine_completions
  REORGANIZE PARTITION pmax INTO (
    PARTITION p2028 VALUES LESS THAN (2029),
    PARTITION pmax  VALUES LESS THAN MAXVALUE
  );
```

> **주의:** 파티션 테이블에서 FK 제약이 지원되지 않음 (MySQL 제한). 참조 무결성은 애플리케이션 레이어에서 보장.

---

### 커뮤니티 댓글 (POST_COMMENTS)

댓글은 root와 한 단계 답글을 지원한다. `parent_comment_id IS NULL`이면 root이고, 값이 있으면 같은 게시글의 root 댓글을 참조하는 답글이다. API가 parent가 root인지 검증해 답글의 답글을 거부한다. 댓글·답글 수정, 실제 삭제, 신고는 현재 범위 밖이다.

```sql
CREATE TABLE post_comments (
  id         BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id    BIGINT   NOT NULL,
  user_id    BIGINT   NOT NULL,
  parent_comment_id BIGINT NULL,
  content    TEXT     NOT NULL,
  created_at DATETIME NOT NULL,
  CONSTRAINT fk_post_comments_post FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  CONSTRAINT fk_post_comments_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  CONSTRAINT fk_post_comments_parent FOREIGN KEY (parent_comment_id) REFERENCES post_comments(id) ON DELETE CASCADE,
  INDEX idx_post_comments_post_cursor (post_id, id),
  INDEX idx_post_comments_thread_cursor (post_id, parent_comment_id, id DESC)
) ENGINE=InnoDB;
```

댓글·답글 작성 시 `posts.comments_count` 증가는 같은 트랜잭션에서 처리하며 두 종류를 모두 합산한다. root 삭제 기능을 추가할 때는 cascade로 삭제되는 답글 수까지 함께 감소시켜야 한다. 클라이언트는 댓글 수를 추측해서 증가시키지 않고, 작성 응답의 서버 기준 `commentsCount`를 사용한다.

---

### 타임존 전략

서버는 UTC 기준으로 동작한다. 현재 스키마에는 사용자별 `timezone` 컬럼이 없고, 루틴 알림 운영 구성도 MVP/배포 단계까지 보류되어 있다.

- 현재 루틴의 `times` (예: `["08:00", "21:00"]`)는 앱/서버가 같은 로컬 기준으로 해석한다.
- 사용자별 타임존과 알림 스케줄러는 배포/푸시 알림 단계에서 새 마이그레이션으로 추가한다.

```java
// 향후 사용자별 timezone 컬럼을 추가할 때의 계산 예시
ZoneId userZone = ZoneId.of(user.getTimezone());
LocalDateTime localFire = LocalDate.now(userZone).atTime(LocalTime.parse("08:00"));
ZonedDateTime utcFire = localFire.atZone(userZone).withZoneSameInstant(ZoneOffset.UTC);
```

**루틴별 타임존 오버라이드는 MVP에서 제외.** 사용자 단위 타임존으로 충분.

---

### 소프트 딜리트 전략

`PETS` 테이블만 소프트 딜리트 적용 (`is_deleted = true`). 반려동물 데이터는 사용자에게 소중하므로 실수 삭제 방지.

- 연관 `activity_records`, `routines`, `routine_completions`, `media_resources`는 CASCADE DELETE (하드 딜리트).
- JPA: `@Where(clause = "is_deleted = false")` 어노테이션으로 모든 조회에서 자동 필터.
- 복구 API: `POST /api/v1/pets/{id}/restore` (Phase 3+).

---

### Spring Data JPA Auditing

모든 테이블의 `created_at`, `updated_at`을 자동 관리.

```java
// BaseEntity (모든 Entity가 상속)
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {
    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;
}

// Main 클래스에 활성화
@EnableJpaAuditing
@SpringBootApplication
public class PetyilgiApplication { ... }
```

---

### 식별자 전략

MVP에서는 `BIGINT AUTO_INCREMENT` (단순성 우선).  
분산 환경 전환 시 UUID v7로 마이그레이션 가능.

---

## init.sql 핵심 구문 (record_walk 예시)

```sql
-- MySQL 8.0 공간 데이터 활성화
SET GLOBAL log_bin_trust_function_creators = 1;

-- SRID 4326 강제 컬럼 정의 예시
CREATE TABLE record_walk (
  record_id      BIGINT PRIMARY KEY,
  distance       DECIMAL(8,2),
  duration       INT,
  start_location POINT NOT NULL SRID 4326,
  end_location   POINT SRID 4326,
  SPATIAL INDEX idx_start (start_location),
  FOREIGN KEY (record_id) REFERENCES activity_records(id) ON DELETE CASCADE
) ENGINE=InnoDB;
```
