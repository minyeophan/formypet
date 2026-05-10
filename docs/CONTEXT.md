# AI 세션 브리핑 — 펫일기 백엔드

> **필독 우선순위 #1.** 새 세션 시작 시 이 파일을 가장 먼저 읽는다.  
> 이후 `docs/FRONTEND_STATUS.md` → 현재 Phase 태스크 파일 순으로 읽는다.

---

## 5줄 현황 요약

1. **현재 Phase:** Phase 8 안정화 완료 후 유지보수 상태. 한글 mojibake 스캔 도구 추가와 루틴 기록 템플릿 테스트 스키마 복구 완료.
2. **마지막 통과 테스트:** 2026-05-10 `./gradlew.bat test`, 대상 테스트 2개, `npx.cmd tsc --noEmit`, `scripts/check-korean-mojibake.ps1` 모두 GREEN.
3. **최근 결정:** 한글 손상 판단은 strict UTF-8 스캐너와 `Get-Content -Encoding utf8` 기준으로만 한다. 콘솔 기본 출력 mojibake만 보고 파일을 재저장하지 않는다.
4. **다음 작업 목표:** 백엔드 실행 후 Expo 앱에서 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 수동 검증한다.
5. **주의:** 기존 Flyway `V1`~`V8`은 수정하지 않는다. 배포, S3, MinIO, LocalStack, 도메인, SSL, 프로덕션 스토리지는 별도 배포 Phase까지 보류한다.

---

## 빠른 시작 명령어

```bash
# 1. DB 컨테이너 올리기 (개발용 docker-compose)
cd backend
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml ps          # mysql 상태 healthy 확인

# 2. 전체 테스트 실행 (Testcontainers가 별도 컨테이너 자동 기동)
./gradlew test

# 3. 앱 실행 (Swagger: http://localhost:8080/swagger-ui.html)
./gradlew bootRun

# 4. 특정 테스트 클래스만 실행
./gradlew test --tests "com.petyilgi.spatial.SpatialQueryIntegrationTest"

# 5. 로그 포함 실행
./gradlew test --info 2>&1 | tail -50
```

> `docker-compose up` 없이 `./gradlew test` 만 실행해도 됨 — Testcontainers가 MySQL을 자동 기동함.  
> 단, Docker Desktop이 실행 중이어야 한다.

---

## 현재 Phase 상세

### 완료된 백엔드 Phase

세부 구현 순서는 `tasks/task-01-setup-tdd-env.md` 참고.

- [x] `backend/` 디렉토리 및 Gradle 프로젝트 초기화
  - verify: `./gradlew dependencies` 오류 없음
- [x] `build.gradle` 의존성 설정 (Spring Boot 3.4, Testcontainers, Flyway, Spatial)
- [x] `docker/docker-compose.yml` MySQL 8.0 + healthcheck
- [x] `src/main/resources/db/migration/V1__create_spatial_test.sql` — Flyway 초기 Spatial 검증 스키마
- [x] `application.yml` (Virtual Thread, DB, Swagger, test profile)
- [x] `SecurityConfig` — Phase 2 이후 JWT 보호 적용
- [x] Testcontainers 베이스 클래스 `IntegrationTestSupport`
- [x] **[RED]** `SpatialQueryIntegrationTest` 3개 테스트 작성
- [x] **[GREEN]** Testcontainers + MySQL Spatial 테스트 통과
- [x] **[REFACTOR]** `record ApiResponse<T>` + `GlobalExceptionHandler` 정의
- [x] **완료 기준:** `./gradlew test` 전체 GREEN, `/swagger-ui.html` 접근 가능

---

## 알려진 함정 (Gotchas)

