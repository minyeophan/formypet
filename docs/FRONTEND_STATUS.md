# 프론트엔드 구현 현황 및 백엔드 API 요구사항

> 마지막 갱신: 2026-05-09  
> 현재 상태: **Phase 8 API 연동 완료** — 인증/JWT, 펫, 기록, 루틴, 커뮤니티 API 연결 완료. Expo 기기/에뮬레이터 수동 검증은 아직 남아 있음.

---

## 기능별 구현 현황

### 1. 반려동물 프로필
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 펫 목록 조회 | ✅ | `pet-context.tsx` | `GET /api/v1/pets` |
| 펫 등록 | ✅ | `PetRegisterForm.tsx` | `POST /api/v1/pets` |
| 펫 수정 | ✅ | `app/pet/[id]/edit.tsx` | `PUT /api/v1/pets/{id}` |
| 펫 삭제 | ✅ | `pet-context.tsx` | `DELETE /api/v1/pets/{id}` |
| 활성 펫 전환 | ✅ | `PetSelector.tsx` | 클라이언트 상태로 유지 가능 |
| 펫 프로필 사진 | ❌ MVP 제외 | - | 추후 `PATCH /api/v1/pets/{id}/photo` |

**연동 상태:** `src/lib/pet-context.tsx`는 백엔드 API를 호출한다. 활성 펫 선택 같은 UI 상태만 로컬에 유지한다.

---

### 2. 활동 기록
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 기록 추가 (바텀시트) | ✅ | `RecordModal.tsx` | `POST /api/v1/pets/{petId}/records` |
| 기록 목록 조회 | ✅ | `ActivityTab.tsx`, `HealthTab.tsx` | `GET /api/v1/pets/{petId}/records` |
| 기록 수정 | ✅ | `record-edit/[id].tsx` | `PUT /api/v1/pets/{petId}/records/{id}` |
| 기록 삭제 | ✅ | `record-edit/[id].tsx` | `DELETE /api/v1/pets/{petId}/records/{id}` |
| 날짜별 필터 | ✅ (클라이언트) | `ActivityCalendar.tsx` | `GET ?date=YYYY-MM-DD` 쿼리 파라미터 |
| 타입별 필터 | ✅ (클라이언트) | `ActivityTab.tsx` | `GET ?typeId=meal` 쿼리 파라미터 |
| 오늘 기록 (홈) | ✅ (클라이언트 필터) | `RecentRecords.tsx` | `GET ?date=today&limit=3` |
| 체중 그래프 | ✅ | `GrowthTab.tsx` | `GET /api/v1/pets/{petId}/records?typeId=weight` |
| 배변 사진 | ✅ (로컬 미디어 API) | `RecordModal.tsx` | `POST /api/v1/pets/{petId}/records/{recordId}/media` |

**현재 typeId 목록:** `meal`, `water`, `medicine`, `poop`, `walk`, `sleep`, `play`, `weight`, `vet`, `checkup`

**연동 상태:** `src/lib/pet-context.tsx`의 기록 생성/수정/삭제는 백엔드 API를 호출한다. 일부 화면 표시용 필터링 유틸은 클라이언트에 남아 있다.

---

### 3. 루틴
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 루틴 목록 | ✅ | `app/routine.tsx` | `GET /api/v1/pets/{petId}/routines` |
| 루틴 생성 | ✅ | `app/routine.tsx` | `POST /api/v1/pets/{petId}/routines` |
| 루틴 수정 | ✅ | `app/routine.tsx` | `PUT /api/v1/pets/{petId}/routines/{id}` |
| 루틴 삭제 | ✅ | `app/routine.tsx` | `DELETE /api/v1/pets/{petId}/routines/{id}` |
| 루틴 완료 체크 | ✅ | `TodayRoutine.tsx` | `PATCH /api/v1/pets/{petId}/routines/{routineId}/completions/{date}` |
| 반복 유형 | ✅ | `app/routine.tsx` | `repeatType: daily\|weekly\|biweekly\|monthly` |
| 푸시 알림 | ❌ MVP 제외 | - | Phase 5+ 이후 |

---

### 4. 커뮤니티
| 기능 | 구현 | 파일 | 백엔드 API 필요 |
|------|------|------|----------------|
| 피드 조회 | ✅ | `community.tsx`, `PostCard.tsx` | `GET /api/v1/posts?cursor=&limit=20` |
| 포스트 작성 | ✅ | `community.tsx` | `POST /api/v1/posts` |
| 좋아요 토글 | ✅ | `PostCard.tsx` | `POST /api/v1/posts/{id}/like` |
| 사진 업로드 | ❌ MVP 제외 | - | 추후 멀티파트 업로드 |
| 검색·해시태그·팔로우 | ❌ MVP 제외 | - | - |

---

### 5. 인증
| 기능 | 구현 | 백엔드 API 필요 |
|------|------|----------------|
| 회원가입 | ✅ | `POST /api/v1/auth/register` |
| 로그인 | ✅ | `POST /api/v1/auth/login` |
| 토큰 갱신 | ✅ | `POST /api/v1/auth/refresh` |
| 로그아웃 | ✅ | `POST /api/v1/auth/logout` |

**현재 상태:** `app/auth.tsx`, `src/lib/auth-context.tsx`, `src/services/api.ts`에서 JWT 인증 흐름을 처리한다. 토큰 저장은 현재 AsyncStorage 기반이다.

---

## API 연동 현황

백엔드 Phase 진행 순서에 맞춘 주요 API 그룹은 Phase 8에서 프론트에 연결됐다.

| 우선순위 | 엔드포인트 그룹 | 상태 |
|---------|---------------|------|
| 1 | Auth (register/login/refresh/logout) | ✅ 연동 완료 |
| 2 | Pets CRUD | ✅ 연동 완료 |
| 3 | Activity Records CRUD + media | ✅ 연동 완료 |
| 4 | Routines CRUD + completions | ✅ 연동 완료 |
| 5 | Community Posts + Likes | ✅ 연동 완료 |

**남은 검증:** 백엔드 실행 후 Expo 앱에서 회원가입/로그인, 펫 온보딩, 기록 CRUD, 루틴 CRUD, 커뮤니티 피드/좋아요, 배변 사진 업로드/표시, 로그아웃 후 재진입을 수동 확인한다.

---

## 현재 데이터 스키마 (프론트 기준)

```typescript
// 프론트엔드 타입 → 백엔드 테이블 매핑 참고용
interface Pet {
  id: string;              // UUID
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
  id: string;              // UUID
  petId: string;           // FK
  typeId: string;          // ENUM
  date: string;            // DATE
  time?: string;           // TIME (HH:MM)
  note?: string;           // TEXT
  // ... typeId별 선택 필드 (ERD.md 참고)
}
```
