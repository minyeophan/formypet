# 백엔드 실사 목록

> 기준일: 2026-06-27  
> 목적: 백엔드 전면 재작성 또는 정리 전에 현재 API, 테이블, 테스트, 프론트 연결 상태를 고정한다.  
> 범위: 백엔드 구현 파일, Flyway 마이그레이션, 통합 테스트, 프론트 서비스 호출 지점 기준. 애플리케이션 코드는 수정하지 않았다.

## 상태 범례

| 상태 | 의미 |
|------|------|
| 유지 | 백엔드 API, 테이블, 테스트, 프론트 호출이 대체로 맞물려 있다. |
| 일부 연결 | 백엔드 기능은 있으나 프론트 진입점 또는 화면 연결이 일부만 있다. |
| 프론트만 있음 | 프론트 화면 또는 route는 있으나 백엔드 API/테이블 계약이 없다. |
| 백엔드만 있음 | API/테이블/테스트는 있으나 현재 주요 프론트 UI에서 쓰지 않는다. |
| 계약 애매 | 프론트와 백엔드 이름 또는 데이터 모델이 맞지 않아 정리가 필요하다. |
| 미구현 | 현재 백엔드 도메인/API/테이블이 없다. |

## 도메인별 요약

| 도메인 | 백엔드 API | 주요 테이블 | 테스트 | 프론트 연결 | 상태 | 메모 |
|--------|------------|-------------|--------|-------------|------|------|
| 인증 | 있음 | `users`, `refresh_tokens`, `oauth_accounts` | 있음 | 호출 중 | 유지 | 로컬 회원가입/로그인, 카카오 로그인, refresh rotation, logout 구현. |
| 사용자 프로필 | 있음 | `users.profile_media_id`, `media_resources` | 있음 | 조회/로그아웃 흐름에서 사용, 프로필 저장 UI는 약함 | 일부 연결 | `GET/PATCH /users/me`, 프로필 이미지 업로드 구현. |
| 펫 | 있음 | `pets`, `media_resources` | 있음 | 호출 중 | 유지 | 등록, 목록, 수정, 소프트삭제, 프로필 사진 구현. |
| 기록 | 있음 | `activity_records`, 타입별 detail 테이블 | 있음 | 호출 중 | 유지 | 9개 현재 타입만 허용하며 제거 타입은 400으로 거부한다. |
| 루틴 | 있음 | `routines`, `routine_completions` | 있음 | 생성/삭제/오늘 루틴/완료 체크 연결 | 일부 연결 | 수정 API는 있으나 주요 수정 UI 진입이 약함. |
| 커뮤니티 | 있음 | `posts`, `post_likes`, `post_media`, `post_polls`, `post_poll_options`, `post_poll_votes`, `post_comments` | 있음 | 피드/글쓰기/좋아요/상세/투표/댓글·답글 연결 | 일부 연결 | 백엔드 제목·본문 검색은 구현됐고 검색 UI·알림·카테고리 필터와 댓글 수정·삭제·신고는 후속 범위. |
| 미디어 | 있음 | `media_resources`, `media_cleanup_queue`, `post_media` | 있음 | 호출 중 | 유지 | 프로필·기록·커뮤니티 미디어와 인증/공개 조회 경로를 제공한다. |
| 지갑/지출 | 있음 | `wallet_expenses` | 있음 | 생성/목록/요약/상세/수정/삭제 연결 | 일부 연결 | 항목·사진 첨부는 후속 범위. |
| 일정 | 있음 | `care_schedules` | 있음 | 생성/목록/상세/수정/삭제 연결 | 일부 연결 | 지도 검색과 알림 실행은 후속 범위. |
| 공간 테스트 | API 없음 | `spatial_test` | 있음 | 없음 | 백엔드만 있음 | MySQL spatial 검증용 테스트 테이블. |

## API 목록

### 공통

| 메서드 | 경로 | 상태 | 프론트 호출 |
|--------|------|------|-------------|
| GET | `/api/v1/health` | 유지 | 직접 호출 확인 없음 |

### 인증

