# 프론트엔드 구현 현황 및 백엔드 Sync 체크

> 마지막 갱신: 2026-06-01
> 이 문서는 **현재 프론트 구현 기준** 현황 문서다. 확정 API 계약서가 아니며, 백엔드 계약 확정 전 확인이 필요한 항목은 `Backend sync needed`에 남긴다. 앱 코드나 백엔드 코드가 바뀌면 관련 섹션만 갱신한다.

## 상태 표기

| 표기 | 의미 |
|------|------|
| ✅ 구현됨 | 화면 또는 프론트 로직이 있음 |
| 🔌 연동됨 | 현재 서비스/provider 코드가 API를 호출 중 |
| 🟡 Sync 필요 | 프론트 요구는 있으나 백엔드와 재확정 필요 |
| ❌ 제외 | MVP 또는 현재 범위 밖 |

## 목차

- [1. 인증](#1-인증)
- [2. 반려동물 프로필](#2-반려동물-프로필)
- [3. 활동 기록](#3-활동-기록)
- [4. 루틴](#4-루틴)
- [5. 커뮤니티](#5-커뮤니티)
- [6. 프론트 모델 참고](#6-프론트-모델-참고)
- [7. 남은 검증](#7-남은-검증)
- [8. AI 업데이트 규칙](#8-ai-업데이트-규칙)

---

## 1. 인증

### 요약

`AuthService`, `AuthNotifier`, `api_client.dart`, `secure_storage.dart` 기준으로 JWT 인증 흐름이 연결되어 있다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 회원가입 | 🔌 연동됨 | `providers/auth_provider.dart`, `services/auth_service.dart` |
| 로그인 | 🔌 연동됨 | `providers/auth_provider.dart`, `services/auth_service.dart` |
| 토큰 갱신 | 🔌 연동됨 | `core/api_client.dart`에서 401 응답 시 refresh 처리 |
| 로그아웃 | 🔌 연동됨 | `AuthService.logout()` 호출 후 로컬 토큰 삭제 |
| 토큰 저장 | ✅ 구현됨 | `flutter_secure_storage` 기반 access/refresh 저장 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 회원가입 | `POST /api/v1/auth/register` |
| 로그인 | `POST /api/v1/auth/login` |
| 토큰 갱신 | `POST /api/v1/auth/refresh`, `refreshToken` |
| 로그아웃 | `POST /api/v1/auth/logout`, `refreshToken` |

### Backend sync needed

- 현재 문서 기준 추가 sync 항목 없음.

---

## 2. 반려동물 프로필

### 요약

펫 CRUD, 활성 펫 전환, 프로필 사진 업로드, 생년월일 입력 화면이 구현되어 있다. CRUD와 사진 업로드는 서비스 코드에서 API를 호출한다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 펫 목록 조회 | 🔌 연동됨 | `providers/pet_provider.dart`, `services/pet_service.dart` |
| 펫 등록 | 🔌 연동됨 | `screens/onboarding/onboarding_screen.dart`, `PetService.createPet()` |
| 펫 수정 | 🔌 연동됨 | `screens/pet/pet_edit_screen.dart`, `PetService.updatePet()` |
| 펫 삭제 | 🔌 연동됨 | `PetService.deletePet()` |
| 활성 펫 전환 | ✅ 구현됨 | provider 상태로 유지 |
| 펫 프로필 사진 | 🔌 연동됨 | `services/media_service.dart` |
| 생년월일 입력 | ✅ 구현됨 | `core/calendar_ranges.dart`, 선택 범위는 `1950-01-01`부터 오늘까지 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 목록 조회 | `GET /api/v1/pets` |
| 등록 | `POST /api/v1/pets` |
| 수정 | `PUT /api/v1/pets/{id}` |
| 삭제 | `DELETE /api/v1/pets/{id}` |
| 프로필 사진 | `POST /api/v1/pets/{petId}/media` |
| 생년월일 | `birthDate: YYYY-MM-DD` |

### Backend sync needed

- `accentColor`, `bgLight`를 서버 생성값으로 둘지, 클라이언트 선택값으로 유지할지 확인 필요.
- `gender`, `weight`, `animalRegistrationNumber`, `neutered`, `specialNotes`, `diseases`, `profileImageUrl`의 nullable 정책 확인 필요.

---

## 3. 활동 기록

### 요약

빠른 기록, 타입별 전체 화면 기록, 목록/필터, 수정/삭제, 미디어 업로드 화면과 로직이 있다. 저장 후보 타입과 화면 표시/임시 타입은 분리해서 봐야 한다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 빠른 기록 | 🔌 연동됨 | `widgets/record_modal.dart`, `core/record_utils.dart` |
| 타입별 기록 화면 | 🔌 연동됨 | `screens/records/meal_record_screen.dart`, `screens/records/record_category_form_screen.dart`; `water`, `diary` 포함 |
| 목록/날짜 필터 | ✅ 구현됨 | `screens/records/records_screen.dart`, `activity_tab.dart`, `health_tab.dart` |
| 타입별 필터 | ✅ 구현됨 | 클라이언트 records 상태 기준 필터 |
| 오늘 기록 홈 카드 | ✅ 구현됨 | `screens/home/recent_records_card.dart` |
| 성장/체중 그래프 | ✅ 구현됨 | `screens/records/growth_tab.dart` |
| 수정/삭제 | 🔌 연동됨 | `widgets/record_detail_form.dart`, `providers/pet_provider.dart` |
| 미디어 업로드 | 🔌 연동됨 | `services/record_service.dart`, 기록 생성 후 media 업로드 |
| 날짜/시간 입력 | ✅ 구현됨 | `widgets/record_inputs/record_date_time_pickers.dart`, `core/calendar_ranges.dart` |
| 숫자 입력 preview | ✅ 구현됨 | `widgets/record_inputs/record_number_input.dart`, `record_picker_sheet.dart` |
| 저장 후 이동 | ✅ 구현됨 | 급식/카테고리 기록 저장 성공 후 `/records`로 이동 |
| 급식/배변 메모 | 🔌 연동됨 | `meal`, `poop` payload의 `note`에 저장 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 목록 조회 | `GET /api/v1/pets/{petId}/records` |
| 생성 | `POST /api/v1/pets/{petId}/records` |
| 수정 | `PUT /api/v1/pets/{petId}/records/{recordId}` |
| 상세 조회 | `GET /api/v1/pets/{petId}/records/{recordId}` |
| 삭제 | `DELETE /api/v1/pets/{petId}/records/{recordId}` |
| 미디어 업로드 | `POST /api/v1/pets/{petId}/records/{recordId}/media` |
| 날짜 필터 후보 | `GET ?date=YYYY-MM-DD` |
| 타입 필터 후보 | `GET ?typeId=meal` |

### 저장 후보 타입

| typeId | 상태 | 비고 |
|--------|------|------|
| `meal` | 🔌 연동됨 | 급식 |
| `water` | 🔌 연동됨 | 음수 |
| `poop` | 🔌 연동됨 | 배변 |
| `walk` | 🔌 연동됨 | 산책 |
| `sleep` | 🔌 연동됨 | 수면 |
| `play` | 🔌 연동됨 | 놀이 |
| `medicine` | 🔌 연동됨 | 투약/영양 |
| `weight` | 🔌 연동됨 | 체중 |
| `vet` | 🔌 연동됨 | 병원 |
| `checkup` | 🔌 연동됨 | 검진/접종 |
| `diary` | 🔌 연동됨 | 일기, `activity_records.note`만 사용 |

### 화면 표시/임시 타입

| typeId | 상태 | 비고 |
|--------|------|------|
| `bath` | 🟡 Sync 필요 | 빠른 기록 화면에는 있으나 `kSupportedTypeIds`에서 제외됨 |
| `groom` | 🟡 Sync 필요 | 빠른 기록 화면에는 있으나 `kSupportedTypeIds`에서 제외됨 |
| `expense` | 🟡 Sync 필요 | 별도 지출 화면이 있으나 활동 기록 API 타입으로 확정 필요 |
| `etc` | 🟡 Sync 필요 | 전체 기록 화면 표시 후보, 저장 계약 미확정 |

### 지갑/지출 UI

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 홈 지갑 진입 | ✅ 구현됨 | 홈 `지갑` 메뉴 → `/wallet` |
| 지갑 요약 | ✅ 구현됨 | `screens/records/expense_wallet_screen.dart`, records 상태의 `expense` 항목 집계 |
| 지출 리포트 | ✅ 구현됨 | `/wallet/report`, 카테고리 합계와 지출 목록 표시 |
| 비용 추가 화면 | ✅ 구현됨 | `/records/expense/new`, 금액/카테고리/기본 정보/메모 UI |
| 지출 저장 | 🟡 Sync 필요 | 저장 버튼은 현재 `준비중`; 백엔드 저장 API/typeId 미확정 |

### Backend sync needed

- `ActivityRecord.detail` 키는 프론트 입력 필드 기준이며, 백엔드 개발 시 재정렬 필요.
- 전체 화면 폼 기준 현재 detail: `meal(foodType, servedAmount, consumedPercent, product?, brand?, feedingMethod?)`, `water(amount)`, `walk(distance)`, `poop(poopShape, poopColor)`, `weight(weight)`, `vet(vetClinicName, vetVisitReason, vetTreatment)`, `medicine(medicineName, dosage)`, `diary`는 detail 없이 `note`만 사용.
- `water` 단위는 UI에서 `ml` 고정값으로 표시하고, 백엔드에는 `amount`만 저장한다.
- `bath`, `groom`, `expense`, `etc`를 활동 기록 타입으로 편입할지, 별도 도메인으로 둘지 결정 필요.
- 목록 API에서 날짜/타입/limit 필터를 서버 쿼리로 제공할지, 현재처럼 클라이언트 필터를 유지할지 확인 필요.
- 기록 생성 후 미디어 업로드 실패 시 프론트는 생성된 기록 삭제로 rollback을 시도한다. 백엔드 트랜잭션/정리 정책 확인 필요.

---

## 4. 루틴

### 요약

루틴 CRUD service와 완료 체크가 구현되어 있고, `RoutineScreen`은 달력/일정 탭과 월간 보기로 구성된다. 서버 `label`은 루틴 이름, `note`는 메모로 분리해 표시한다. 홈 화면의 오늘 루틴도 provider 상태를 사용한다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 루틴 목록 | 🔌 연동됨 | `services/routine_service.dart`, `providers/pet_provider.dart` |
| 루틴 생성 | 🔌 연동됨 | `/routine/new`, 백엔드 필수 `label`을 포함해 `PetNotifier.addRoutine()` 호출 |
| 루틴 수정 service | 🔌 연동됨 | `RoutineService.updateRoutine()`, `PetNotifier.updateRoutine()` |
| 루틴 삭제 | 🔌 연동됨 | `routine/routine_screen.dart` |
| 오늘 루틴 | 🔌 연동됨 | `RoutineService.getTodayRoutines()` |
| 완료 체크 | 🔌 연동됨 | completion API 호출 |
| 반복 유형 | ✅ 구현됨 | `daily`, `weekly`, `biweekly`, `monthly`; 백엔드 규칙과 같은 날짜 helper 사용 |
| 달력/일정 탭 | ✅ 구현됨 | `/routine`, 월간 달력과 샘플 badge가 있는 일정 목록 UI |
| 일정 추가 화면 | ✅ 구현됨 | `/routine/schedule/new`, `RoutineScheduleCreateScreen` |
| 일정 저장 | 🟡 Sync 필요 | 현재 저장 버튼은 `준비중`; 일정 API 계약 미확정 |
| 푸시 알림 | ❌ 제외 | Phase 5+ 이후 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 목록 | `GET /api/v1/pets/{petId}/routines` |
| 생성 | `POST /api/v1/pets/{petId}/routines` |
| 수정 | `PUT /api/v1/pets/{petId}/routines/{routineId}` |
| 삭제 | `DELETE /api/v1/pets/{petId}/routines/{routineId}` |
| 오늘 루틴 | `GET /api/v1/pets/{petId}/routines/today` |
| 완료 체크 | `PATCH /api/v1/pets/{petId}/routines/{routineId}/completions/{date}` |
| 반복 유형 | `repeatType: daily|weekly|biweekly|monthly` |

### Backend sync needed

- `today` 응답 형태는 현재 프론트가 `{ routines: [{ routine, completion }], summary }`를 기대한다.
- 루틴 CRUD 후 프론트는 오늘 루틴을 best-effort로 재조회한다. 후속 조회 실패는 저장 실패로 취급하지 않는다.
- 완료 상태 enum과 날짜 기준 timezone 정책 확인 필요.
- 서버 요청 검증 강화 필요: `label` 길이, `times` 형식, 주간 요일 최소 1개와 `0..6`, `monthlyInterval >= 1`, 날짜 범위.
- 월간 범위 일정 API가 추가되면 프론트 반복 계산 중복 제거를 검토한다.
- 푸시 알림은 현재 범위 밖이다.

---

## 5. 커뮤니티

### 요약

피드 조회, 글쓰기, 좋아요, 이미지 첨부, 투표 작성 UI가 있다. 글쓰기 API는 `multipart(payload, files)` 기준으로 호출한다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 피드 조회 | 🔌 연동됨 | `screens/community/community_screen.dart`, `services/community_service.dart` |
| 글쓰기 | 🔌 연동됨 | `screens/community/write_screen.dart`, `CommunityService.createPost()` |
| 좋아요 | 🔌 연동됨 | `post_card.dart`, `CommunityService.toggleLike()` |
| 이미지 첨부 | 🔌 연동됨 | `write_screen.dart`, multipart `files` |
| 투표 작성 UI | ✅ 구현됨 | `write_screen.dart`, `PollDraft` 생성 |
| 투표 참여 | 🟡 Sync 필요 | `post_card.dart` 표시 모델은 있으나 참여 API 재확인 필요 |
| 검색·해시태그·팔로우 | ❌ 제외 | MVP 제외 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 피드 조회 | `GET /api/v1/posts?cursor=&limit=20&sort=latest|popular&category=...` |
| 글쓰기 | `POST /api/v1/posts` |
| 글쓰기 payload | multipart field `payload`에 JSON 문자열 |
| 이미지 첨부 | multipart field `files` 반복 |
| 좋아요 | `POST /api/v1/posts/{postId}/like` |
| 투표 작성 | `payload.poll: { question, options }` |
| 투표 참여 후보 | `POST /api/v1/posts/{postId}/poll/options/{optionId}/vote` |

### 글쓰기 현재 동작

| 항목 | 상태 | 비고 |
|------|------|------|
| 제목 | ✅ 구현됨 | 프론트 필수 입력. 비면 `제목을 입력해 주세요` 표시 |
| 본문 | ✅ 구현됨 | 프론트 필수 입력. 비면 `내용을 입력해 주세요` 표시 |
| 게시판 | ✅ 구현됨 | 기본값 `FREE`, `CupertinoPicker` bottom sheet로 선택 |
| 상단 바 | ✅ 구현됨 | `취소 / 자유 / 등록` 커스텀 바 |
| payload | 🔌 연동됨 | `content`, `title`, `category`, 선택 `poll` |
| 이미지 | 🔌 연동됨 | `multipart/form-data`의 `files` |

### 투표 작성 현재 동작

| 항목 | 상태 | 비고 |
|------|------|------|
| 패널 표시 | ✅ 구현됨 | 하단 투표 버튼으로 글쓰기 화면 안에 mock 패널 표시 |
| 기본 항목 | ✅ 구현됨 | `항목 입력` 2개 |
| 항목 추가 | ✅ 구현됨 | 클라이언트 입력 컨트롤만 추가 |
| 등록 payload | 🔌 연동됨 | 2개 이상 입력 시 `PollDraft` 포함 |
| question | 🟡 Sync 필요 | 현재 임시값 `투표` |
| 등록 후 수정 | ✅ 구현됨 | UI 안내: `글 등록 이후에는 투표를 수정할 수 없어요.` |

### Backend sync needed

- 게시글 제목/본문/게시판은 프론트에서 필수 입력으로 처리한다. 백엔드 검증 정책과 에러 메시지 확인 필요.
- 이미지 최대 개수는 백엔드 계약과 맞춰야 한다. 기존 문서 기준은 최대 3장이나, 현재 프론트 입력 제한과 재확인 필요.
- 투표 `question`을 별도 입력받을지, 현재 임시값 `투표`를 허용할지 결정 필요.
- 투표 참여 API와 응답 모델을 재확인해야 한다.
- 카테고리 enum은 현재 `CARE`, `FOOD`, `OUTING`, `SHOW`, `QUESTION`, `FREE`, `ADOPTION`, `RESCUE`, `NEWS`, `EVENT`를 사용한다.

---

## 6. 프론트 모델 참고

이 섹션은 백엔드 개발 전 프론트 모델을 빠르게 확인하기 위한 참고다. 최종 DB/API 계약은 백엔드 문서와 구현에서 확정한다.

```typescript
interface Pet {
  id: string;              // 백엔드 Long id를 Flutter 모델에서 String으로 변환
  name: string;
  species: string;
  birthDate: string;       // YYYY-MM-DD
  accentColor: string;
  bgLight: string;
  gender?: 'male' | 'female';
  weight?: number;
  animalRegistrationNumber?: string;
  neutered?: boolean;
  specialNotes?: string;
  diseases?: string;
  profileImageUrl?: string;
}

interface ActivityRecord {
  id: string;              // 백엔드 Long id를 Flutter 모델에서 String으로 변환
  petId: string;           // 백엔드 Long FK를 Flutter 모델에서 String으로 변환
  typeId: string;
  date: string;            // YYYY-MM-DD
  time?: string;           // HH:mm
  routineId?: string;
  note?: string;
  mediaUrls: string[];
  detail: Record<string, unknown>;
}

interface CommunityPostPayload {
  title: string;
  content: string;
  category: string;
  poll?: {
    question: string;
    options: string[];
  };
}
```

---

## 7. 남은 검증

백엔드 실행 후 Flutter 앱에서 아래 흐름을 수동 확인한다.

| 범위 | 검증 항목 |
|------|-----------|
| 인증 | 회원가입, 로그인, 토큰 갱신, 로그아웃 후 재진입 |
| 펫 | 온보딩, 펫 추가/수정/삭제, 프로필 사진 |
| 기록 | 빠른 기록, 타입별 기록, 수정/삭제, 배변/기록 사진 업로드와 표시 |
| 루틴 | 생성/수정/삭제, 오늘 루틴, 완료 체크 |
| 지갑 | 홈 지갑 진입, 지갑 요약, 리포트, 비용 추가 UI; 저장 계약 결정 후 실제 저장 |
| 커뮤니티 | 피드, 게시판 필터, 글쓰기, 이미지 첨부, 좋아요, 투표 표시/작성 |

---

## 8. AI 업데이트 규칙

- 실제 코드 확인 없이 상태를 `🔌 연동됨`으로 바꾸지 않는다.
- 백엔드 미확정 항목은 삭제하지 말고 `🟡 Sync 필요`로 남긴다.
- 문서 정리 작업 중 `backend/`, `frontend/`, `DESIGN.md`를 임의 수정하지 않는다.
- 한글 Markdown은 읽을 수 있는 UTF-8로 유지한다.
- 문서 수정 후 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1`를 실행한다.