| 상황 | 잘못된 접근 | 올바른 접근 |
|------|------------|------------|
| 테스트 DB 스키마 | `ddl-auto: validate` → FlywayException | `ddl-auto: none` + Flyway 마이그레이션 |
| Spring Security 기본값 | 모든 엔드포인트 401 차단 | `SecurityConfig.permitAll()` Phase 1 적용 |
| Testcontainers 격리 | 테스트 간 데이터 충돌 | `@Transactional` 자동 롤백 + `@BeforeEach` 정리 |
| Virtual Thread + DB 커넥션 | `synchronized` 블록 → pinning | `ReentrantLock` 또는 lock-free 패턴 |
| POINT 저장 | SRID 없이 저장 → Spatial 연산 실패 | `ST_GeomFromText('POINT(lng lat)', 4326)` 강제 |
| Testcontainers 병렬 실행 | 컨테이너 포트 충돌 | `maxParallelForks = 1` (build.gradle) |
| PETS 삭제 | 하드 딜리트 → 데이터 영구 소실 | `is_deleted = true` 소프트 딜리트 + `@Where` |
| ROUTINE_COMPLETIONS 중복 | 같은 날 루틴 레코드 2개 생성 | `UNIQUE(routine_id, scheduled_date)` 제약 |
| ACTIVITY_TYPES 없이 기록 생성 | FK 위반 오류 | V4 마이그레이션 상단에 INSERT 시드 데이터 포함 |
| CHECK 제약 무시 (MySQL < 8.0.16) | XOR 제약이 무시됨 | TRIGGER로 보완 + 서비스 레이어 이중 검증 |
| ROUTINE_COMPLETIONS FK + 파티션 | MySQL에서 파티션 테이블에 FK 불가 | 앱 레이어에서 참조 무결성 보장 |
| 루틴 알림 시간 | 서버 UTC 기준 저장 → 잘못된 발송 | `users.timezone`으로 로컬 시간 변환 후 UTC 스케줄 |
| 고아 S3 파일 | 업로드 후 기록 저장 실패 → 과금 | `media_resources.status = UPLOADING` 배치 정리 |
| 완료 취소 시 기록 연결 | record_id 조인으로 삭제 | `routine_completions.activity_record_id ON DELETE SET NULL` |

---

## 아키텍처 결정 이력 (ADR 요약)

| 번호 | 결정 | 이유 |
|------|------|------|
| BE-001 | Java 21 Virtual Thread | Pinning 방지, 동시성 단순화. `synchronized` 금지. |
| BE-002 | Testcontainers (실 DB) | Mock DB는 Spatial 쿼리 검증 불가. |
| BE-003 | RFC 7807 ProblemDetail | 표준 오류 응답, 프론트 파싱 통일. |
| BE-004 | record DTO (정적 팩토리) | 불변성 보장, `of(entity)` / `from(request)` 패턴 강제. |
| BE-005 | /api/v1/ 경로 고정 | 버전 관리. 프론트 base URL 단일 상수화 예정. |

---

## 세션 종료 시 업데이트 항목

이 파일의 **5줄 현황 요약** 섹션을 다음 내용으로 갱신한다:
- 현재 Phase 및 상태
- 마지막으로 GREEN이 된 테스트 이름
- 세션 중 내린 주요 결정
- 다음 세션의 첫 번째 구체적 행동
- 건드리면 안 되는 파일/로직

---

## 프로젝트 루트 구조 (목표)

```
paa/
├── frontend/          # React Native (Expo) — 현재 로컬 MVP 완성
├── backend/           # Spring Boot 3.4+ — Phase 3 완료, Phase 4 예정
│   ├── src/
│   │   ├── main/java/com/petyilgi/
│   │   └── test/java/com/petyilgi/
│   ├── build.gradle
│   └── docker/docker-compose.yml
├── docs/
│   ├── CONTEXT.md     ← 지금 이 파일
│   ├── PHASE_PLAN.md
│   ├── FRONTEND_STATUS.md
│   ├── ERD.md
│   ├── ADR.md
│   └── ARCHITECTURE.md
└── tasks/
    └── task-01-setup-tdd-env.md
```

---

## 미완료 작업 백로그