| 메서드 | 경로 | 요청 | 응답 | 상태 | 프론트 호출 |
|--------|------|------|------|------|-------------|
| POST | `/api/v1/auth/register` | `email`, `password`, `nickname` | `accessToken`, `refreshToken` | 유지 | `AuthService.register()` |
| POST | `/api/v1/auth/login` | `email`, `password` | `accessToken`, `refreshToken` | 유지 | `AuthService.login()` |
| POST | `/api/v1/auth/kakao` | `accessToken` | `accessToken`, `refreshToken` | 유지 | `AuthService.loginWithKakao()` |
| POST | `/api/v1/auth/refresh` | `refreshToken` | 새 `accessToken`, `refreshToken` | 유지 | `api_client.dart` 401 refresh |
| POST | `/api/v1/auth/logout` | `refreshToken` | 204 | 유지 | `AuthService.logout()` |

### 사용자 프로필

| 메서드 | 경로 | 요청 | 응답 | 상태 | 프론트 호출 |
|--------|------|------|------|------|-------------|
| GET | `/api/v1/users/me` | 없음 | `email`, `nickname`, `profileImageUrl`, `registrationSource` | 유지 | 로그인 후 `getProfile()` |
| PATCH | `/api/v1/users/me` | `nickname` | 사용자 프로필 | 일부 연결 | 서비스는 있으나 저장 UI는 약함 |
| POST | `/api/v1/users/me/profile-image` | multipart `file` | 사용자 프로필 | 일부 연결 | 프로필 이미지 서비스/테스트 있음 |

### 펫

| 메서드 | 경로 | 요청/필터 | 응답 | 상태 | 프론트 호출 |
|--------|------|-----------|------|------|-------------|
| POST | `/api/v1/pets` | `PetCreateRequest` | `PetResponse` | 유지 | `PetService.createPet()` |
| GET | `/api/v1/pets` | 없음 | `List<PetResponse>` | 유지 | `PetService.getPets()` |
| PUT | `/api/v1/pets/{id}` | `PetUpdateRequest` | `PetResponse` | 유지 | `PetService.updatePet()` |
| DELETE | `/api/v1/pets/{id}` | 없음 | 204 | 유지 | `PetService.deletePet()` |

주의: 단건 조회 `GET /api/v1/pets/{id}`는 없다. 프론트는 보유한 목록 상태에서 펫을 찾는다.

### 기록

| 메서드 | 경로 | 요청/필터 | 응답 | 상태 | 프론트 호출 |
|--------|------|-----------|------|------|-------------|
| POST | `/api/v1/pets/{petId}/records` | `typeId`, `date`, `time`, `routineId`, `note`, `detail` | `ActivityRecordResponse` | 유지 | `RecordService.createRecord()` |
| GET | `/api/v1/pets/{petId}/records` | `date`, `typeId`, `limit` | `List<ActivityRecordResponse>` | 유지 | `RecordService.getRecords()` |
| GET | `/api/v1/pets/{petId}/records/{recordId}` | 없음 | `ActivityRecordResponse` | 유지 | `RecordService.getRecord()` |
| PUT | `/api/v1/pets/{petId}/records/{recordId}` | partial update | `ActivityRecordResponse` | 유지 | `RecordService.updateRecord()` |
| DELETE | `/api/v1/pets/{petId}/records/{recordId}` | 없음 | 204 | 유지 | `RecordService.deleteRecord()` |

### 루틴

| 메서드 | 경로 | 요청/필터 | 응답 | 상태 | 프론트 호출 |
|--------|------|-----------|------|------|-------------|
| POST | `/api/v1/pets/{petId}/routines` | `RoutineCreateRequest` | `RoutineResponse` | 유지 | `RoutineService.createRoutine()` |
| GET | `/api/v1/pets/{petId}/routines` | 없음 | `List<RoutineResponse>` | 유지 | `RoutineService.getRoutines()` |
| GET | `/api/v1/pets/{petId}/routines/today` | optional `date` | `TodayRoutineResponse` | 유지 | `RoutineService.getTodayRoutines()` |
| PUT | `/api/v1/pets/{petId}/routines/{routineId}` | `RoutineUpdateRequest` | `RoutineResponse` | 일부 연결 | 서비스/provider 있음, 주요 UI 진입 약함 |
| PATCH | `/api/v1/pets/{petId}/routines/{routineId}/completions/{date}` | `status` | `RoutineCompletionResponse` | 유지 | `RoutineService.patchCompletion()` |
| DELETE | `/api/v1/pets/{petId}/routines/{routineId}` | 없음 | 204 | 유지 | `RoutineService.deleteRoutine()` |

