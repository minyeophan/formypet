# 전체 TDD 마일스톤 — 펫일기 백엔드

> 원칙: **Red → Green → Refactor** 사이클을 벗어난 구현 없음.  
> 각 Phase는 단일 Verify 조건이 통과해야 다음으로 진행한다.

---

## Phase 0 — 거버넌스 정립 ✅
**상태:** 완료  
**산출물:** AGENTS.md 규칙, docs/ 문서 체계, ERD 초안  
**Frontend 결합:** 없음

---

## Phase 1 — TDD 인프라 구축
**상태:** 완료  
**Verify:** `./gradlew test` 통과 — Testcontainers MySQL에 대한 공간 쿼리(ST_Distance_Sphere) 통합 테스트 GREEN  
**태스크:** `tasks/task-01-setup-tdd-env.md`  
**예상 소요:** 4–6시간

### 목표
- Gradle 빌드 구성 (Java 21, Groovy DSL)
- Docker Compose (MySQL 8.0 + healthcheck + init.sql: 공간 인덱스, SRID 4326)
- Virtual Thread 활성화 (`spring.threads.virtual.enabled=true`)
- Flyway 마이그레이션 (`V1__create_spatial_test.sql`)
- RFC 7807 `ProblemDetail` 기반 공통 응답/예외 구조
- Testcontainers 통합 테스트 베이스 클래스
- Swagger UI (`/swagger-ui.html`) Mock API 확인 가능 상태
- `SecurityConfig` — Phase 1은 전체 `permitAll()`

### 핵심 테스트 (Red 먼저)
```
SpatialQueryIntegrationTest
  - testMySQLConnectionWithSpatialSupport()     // ST_Distance_Sphere 실행 확인
  - testInsertAndQueryPointWithSRID4326()       // POINT(lng, lat) 저장·조회
  - testRadiusSearchReturnsCorrectResults()     // 반경 1km 내 결과 필터
```

### DoD (완료 기준)
- [x] `./gradlew test` 3개 테스트 GREEN (CI 환경에서도)
- [x] `./gradlew bootRun` 후 `http://localhost:8080/swagger-ui.html` 접근 가능
- [x] `GET /api/v1/health` → `"Virtual Thread ✅"` 응답
- [x] `application.yml` test profile 구성 완료 (테스트용 Flyway disabled, ddl-auto: none)

### 리스크
- Testcontainers 최초 실행 시 MySQL 이미지 pull (수 분 소요) — CI 캐시 필요
- Apple Silicon(arm64)에서 `mysql:8.0` 이미지 호환 확인 필요 (`platform: linux/amd64` 명시)
- Flyway `V1__create_spatial_test.sql`과 Entity 필드 불일치 시 `validate` 오류 — 항상 같이 수정

**Frontend 결합:** Swagger UI로 Mock 엔드포인트 확인 가능. 실제 데이터 연동 없음.

---

## Phase 2 — 인증 도메인 (Auth)
**상태:** 완료  
**Verify:** `AuthIntegrationTest` — 회원가입·로그인·토큰 갱신·로그아웃 시나리오 전체 GREEN  
**예상 소요:** 6–8시간

### 목표
- `users`, `refresh_tokens` 테이블 + JPA Entity
- Spring Security 6 + JWT (Access 15분, Refresh 7일)
- `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `POST /api/v1/auth/refresh`, `POST /api/v1/auth/logout`
- Password BCrypt 해싱, RefreshToken DB 저장
- Flyway: `V2__add_users_and_tokens.sql`

### 핵심 테스트 (Red 먼저)
```
AuthIntegrationTest
  - registerSuccessReturnsTokens()
  - loginWithWrongPasswordReturns401()
  - refreshTokenRotation()
  - accessProtectedEndpointWithoutTokenReturns401()