### Phase 4 잔여 — 미디어/S3 업로드
- **상태:** 미완료. ActivityRecord 핵심 CRUD만 완료됨.
- **남은 작업:** `V5__add_media_resources.sql`, `media_resources` 테이블, 펫 프로필 미디어 업로드 API, 기록 첨부 미디어 업로드 API.
- **첫 단계:** S3를 바로 붙일지, 로컬 테스트 대역/MinIO/LocalStack을 쓸지 결정한 뒤 RED 테스트 작성.
- **주의:** ActivityRecord CRUD를 되돌리지 말 것. `frontend/`는 백엔드 Phase 완료 전까지 수정 금지.

### Phase 5 — Routine
- **상태:** 미완료.
- **남은 작업:** `routines`, `routine_completions`, 루틴 CRUD, 오늘 할 일/이행률 API.
- **첫 단계:** `RoutineIntegrationTest` RED 작성.

### Phase 6 — Community
- **상태:** 미완료.
- **남은 작업:** `posts`, `post_likes`, 커서 페이지네이션 피드, 좋아요 토글.
- **첫 단계:** `CommunityIntegrationTest` RED 작성.
## Handover - 2026-05-09 Phase 5
- Goal: Implement Phase 5 Routine backend APIs.
- Done: Added routine CRUD, completion status update, and today summary API under `/api/v1/pets/{petId}/routines`; added `V5__add_routines.sql`; added `RoutineIntegrationTest` with 5 tests; added `tasks/task-05-routine.md`.
- Remaining: Phase 4 media upload backlog is still not implemented. Frontend integration is still pending and `frontend/` was not touched.
- Next step: If continuing backend phases, either finish Phase 4 media backlog or start Phase 6 Community with RED tests.
- Warnings: Existing `V1`-`V4` migrations were not modified. The repository had unrelated pre-existing git changes/deletions outside this task.

## Handover - 2026-05-09 Phase 6
- Goal: Implement Phase 6 Community backend APIs.
- Done: Added post creation, cursor feed, and like toggle APIs under `/api/v1/posts`; added `V6__add_community.sql`; added `CommunityIntegrationTest` with 4 tests; added `tasks/task-06-community.md`; updated `PHASE_PLAN.md`.
- Remaining: Phase 4 media upload backlog is still not implemented. Frontend integration remains pending and `frontend/` was not touched.
- Next step: Decide whether to finish the Phase 4 media backlog or start frontend API integration.
- Warnings: Existing `V1`-`V5` migrations were not modified. The repository had unrelated pre-existing git changes/deletions outside this task.

## Handover - 2026-05-09 Phase Replan
- Goal: Replan remaining work because paid S3 is not available.
- Done: Defined Phase 7 as local filesystem media storage, Phase 8 as frontend API integration, and a separate deferred deployment phase; added `tasks/task-07-local-media.md`.
- Remaining: Implement Phase 7 with TDD before touching frontend integration.
- Next step: Start Phase 7 by writing `MediaIntegrationTest` RED tests.
- Warnings: Do not add S3, MinIO, LocalStack, or cloud deployment work before Phase 8 is verified.

## Handover - 2026-05-09 Phase 7
- Goal: Implement authenticated local media storage for pet profile and activity record images.
- Done: Added `V7__add_media_resources.sql`; added media upload/read endpoints in `MediaController`; added `MediaService`, `MediaStorage`, and `LocalMediaStorage`; added `MediaIntegrationTest` and `MediaStorageFailureIntegrationTest`.
- Remaining: Phase 8 frontend API integration is still pending and `frontend/` was not touched.
- Next step: Run `./gradlew test --rerun-tasks`, then start Phase 8A API/auth client work only if regression stays green.
- Warnings: Keep S3, MinIO, LocalStack, deployment, domain, SSL, and production storage decisions deferred to the separate deployment phase.