### 커뮤니티

| 메서드 | 경로 | 요청/필터 | 응답 | 상태 | 프론트 호출 |
|--------|------|-----------|------|------|-------------|
| POST | `/api/v1/posts` | multipart `payload`, repeated `files` | `PostResponse` | 일부 연결 | `CommunityService.createPost()` |
| GET | `/api/v1/posts` | `keyword`, `category`, `sort`, `cursor`, `limit` | `PostFeedResponse` | 유지 | `CommunityService.getFeed()` |
| GET | `/api/v1/posts/{postId}` | 없음 | `PostResponse` | 유지 | `CommunityService.getPost()` |
| GET | `/api/v1/posts/{postId}/comments` | `cursor`, `limit`, `replyLimit` | root 댓글 feed와 최신 답글 | 유지 | `CommunityService.getComments()` |
| GET | `/api/v1/posts/{postId}/comments/{commentId}` | `replyLimit` | root thread | 유지 | `CommunityService.getCommentThread()` |
| GET | `/api/v1/posts/{postId}/comments/{commentId}/replies` | `cursor`, `limit` | 시간순 답글 feed | 유지 | `CommunityService.getReplies()` |
| POST | `/api/v1/posts/{postId}/comments` | `content`, optional `parentCommentId` | `PostCommentResponse` | 유지 | `CommunityService.createComment()` |
| POST | `/api/v1/posts/{postId}/like` | 없음 | `PostLikeResponse` | 유지 | `CommunityService.toggleLike()` |
| POST | `/api/v1/posts/{postId}/poll/options/{optionId}/vote` | 없음 | `PostResponse` | 유지 | `CommunityService.vote()` |

### 지갑/지출 API

| 메서드 | 경로 | 요청/필터 | 응답 | 상태 | 프론트 호출 |
|--------|------|-----------|------|------|-------------|
| POST | `/api/v1/pets/{petId}/wallet/expenses` | 지출 생성 payload | `WalletExpenseResponse` | 유지 | `WalletExpenseService.createExpense()` |
| GET | `/api/v1/pets/{petId}/wallet/expenses` | 기간·cursor 필터 | 지출 목록 | 유지 | `WalletExpenseService.listExpenses()` |
| GET | `/api/v1/pets/{petId}/wallet/expenses/summary` | 기간 필터 | 지출 요약 | 유지 | `WalletExpenseService.getSummary()` |
| GET | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | 없음 | `WalletExpenseResponse` | 유지 | `WalletExpenseService.getExpense()` |
| PUT | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | 지출 수정 payload | `WalletExpenseResponse` | 유지 | `WalletExpenseService.updateExpense()` |
| DELETE | `/api/v1/pets/{petId}/wallet/expenses/{expenseId}` | 없음 | 204 | 유지 | `WalletExpenseService.deleteExpense()` |

### 일정 API

| 메서드 | 경로 | 요청/필터 | 응답 | 상태 | 프론트 호출 |
|--------|------|-----------|------|------|-------------|
| POST | `/api/v1/pets/{petId}/care-schedules` | 일정 생성 payload | `CareScheduleResponse` | 유지 | `CareScheduleService.createSchedule()` |
| GET | `/api/v1/pets/{petId}/care-schedules` | 날짜 범위·카테고리 | 일정 목록 | 유지 | `CareScheduleService.getSchedules()` |
| GET | `/api/v1/pets/{petId}/care-schedules/{scheduleId}` | 없음 | `CareScheduleResponse` | 유지 | `CareScheduleService.getSchedule()` |
| PUT | `/api/v1/pets/{petId}/care-schedules/{scheduleId}` | 일정 수정 payload | `CareScheduleResponse` | 유지 | `CareScheduleService.updateSchedule()` |
| DELETE | `/api/v1/pets/{petId}/care-schedules/{scheduleId}` | 없음 | 204 | 유지 | `CareScheduleService.deleteSchedule()` |

### 미디어

