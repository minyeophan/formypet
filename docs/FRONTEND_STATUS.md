# 프론트엔드 구현 현황 및 백엔드 API 요구사항

> 마지막 갱신: 2026-05-26  
> 현재 상태: **Flutter 전환 및 Phase 8 API 연동 완료** — 인증/JWT, 펫, 기록, 루틴, 커뮤니티 API 연결 완료. Android 기기/에뮬레이터에서 백엔드와 함께 하는 수동 E2E 검증은 아직 남아 있음.

---

## 기능별 구현 현황

### 1. 반려동물 프로필
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 펫 목록 조회 | ✅ | `providers/pet_provider.dart`, `services/pet_service.dart` | `GET /api/v1/pets` |
| 펫 등록 | ✅ | `screens/onboarding/onboarding_screen.dart` | `POST /api/v1/pets` |
| 펫 수정 | ✅ | `screens/pet/pet_edit_screen.dart` | `PUT /api/v1/pets/{id}` |
| 펫 삭제 | ✅ | `providers/pet_provider.dart` | `DELETE /api/v1/pets/{id}` |
| 활성 펫 전환 | ✅ | `screens/home/pet_selector.dart` | 클라이언트 상태로 유지 가능 |
| 펫 프로필 사진 | ✅ | `screens/onboarding/onboarding_screen.dart`, `screens/pet/pet_edit_screen.dart`, `services/media_service.dart` | `POST /api/v1/pets/{petId}/media` |
| 생년월일 입력 | ✅ | `screens/onboarding/onboarding_screen.dart`, `screens/pet/pet_edit_screen.dart`, `core/calendar_ranges.dart` | `birthDate: YYYY-MM-DD`, 선택 범위는 `1950-01-01`부터 오늘까지 |

**연동 상태:** `PetNotifier`가 백엔드 API를 호출하고, 활성 펫 선택 같은 UI 상태만 로컬에 유지한다.

---

### 2. 활동 기록
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 빠른 기록 추가 (바텀시트) | ✅ | `widgets/record_modal.dart` | `POST /api/v1/pets/{petId}/records` |
| 타입별 전체 화면 기록 추가 | ✅ | `screens/records/meal_record_screen.dart`, `screens/records/record_category_form_screen.dart` | `POST /api/v1/pets/{petId}/records` |
| 기록 목록 조회 | ✅ | `screens/records/activity_tab.dart`, `screens/records/health_tab.dart` | `GET /api/v1/pets/{petId}/records` |
| 기록 수정/상세 입력 | ✅ | `widgets/record_detail_form.dart` | `PUT /api/v1/pets/{petId}/records/{id}` |
| 기록 삭제 | ✅ | `providers/pet_provider.dart` | `DELETE /api/v1/pets/{petId}/records/{id}` |
| 날짜별 필터 | ✅ (클라이언트) | `screens/records/activity_tab.dart` | `GET ?date=YYYY-MM-DD` 쿼리 파라미터 |
| 타입별 필터 | ✅ (클라이언트) | `screens/records/activity_tab.dart` | `GET ?typeId=meal` 쿼리 파라미터 |
| 오늘 기록 (홈) | ✅ (클라이언트 필터) | `screens/home/recent_records_card.dart` | `GET ?date=today&limit=3` |
| 체중 그래프 | ✅ | `screens/records/growth_tab.dart` | `GET /api/v1/pets/{petId}/records?typeId=weight` |
| 배변 사진 | ✅ (미디어 API) | `widgets/record_modal.dart` | `POST /api/v1/pets/{petId}/records/{recordId}/media` |
| 기록 날짜/시간 입력 | ✅ | `widgets/record_inputs/record_date_time_pickers.dart`, `core/calendar_ranges.dart` | payload는 기존 `date: YYYY-MM-DD`, `time: HH:mm` 유지. 기본 날짜 선택 범위는 `1950-01-01`부터 현재년도 말까지 |
| 기록 숫자 입력 | ✅ | `widgets/record_inputs/record_number_input.dart`, `widgets/record_inputs/record_picker_sheet.dart` | payload schema 변경 없음. 숫자 키패드는 완료 전 입력 중인 값을 헤더 preview로만 표시하고 controller는 완료 시 반영 |

**백엔드 지원 typeId 목록:** `meal`, `water`, `medicine`, `poop`, `walk`, `sleep`, `play`, `weight`, `vet`, `checkup`

**`RecordTypeGrid` 표시 카드:** `급식(meal)`, `음수(groom)`, `배변(poop)`, `산책(walk)`, `영양(medicine)`, `병원(vet)`, `접종(checkup)`, `몸무게(weight)`, `지출(expense)`, `일기(diary)`, `이상현상(etc)`. 현재는 화면 표시만 조정한 임시 상태라 `groom`은 `음수`로, `etc`는 `이상현상`으로 보이지만 저장 payload와 백엔드 타입은 변경하지 않았다. 실제 `water`, `abnormal` 같은 타입 분리는 별도 백엔드 작업에서 결정한다.