```

### DoD (완료 기준)
- [x] 4개 테스트 GREEN
- [x] `SecurityConfig`에서 `/api/v1/auth/**`만 `permitAll()`, 나머지 `authenticated()`
- [x] RefreshToken 재사용 시 무효화 (rotation)
- [x] `V2__add_users_and_tokens.sql` Flyway 마이그레이션 완료

### 리스크
- JWT 라이브러리 선택 (`jjwt` vs `nimbus-jose-jwt`) — `jjwt 0.12+` 권장
- RefreshToken 동시 갱신 경합 — Optimistic Lock 또는 DB unique constraint 필요

**Frontend 결합:** 이 Phase 완료 후 프론트엔드 로그인 화면 연동 가능.  
현재 프론트: AsyncStorage 로컬 전용 → 인증 미구현. 연동 시 `pet-context.tsx` 전면 수정 필요.

---

## Phase 3 — 펫 도메인 (Pet)
**상태:** 완료  
**Verify:** `PetIntegrationTest` — CRUD + 다중 펫 전환 시나리오 GREEN  
**예상 소요:** 4–6시간

### 목표
- `pets` 테이블 + Entity + Repository
- `GET/POST/PUT/DELETE /api/v1/pets`
- 사용자별 펫 목록 조회, 소유권 검증
- record 기반 DTO: `PetResponse`, `PetCreateRequest`
- Flyway: `V3__add_pets.sql`

### 핵심 테스트 (Red 먼저)
```
PetIntegrationTest
  - createPetReturnsCreatedPet()
  - listPetsReturnsOnlyOwnedPets()
  - updatePetNameSucceeds()
  - deletePetAlsoDeletesRecords()       // Cascade 검증
  - accessOtherUsersPetReturns403()
```

### DoD (완료 기준)
- [x] 5개 테스트 GREEN
- [x] 다른 유저의 펫 접근 시 403 (소유권 검증 서비스 레이어)
- [x] 펫 삭제는 `is_deleted = true` 소프트 딜리트로 처리
- [x] `accent_color`, `bg_light` 서버에서 자동 배정 로직 포함

### 리스크
- 펫 소유권 검증 중복 코드 — `PetAccessGuard` 또는 서비스 공통 메서드로 통일

**Frontend 결합:** Phase 3 완료 → `usePets()` context를 API 호출로 교체 가능.  
대상 파일: `src/lib/pet-context.tsx`, `src/components/onboarding/PetRegisterForm.tsx`

---

## Phase 4 — 활동 기록 도메인 (ActivityRecord)
**상태:** 부분 완료 — ActivityRecord CRUD 완료, 미디어는 Phase 7로 분리  
**Verify:** `ActivityRecordIntegrationTest` — 모든 typeId별 저장·조회·수정·삭제 GREEN  
**예상 소요:** 10–14시간 (서브타입 테이블 7개)

### 목표
- `activity_records` 슈퍼타입 + 서브타입 테이블 (JOINED 전략, typeId별 7개)
- `GET/POST/PUT/DELETE /api/v1/pets/{petId}/records`
- 날짜 필터 (`?date=YYYY-MM-DD`), typeId 필터 (`?typeId=meal`), 최근 N개 (`?limit=3`)
- 산책/병원 POINT 저장 (SRID 4326)
- 미디어 업로드는 Phase 7 Local Media Domain으로 분리
- Flyway: `V4__add_activity_records.sql`

### 핵심 테스트 (Red 먼저)
```
ActivityRecordIntegrationTest
  - createMealRecordSucceeds()
  - createWalkRecordWithLocationSucceeds()
  - filterRecordsByDateReturnsCorrectSubset()
  - filterRecordsByTypeIdReturnsCorrectSubset()
  - updateRecordOnlyChangesSpecifiedFields()
```

### DoD (완료 기준)
- [ ] 5개 테스트 GREEN
- [ ] 모든 typeId (meal/water/medicine/poop/walk/weight/vet) 저장·조회 확인
- [ ] POINT 컬럼 SRID 4326 강제 확인 (잘못된 SRID 삽입 시 예외)
- [ ] 날짜/typeId 복합 필터 동작 확인
- [ ] 미디어 업로드는 Phase 7에서 로컬 저장소 기준으로 검증
- [ ] `(pet_id, date)` 복합 인덱스 포함 마이그레이션

### 리스크
- `@Inheritance(JOINED)` + 필터 쿼리 시 N+1 문제 — `JOIN FETCH` 또는 `@EntityGraph` 필요
- 서브타입 테이블 7개 마이그레이션 SQL — `V4__` 파일에 통합
- S3는 현재 사용하지 않음. 로컬 미디어 저장소는 Phase 7에서 별도 구현

**Frontend 결합:** Phase 4 완료 → `addRecord()`, `updateRecord()` API 교체 가능.  
대상 파일: `src/lib/pet-context.tsx`, `app/record-edit/[id].tsx`

---

## Phase 5 — 루틴 도메인 (Routine)
**상태:** 완료  
**Verify:** `RoutineIntegrationTest` — 반복 유형별 스케줄 계산 GREEN  
**예상 소요:** 4–6시간

### 목표
- `routines` 테이블 (JSON `days`, JSON `times` 컬럼)
- `routine_completions` 테이블 — 일별 PENDING/COMPLETED/SKIPPED 상태 추적
- `GET/POST/PUT/DELETE /api/v1/pets/{petId}/routines`
- `PATCH /api/v1/pets/{petId}/routines/{id}/completions/{date}` — 완료 상태 변경
- `GET /api/v1/pets/{petId}/routines/today` — 오늘 이행률 + 할 일 목록
- Flyway: `V5__add_routines.sql` (routines + routine_completions 포함)

### 핵심 테스트 (Red 먼저)
```
RoutineIntegrationTest
  - createDailyRoutineSucceeds()
  - createWeeklyRoutineWithDaysSucceeds()
  - markCompletionChangesStatus()
  - todayCompletionRateCalculatesCorrectly()
  - deleteRoutineSucceeds()
```

### DoD (완료 기준)
- [x] 5개 테스트 GREEN
- [x] JSON 컬럼 (`days`, `times`) 저장·조회 정상 동작
- [x] `routine_completions` (routine_id, scheduled_date) 유니크 제약 검증
- [x] 오늘 이행률 API 응답 확인 (`{ total, done, rate }`)

### 리스크
- MySQL JSON 컬럼 JPA 매핑 — `@Convert` + `JsonConverter` 또는 Hypersistence Utils 라이브러리 필요
- `PENDING` 레코드 생성 시점 — lazy(요청 시) vs eager(스케줄러) 결정 필요

**Frontend 결합:** `app/routine.tsx` API 교체.

---

## Phase 6 — 커뮤니티 도메인 (Community)
**상태:** 완료  
**Verify:** `CommunityIntegrationTest` — 피드 페이지네이션 + 좋아요 토글 GREEN  
**예상 소요:** 4–5시간

### 목표
- `posts`, `post_likes` 테이블
- `GET /api/v1/posts` (커서 페이지네이션 `?cursor=&limit=20`)
- `POST /api/v1/posts`, `POST /api/v1/posts/{id}/like` (토글)
- 사진 업로드 MVP 제외
- Flyway: `V6__add_community.sql`

### 핵심 테스트 (Red 먼저)
```
CommunityIntegrationTest
  - createPostSucceeds()
  - feedReturnsCursorPagination()
  - likeToggleIncreasesAndDecreasesCount()
  - duplicateLikeIsIdempotent()
```

### DoD (완료 기준)
- [x] 4개 테스트 GREEN
- [x] 커서 페이지네이션 (id 기반) 동작 확인
- [x] 좋아요 토글 멱등성 확인 (같은 유저 중복 좋아요 → 취소)
- [x] `likes_count` 정합성 — DB 트리거 또는 서비스 레이어 원자적 증감

### 리스크
- `likes_count` 동시 업데이트 경합 — `UPDATE posts SET likes_count = likes_count + 1` 원자적 연산 필수

**Frontend 결합:** `app/(tabs)/community.tsx` API 교체.

---

## Frontend 결합 타임라인 요약

| Phase | 완료 조건 | 프론트 연동 가능 파일 |
|-------|----------|---------------------|
| 2 (Auth) | JWT 발급 | `pet-context.tsx`, 로그인 화면 신규 |
| 3 (Pet) | Pet CRUD | `pet-context.tsx`, `PetRegisterForm.tsx` |
| 4 (Record) | Record CRUD | `pet-context.tsx`, `record-edit/[id].tsx` |
| 5 (Routine) | Routine CRUD | `app/routine.tsx` |
| 6 (Community) | Post CRUD | `community.tsx` |

---

## Revised Next Phases - 2026-05-09

### Phase 7 - Local Media Domain
**Status:** Complete  
**Verify:** `MediaIntegrationTest` - local upload, DB save, URL response, and file retrieval GREEN  
**Task:** `tasks/task-07-local-media.md`

#### Goals
- Add `media_resources` table.
- Implement local filesystem storage under `backend/storage/{userId}/{petId}/{yyyyMM}/{uuid}.{ext}`.
- Add record media upload API: `POST /api/v1/pets/{petId}/records/{recordId}/media`.
- Add pet profile media upload API: `POST /api/v1/pets/{petId}/media`.
- Add media retrieval URL/API for frontend display.
- Add `MediaStorage` interface with `LocalMediaStorage` implementation only.
- Flyway: `V7__add_media_resources.sql`.

#### DoD
- [ ] Upload stores file locally and creates `media_resources` row.
- [ ] Response includes stable media URL.
- [ ] URL retrieves the uploaded file.
- [ ] Ownership checks prevent other users from accessing media.
- [ ] Full backend tests pass.

#### Explicit Exception
- S3, MinIO, LocalStack, and paid cloud storage are excluded.
- S3 integration is deferred until after frontend API integration and deployment planning.

### Phase 8 - Frontend API Integration
**Status:** Complete by CLI, manual Expo device/emulator verification pending  
**Verify:** `npx.cmd tsc --noEmit` passes in `frontend/`; manual Expo app flow remains pending.

#### Goals
- Replace AsyncStorage/mock data with backend API calls.
- Wire JWT storage and authenticated requests.
- Integrate Pet CRUD, ActivityRecord CRUD, Routine CRUD, Community feed/likes.
- Use Phase 7 local media URLs for image display.

#### DoD
- [x] Login/register API client and token storage wired.
- [x] Pet CRUD uses backend APIs.
- [x] Records, routines, and community screens use backend data.
- [x] Local media upload/display is wired through Phase 7 media APIs.
- [ ] Manual Expo device/emulator verification complete.

### Deployment Phase - Deferred
**Status:** Deferred  
**Reason:** Deployment work is intentionally postponed until after frontend API integration.

#### Deferred Scope
- Production deployment.
- S3 or other cloud object storage.
- Domain/SSL/server provisioning.
- Production environment hardening.

#### Re-entry Condition
- Start the deployment phase only after Phase 8 is verified from the app end to end.