| 메서드 | 경로 | 요청 | 응답 | 상태 | 프론트 호출 |
|--------|------|------|------|------|-------------|
| POST | `/api/v1/pets/{petId}/media` | multipart `file` | `MediaResponse` | 유지 | `MediaService.uploadPetPhoto()` |
| POST | `/api/v1/pets/{petId}/records/{recordId}/media` | multipart `file` | `MediaResponse` | 유지 | `RecordService` media upload |
| GET | `/api/v1/media/{mediaId}` | 인증 필요 | bytes | 유지 | `AuthenticatedNetworkImage`, private media URL |
| GET | `/api/v1/public/media/{mediaId}` | 인증 불필요 | bytes | 유지 | community public media URL |

### 지갑/지출

| 항목 | 현재 상태 |
|------|-----------|
| 지갑 메인 route | `/wallet` 구현 |
| 비용 추가 route | `/wallet/expenses/new` 구현 |
| 비용 상세 route | `/wallet/expenses/{recordId}` 구현 |
| 비용 수정 route | `/wallet/expenses/{recordId}/edit` 구현 |
| 레거시 redirect | `/records/expense/new` redirect 제거 완료 |
| 백엔드 API | `/api/v1/pets/{petId}/wallet/expenses` CRUD와 summary |
| 백엔드 테이블 | `wallet_expenses` |
| 현재 프론트 저장 방식 | `WalletExpenseService`와 provider를 통한 전용 API 호출 |
| 후속 범위 | 지출 항목·사진 첨부 |

### 일정

| 항목 | 현재 상태 |
|------|-----------|
| 일정 route | `/routine/schedule/new`, `/routine/schedule/{id}`, `/routine/schedule/{id}/edit` 구현 |
| 백엔드 API | `/api/v1/pets/{petId}/care-schedules` CRUD |
| 백엔드 테이블 | `care_schedules` |
| 저장 동작 | 생성·수정·삭제 후 선택 날짜 또는 상세 route로 이동 |
| 후속 범위 | 지도 검색과 알림 실행 |

## 테이블 목록

| 테이블 | 도메인 | 용도 | 상태 |
|--------|--------|------|------|
| `users` | 인증/사용자 | 계정, 닉네임, 가입 소스, 프로필 미디어 ID | 유지 |
| `oauth_accounts` | 인증 | OAuth provider 계정 연결 | 유지 |
| `refresh_tokens` | 인증 | refresh token 저장/rotation | 유지 |
| `pets` | 펫 | 사용자별 반려동물 프로필, 소프트삭제 | 유지 |
| `activity_types` | 기록 | 기록 타입 마스터 | 유지: `meal`, `water`, `poop`, `walk`, `medicine`, `weight`, `vet`, `diary`, `etc` |
| `activity_records` | 기록 | 기록 공통 헤더 | 유지 |
| `record_meal` | 기록 | 급식 detail | 유지 |
| `record_water` | 기록 | 음수 detail | 유지 |
| `record_medicine` | 기록 | 복약 detail | 유지 |
| `record_poop` | 기록 | 배변 detail | 유지 |
| `record_walk` | 기록 | 산책 detail, 현재 sleep/play duration도 재사용 | 계약 애매 |
| `record_weight` | 기록 | 체중 detail | 유지 |
| `record_vet` | 기록 | 병원/검진 detail | 유지 |
| `routines` | 루틴 | 반복 루틴 정의 | 유지 |
| `routine_completions` | 루틴 | 날짜별 루틴 완료 상태 | 유지 |
| `care_schedules` | 일정 | 반려동물 일정 범위·장소·알림 설정 | 유지 |
| `wallet_expenses` | 지갑 | 반려동물별 지출과 카테고리·금액 | 유지 |
| `posts` | 커뮤니티 | 게시글 | 유지 |
| `post_likes` | 커뮤니티 | 게시글 좋아요 | 유지 |
| `post_media` | 커뮤니티/미디어 | 게시글 이미지 연결 | 유지 |
| `post_polls` | 커뮤니티 | 게시글 투표 | 일부 연결 |
| `post_poll_options` | 커뮤니티 | 투표 선택지 | 일부 연결 |
| `post_poll_votes` | 커뮤니티 | 사용자 투표 기록 | 유지 |
| `post_comments` | 커뮤니티 | root 댓글과 한 단계 답글 | 유지 |
| `media_resources` | 미디어 | 로컬 저장소 파일 메타데이터 | 유지 |
| `media_cleanup_queue` | 미디어 | DB 삭제 뒤 파일 삭제 재시도용 storage key | 유지 |
| `spatial_test` | 테스트 | MySQL spatial 검증 | 백엔드만 있음 |