**연동 상태:** `PetNotifier`의 기록 생성/수정/삭제는 백엔드 API를 호출한다. 일부 화면 표시용 필터링 유틸은 클라이언트에 남아 있다. `RecordTypeGrid`에서 진입하는 급식/카테고리 기록 화면은 앱 자체 bottom sheet 입력 패널을 사용하며 저장 payload와 API 계약은 바꾸지 않는다.

---

### 3. 루틴
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 루틴 목록 | ✅ | `routine/routine_screen.dart` | `GET /api/v1/pets/{petId}/routines` |
| 루틴 생성 | ✅ | `routine/routine_screen.dart` | `POST /api/v1/pets/{petId}/routines` |
| 루틴 수정 | ✅ | `routine/routine_screen.dart` | `PUT /api/v1/pets/{petId}/routines/{id}` |
| 루틴 삭제 | ✅ | `routine/routine_screen.dart` | `DELETE /api/v1/pets/{petId}/routines/{id}` |
| 루틴 완료 체크 | ✅ | `providers/pet_provider.dart` | `PATCH /api/v1/pets/{petId}/routines/{routineId}/completions/{date}` |
| 반복 유형 | ✅ | `routine/routine_screen.dart` | `repeatType: daily\|weekly\|biweekly\|monthly` |
| 푸시 알림 | ❌ MVP 제외 | - | Phase 5+ 이후 |

---

### 4. 커뮤니티
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 피드 조회 | ✅ | `screens/community/community_screen.dart`, `screens/community/post_card.dart` | `GET /api/v1/posts?cursor=&limit=20` |
| 포스트 작성 | ✅ | `screens/community/write_screen.dart` | `POST /api/v1/posts` |
| 좋아요 토글 | ✅ | `screens/community/post_card.dart` | `POST /api/v1/posts/{id}/like` |
| 사진 업로드 | ✅ | `screens/community/write_screen.dart`, `services/community_service.dart` | `POST /api/v1/posts` multipart (`payload`, `files`) |
| 투표 작성/투표 | ✅ | `screens/community/write_screen.dart`, `screens/community/post_card.dart` | `POST /api/v1/posts`, `POST /api/v1/posts/{postId}/poll/options/{optionId}/vote` |
| 검색·해시태그·팔로우 | ❌ MVP 제외 | - | - |

**주의:** 백엔드는 게시글 제목을 필수로 검증하고, 게시글 첨부 이미지는 최대 3장까지 허용한다. 프론트 입력 제한을 바꿀 때 이 계약을 함께 확인한다.

---

### 5. 인증
| 기능 | 구현 | 백엔드 API 필요 |
|------|------|----------------|
| 회원가입 | ✅ | `POST /api/v1/auth/register` |
| 로그인 | ✅ | `POST /api/v1/auth/login` |
| 토큰 갱신 | ✅ | `POST /api/v1/auth/refresh` |
| 로그아웃 | ✅ | `POST /api/v1/auth/logout` |

**현재 상태:** `providers/auth_provider.dart`, `services/auth_service.dart`, `core/api_client.dart`에서 JWT 인증 흐름을 처리한다. 토큰 저장은 `flutter_secure_storage` 기반이다.

---

## API 연동 현황

백엔드 Phase 진행 순서에 맞춘 주요 API 그룹은 Phase 8에서 프론트에 연결됐다.

| 우선순위 | 엔드포인트 그룹 | 상태 |
|---------|---------------|------|
| 1 | Auth (register/login/refresh/logout) | ✅ 연동 완료 |
| 2 | Pets CRUD | ✅ 연동 완료 |
| 3 | Activity Records CRUD + media | ✅ 연동 완료 |
| 4 | Routines CRUD + completions | ✅ 연동 완료 |
| 5 | Community Posts + Likes + Media + Polls | ✅ 연동 완료 |

**남은 검증:** 백엔드 실행 후 Flutter 앱에서 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 수동 확인한다.

---

## 현재 데이터 스키마 (프론트 기준)

```typescript
// 프론트엔드 타입 → 백엔드 테이블 매핑 참고용
interface Pet {
  id: string;              // 백엔드 Long id를 Flutter 모델에서 String으로 변환
  name: string;            // VARCHAR(50)
  species: string;         // ENUM or VARCHAR
  birthDate: string;       // DATE (YYYY-MM-DD)
  accentColor: string;     // VARCHAR(7) — 서버 생성 or 클라이언트 선택
  bgLight: string;         // VARCHAR(7)
  gender?: 'male'|'female';
  weight?: number;         // DECIMAL(5,2)
  animalRegistrationNumber?: string; // VARCHAR(20)
  neutered?: boolean;
  specialNotes?: string;   // TEXT
  diseases?: string;       // TEXT
}

interface ActivityRecord {
  id: string;              // 백엔드 Long id를 Flutter 모델에서 String으로 변환
  petId: string;           // 백엔드 Long FK를 Flutter 모델에서 String으로 변환
  typeId: string;          // ENUM
  date: string;            // DATE
  time?: string;           // TIME (HH:MM)
  note?: string;           // TEXT
  // ... typeId별 선택 필드 (ERD.md 참고)
}
```