## Handover - 2026-05-09 Phase 8
- Goal: Integrate the Expo frontend with backend APIs for auth, pets, records, routines, and community.
- Done: Added `frontend/src/services/api.ts` with typed `/api/v1` client and JWT storage; added `frontend/src/lib/auth-context.tsx`; added `frontend/app/auth.tsx`; wired `frontend/src/lib/pet-context.tsx` to backend pet/record/routine APIs and record media upload; wired `frontend/app/(tabs)/community.tsx` to backend feed/like APIs; updated onboarding and routine save flows for async backend writes; added `tasks/task-08-frontend-api-integration.md`.
- Remaining: No device/emulator manual run was performed.
- Next step: Start the Expo app with backend running and manually verify login/register, pet onboarding, record CRUD, routine CRUD, community feed/like, and poop photo upload/display.
- Warnings: Backend logout was not yet available in the original Phase 8 handover. Keep S3, MinIO, LocalStack, deployment, domain, SSL, and production storage decisions deferred to the separate deployment phase.

## Handover - 2026-05-09 Phase 8 Stabilization
- Goal: Stabilize Phase 8 before manual Expo verification and separate deployment from numbered phases.
- Done: Added backend `POST /api/v1/auth/logout`; refresh tokens are deleted when present and unknown tokens are no-op `204 No Content`. Frontend async pet/record/routine write functions are typed as promises, and visible save/delete flows await backend writes before success UI. `build.gradle` includes `testRuntimeOnly 'org.junit.platform:junit-platform-launcher'` to remove the Gradle deprecation warning.
- Remaining: Expo physical device/emulator manual verification is still pending.
- Next step: Run the backend, set `EXPO_PUBLIC_API_BASE_URL=http://<PC-LAN-IP>:8080` for physical devices, then manually verify register/login, pet onboarding, record CRUD, routine CRUD, community feed/like, poop photo upload/display, and logout/re-entry.
- Warnings: Deployment, S3, MinIO, LocalStack, domain, SSL, and production storage decisions are deferred to the separate deployment phase, not a numbered phase.

## Handover - 2026-05-10 Korean/Text Integrity + Routine Template Recovery
- Goal: Audit Korean text for real mojibake, prevent future false positives from Windows console output, and restore failing routine template tests.
- Done: Added `scripts/check-korean-mojibake.ps1`; updated `docs/AI_MISTAKES.md` and `docs/FRONTEND_STATUS.md`; aligned `backend/src/test/resources/init-test.sql` with `V8__add_routine_record_template.sql` by adding `routines.note` and `routines.detail`.
- Remaining: Expo physical device/emulator manual verification is still pending.
- Next step: Run backend and Expo together, then manually verify register/login, pet onboarding, record CRUD, routine CRUD, community feed/like, poop photo upload/display, and logout/re-entry.
- Warnings: Run the mojibake scanner with `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1` on Windows PowerShell. Do not rewrite Korean files based only on default `Get-Content` display.

## Handover - 2026-05-10 Frontend BottomSheet Flicker Stabilization
- Goal: Reduce flicker on home -> records -> add -> activity type selection and related record/routine BottomSheet mutations.
- Done: Stabilized `RecordModal` with fixed snap point, type/detail steps, delayed create after sheet close, and detail back navigation. Delayed record edit/delete in `frontend/app/records.tsx` until the sheet closes. Delayed routine create/update/delete in `frontend/app/routine.tsx` until the editor sheet closes and removed the old delete phase state. Memoized `PetProvider` actions/value in `frontend/src/lib/pet-context.tsx`. Fixed unstable keys in routine times/weekdays and poop photo thumbnails.
- Remaining: Manual Expo device/emulator verification is still pending for the flicker paths.
- Next step: Run Expo with backend available, then manually check home quick record, records add/type selection/save, record edit/delete, routine create/update/delete, and routine delete followed by `+ 새 루틴 추가`.
- Warnings: Frontend is currently untracked in git from this repository state, so `git diff -- frontend/...` does not show these file changes. Keep using UTF-8 reads/scans for Korean text.