## 기록 타입 현황

| typeId | 백엔드 지원 | detail 저장 | 프론트 주요 진입 | 상태 | 메모 |
|--------|-------------|-------------|------------------|------|------|
| `meal` | 예 | `record_meal` | 예 | 유지 | 급식 입력, 사진 1장 첨부 지원. |
| `water` | 예 | `record_water.amount` | 예 | 유지 | UI는 ml 고정, 백엔드는 amount만 저장. |
| `poop` | 예 | `record_poop` | 예 | 유지 | 배변 입력. |
| `walk` | 예 | `record_walk` | 예 | 유지 | 위치 필드는 있으나 프론트 사용 범위 확인 필요. |
| `medicine` | 예 | `record_medicine` | 예 | 유지 | 복약 입력. |
| `weight` | 예 | `record_weight` | 예 | 유지 | 성장/체중 표시와 연결. |
| `vet` | 예 | `record_vet` | 예 | 유지 | 병원 입력. |
| `diary` | 예 | detail 없음, `note`만 | 예 | 유지 | `V12` 추가. |
| `etc` | 예 | detail 없음, `note`만 | 예 | 유지 | `V13` 추가. |
| `sleep` | 예 | `record_walk.duration` 재사용 | 주요 진입 없음 | 백엔드만 있음 | 타입 유지 여부 결정 필요. |
| `play` | 예 | `record_walk.duration` 재사용 | 주요 진입 없음 | 백엔드만 있음 | 타입 유지 여부 결정 필요. |
| `checkup` | 예 | `record_vet` 재사용 | 현재 기록 그리드에서 숨김 | 백엔드만 있음 | `vet`과 통합할지 결정 필요. |
| `expense` | 아니오 | 없음 | wallet UI가 저장 시도 | 계약 애매 | 지갑 전용 도메인으로 분리 권장. |
| `bath` | 아니오 | 없음 | 제거됨 | 제거 완료 | 백엔드 미지원. 프론트 quick/detail 잔재 제거 완료. |
| `groom` | 아니오 | 없음 | 제거됨 | 제거 완료 | 백엔드 미지원. 프론트 quick/detail 잔재 제거 완료. |

## 테스트 목록

| 테스트 파일 | 도메인 | 주요 검증 |
|-------------|--------|-----------|
| `AuthIntegrationTest` | 인증 | 회원가입, 로그인 실패, refresh rotation, logout, 보호 API 401, 카카오 로그인 흐름 |
| `RestClientKakaoUserClientTest` | 인증 | 카카오 응답 파싱, 이메일/닉네임 누락 허용, 401/5xx/network 실패 변환 |
| `UserProfileIntegrationTest` | 사용자 프로필 | 내 프로필 조회, 닉네임 수정, 프로필 이미지 업로드, 인증 필요 |
| `PetIntegrationTest` | 펫 | 등록, birthDate null, 확장 필드/색상, 목록, 최신 프로필 이미지, 수정, 소프트삭제, 소유권 |
| `ActivityRecordIntegrationTest` | 기록 | 생성, routineId 연결, diary/etc note-only, 단건 조회, 소유권, 타입별 생성, 필터, 수정, 삭제 |
| `RoutineIntegrationTest` | 루틴 | daily/weekly 생성, 템플릿 수정, 완료 상태 변경, 오늘 완료율, 삭제 |
| `CommunityIntegrationTest` | 커뮤니티 | multipart 게시글, latest/popular cursor, 좋아요, 투표, 댓글·답글 limit/cursor, parent 검증, count와 프로필 URL |
| `FlywayMigrationTest` | Flyway | 빈 MySQL 8 DB에서 V1부터 최신 migration까지 실행 |
| `MediaIntegrationTest` | 미디어 | pet/record media, record 응답 media URL, record 삭제 후 파일 정리, webp content type, private/public 접근, 용량/확장자 검증 |
| `MediaStorageFailureIntegrationTest` | 미디어 | 저장 실패 시 DB row 미삽입 |
| `MediaCleanupRunnerTest` | 미디어 | 파일 삭제 성공 뒤 queue 삭제, 저장소 실패 시 queue 보존 |
| `DeprecatedActivityTypesMigrationTest` | Flyway | V16 데이터에서 V17 적용 후 레거시 기록·루틴·미디어 DB 행 제거와 queue 확인 |
| `OpenApiIntegrationTest` | 문서 | Springdoc API 문서 렌더링 |
| `SpatialQueryIntegrationTest` | 공간 테스트 | MySQL spatial distance, SRID, 반경 검색 |

검증 메모: 2026-06-27 `CommunityIntegrationTest`와 빈 DB `FlywayMigrationTest`를 `--rerun-tasks`로 실행해 GREEN을 확인했다. `WalletExpenseIntegrationTest`와 `CareScheduleIntegrationTest`는 각 기능 구현 시 선택 테스트가 GREEN이었으며, 백엔드 전체 suite의 마지막 기록은 `docs/CONTEXT.md`를 기준으로 한다.

## 프론트 연결 요약

| 프론트 파일 | 호출 도메인 | 호출 API |
|-------------|-------------|----------|
| `frontend/lib/services/auth_service.dart` | 인증/프로필 | auth register/login/kakao/logout, users/me |
| `frontend/lib/core/api_client.dart` | 인증 | auth refresh |
| `frontend/lib/services/pet_service.dart` | 펫 | pets CRUD |
| `frontend/lib/services/media_service.dart` | 미디어 | pet photo upload, private/public URL helper |
| `frontend/lib/services/record_service.dart` | 기록/기록 미디어 | records CRUD, record media upload |
| `frontend/lib/services/routine_service.dart` | 루틴 | routines CRUD, today, completion patch |
| `frontend/lib/services/community_service.dart` | 커뮤니티 | posts feed/create/detail/like/vote, root/thread/reply 조회와 댓글·답글 작성 |
| `frontend/lib/services/wallet_expense_service.dart` | 지갑 | wallet expenses CRUD와 summary |
| `frontend/lib/services/care_schedule_service.dart` | 일정 | care schedules CRUD |
| `frontend/lib/providers/pet_provider.dart` | 펫/기록/루틴 | 사용자 인증 후 pets, records, routines, today routines 로드 |
| `frontend/lib/providers/community_provider.dart` | 커뮤니티 | feed load, load more, like, vote, create post/comment/reply와 게시글 count 캐시 동기화 |
| `frontend/lib/screens/wallet/*` | 지갑 | wallet expense provider/service 기반 목록·요약·생성·상세·수정·삭제 |

## 죽은 코드 및 애매한 계약

| 항목 | 구분 | 근거 | 권장 처리 |
|------|------|------|-----------|
| `/records/expense/new` | 제거된 레거시 route | 더 이상 `/wallet/expenses/new`로 redirect하지 않음 | `/wallet/expenses/new` 직접 진입 유지 |
| `sleep`, `play` 기록 타입 | 백엔드만 있음 | 백엔드는 지원하나 현재 주요 기록 그리드 진입 없음 | 유지/숨김/제거 정책 결정 |
| `checkup` 기록 타입 | 백엔드만 있음 | 백엔드는 `record_vet` 재사용, 프론트 기록 그리드에서 숨김 | `vet`과 통합 여부 결정 |
| `bath`, `groom` | 제거 완료 | 프론트 quick/detail 잔재 제거, 백엔드 미지원 | 새 기록 타입으로 다시 열지 않음 |
| 루틴 수정 | 일부 연결 | 백엔드/service/provider 있음, 주요 수정 UI 진입 약함 | UI 연결 또는 보류 문서화 |

## 다음 문서 작업 제안

1. `docs/BACKEND_DOMAIN_DECISIONS.md`
   - `sleep/play/checkup` 처리 정책을 결정한다. `bath/groom`은 제거 완료 상태로 유지한다.
2. `docs/TARGET_ERD.md`
   - 현재 ERD와 별도로 목표 ERD를 작성한다.
   - 현재 지갑·일정·댓글 답글 구조를 기준 ERD와 동기화한다.
3. `docs/API_CONTRACT.md`
   - 프론트와 백엔드가 같은 API 이름, DTO 필드, 응답 형태를 쓰도록 고정한다.
4. `docs/BACKEND_MIGRATION_PLAN.md`
   - 새 Flyway 번호와 테스트 스키마 반영 순서를 정한다.
