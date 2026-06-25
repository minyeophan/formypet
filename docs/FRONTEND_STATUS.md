# 프론트엔드 구현 현황 및 백엔드 Sync 체크

> 마지막 갱신: 2026-06-25
> 이 문서는 **현재 사용자 접근 가능한 프론트 UI와 서비스/provider 구현 기준** 현황 문서다. 확정 API 계약서가 아니며, 백엔드 계약 확정 전 확인이 필요한 항목은 `Backend sync needed`에 남긴다. 앱 코드나 백엔드 코드가 바뀌면 관련 섹션만 갱신한다.

## 상태 표기

| 표기 | 의미 |
|------|------|
| ✅ 구현됨 | 화면 또는 프론트 로직이 있음 |
| 🔌 연동됨 | 현재 서비스/provider 코드가 API를 호출 중 |
| 🚧 부분 구현 | 화면 골격은 있으나 핵심 동작이 `준비중`, 샘플, 표시 전용임 |
| 🧭 진입점 없음 | service, provider, 이전 위젯은 있으나 현재 사용자 UI에서 접근할 수 없음 |
| 🟡 Sync 필요 | 프론트 요구는 있으나 백엔드와 재확정 필요 |
| ❌ 제외 | MVP 또는 현재 범위 밖 |

## 목차

- [0. 사용자 화면 동선 현황](#0-사용자-화면-동선-현황)
- [1. 인증](#1-인증)
- [2. 반려동물 프로필](#2-반려동물-프로필)
- [3. 활동 기록](#3-활동-기록)
- [4. 루틴](#4-루틴)
- [5. 커뮤니티](#5-커뮤니티)
- [6. 프론트 모델 참고](#6-프론트-모델-참고)
- [7. 남은 검증](#7-남은-검증)
- [8. AI 업데이트 규칙](#8-ai-업데이트-규칙)

---

## 0. 사용자 화면 동선 현황

이 표는 라우터와 실제 버튼 콜백 기준이다. 파일이나 service가 존재해도 현재 화면에서 들어갈 수 없으면 `🧭 진입점 없음`으로 적는다.

| 영역 | 사용자 동선 | 상태 | 현재 동작 또는 남은 일 |
|------|-------------|------|------------------------|
| Home | 상단 알림 아이콘 | 🧭 진입점 없음 | 표시 전용 비활성 버튼. 알림 목록 화면 없음 |
| Home | `일정` 메뉴 | 🚧 부분 구현 | `준비중` 토스트만 표시. 실제 일정은 루틴 화면의 일정 탭에서 샘플로만 표시 |
| Home | `반려로그` 메뉴 | 🧭 진입점 없음 | `준비중` 토스트만 표시. 별도 화면 없음 |
| Community | 상단 알림, 검색 아이콘 | 🧭 진입점 없음 | `준비중` 토스트만 표시. 알림 목록과 검색 화면 없음 |
| Community | 게시글 카드 | 🔌 연동됨 | 피드 조회, 좋아요, 상세 진입, 첫 이미지 썸네일, 이미지 개수, 투표 badge 표시 |
| Community | 카테고리 화면 `전체⌄`, 이용 가이드 | 🚧 부분 구현 | 표시 전용 UI. 필터 선택과 가이드 화면 없음 |
| My | 펫 카드, `펫 추가하기` | ✅ 구현됨 | `/pet/{id}`, `/pets/new`로 이동 |
| My | 설정, `모두보기`, 프로필 편집 | ✅ 구현됨 | `/my/settings`, `/my/pets`, `/my/profile`로 이동 |
| My | 약관 및 정책 | ✅ 구현됨 | `/my/policies`, `/my/policies/{policyId}`로 이동 |
| My | 약관 및 정책 외 나머지 메뉴 row | 🚧 부분 구현 | `준비중` 토스트만 표시 |
| My | 로그아웃 | 🔌 연동됨 | 설정의 확인 시트 승인 후 `AuthNotifier.logout()` 호출 |
| Records | `반려기록` 메인, 전체 기록, 성장 | ✅ 구현됨 | `/records`, `/records/all`, `/records/growth`로 이동 |
| Records | 급식, 음수, 배변, 산책, 몸무게, 병원, 영양, 일기, 기타 | 🔌 연동됨 | 전체 화면 입력 후 기록 생성 API 호출 |
| Records | 기록 목록 row | 🚧 부분 구현 | 목록 표시는 되지만 상세, 수정, 삭제 진입 UI 없음 |
| Wallet | 지갑, 지출 리포트, 비용 추가 | 🚧 부분 구현 | 조회·입력 UI는 있으나 비용 저장, 항목 추가, 사진 첨부는 미구현 |
| Routine | 루틴 생성, 완료 체크, 삭제 | 🔌 연동됨 | API 호출 연결 |
| Routine | 루틴 수정 | 🧭 진입점 없음 | service/provider는 있으나 수정 화면 진입 없음 |
| Routine | 일정 목록, 일정 추가 | 🚧 부분 구현 | 목록은 고정 샘플. 추가 폼은 있으나 저장 API와 지도 검색 없음 |

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
| 로그아웃 service | 🔌 연동됨 | `AuthService.logout()` 호출 후 로컬 토큰 삭제 |
| 로그아웃 UI | 🔌 연동됨 | `/my/settings` 위험 액션 카드와 확인 시트에서 호출 |
| 토큰 저장 | ✅ 구현됨 | `flutter_secure_storage` 기반 access/refresh 저장 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 회원가입 | `POST /api/v1/auth/register` |
| 로그인 | `POST /api/v1/auth/login` |
| 토큰 갱신 | `POST /api/v1/auth/refresh`, `refreshToken` |
| 로그아웃 | `POST /api/v1/auth/logout`, `refreshToken` |

### 프로필 API 계약

- `GET /api/v1/users/me`, `PATCH /api/v1/users/me`, `POST /api/v1/users/me/profile-image`는 모두 `id`, `email`, `nickname`, `profileImageUrl`, `registrationSource`를 반환한다.
- `id`는 백엔드 `Long`이며 Flutter `UserProfile`에서는 문자열로 변환한다.
- 닉네임 변경은 `PATCH /api/v1/users/me`에 `{ "nickname": "..." }`를 보내며, 서버에서 trim한 1~50자를 허용한다.
- 사진 등록은 `POST /api/v1/users/me/profile-image`의 multipart `file` 한 개다. `jpg`, `jpeg`, `png`, `webp`와 최대 5MB를 허용한다.
- 프로필 사진은 사용자당 최신 한 장만 유지한다. 새 파일을 저장한 뒤 이전 DB 행과 저장 파일을 커밋 후 정리하며, 사진 삭제 API는 제공하지 않는다.

### Backend sync needed

- `PetNotifier.clearForSignedOutUser()`의 환경설정 Future 실패 및 무한 대기 방어는 프론트 후속 작업으로 남긴다.

---

## 2. 반려동물 프로필

### 요약

펫 CRUD, 활성 펫 전환, 프로필 사진 업로드, 생년월일/함께한 날 선택 UI가 구현되어 있다. CRUD와 사진 업로드는 서비스 코드에서 API를 호출한다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 펫 목록 조회 | 🔌 연동됨 | `providers/pet_provider.dart`, `services/pet_service.dart` |
| 펫 등록 | 🔌 연동됨 | `screens/onboarding/onboarding_screen.dart`, `PetService.createPet()` |
| 펫 수정 | 🔌 연동됨 | `screens/pet/pet_edit_screen.dart`, `PetService.updatePet()` |
| 펫 삭제 | 🔌 연동됨 | `PetService.deletePet()` |
| 활성 펫 전환 | ✅ 구현됨 | provider 상태로 유지 |
| 펫 프로필 사진 | 🔌 연동됨 | `services/media_service.dart` |
| 생년월일 입력 | ✅ 구현됨 | `PetDateField`, `core/calendar_ranges.dart`, 선택 범위는 `1950-01-01`부터 오늘까지 |
| 함께한 날 입력 | ✅ 구현됨 | PetEdit에서 `PetDateField`와 기존 date picker sheet 사용 |
| PetEdit 입력 레이아웃 | ✅ 구현됨 | 종 3열 grid, 성별/중성화 2분할 row, 특수상태 dense 4분할 row |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 목록 조회 | `GET /api/v1/pets` |
| 등록 | `POST /api/v1/pets` |
| 수정 | `PUT /api/v1/pets/{id}` |
| 삭제 | `DELETE /api/v1/pets/{id}` |
| 프로필 사진 | `POST /api/v1/pets/{petId}/media` |
| 생년월일 | `birthDate: YYYY-MM-DD` |
| 생년월일 미상 | Onboarding은 `birthDate` 생략, PetEdit은 `birthDateUnknown: true` |
| 확장 프로필 | `breed`, `adoptionDate`, `guardianNickname`, `specialStatus`, `personality`, `primaryHospitalName` |
| 프로필 색상 | `accentColor`, `bgLight` |

### Backend sync needed

- `accentColor`, `bgLight`는 클라이언트 선택값을 create/update 요청에 포함하면 백엔드가 저장하고, 누락 시 서버 기본값 또는 기존값을 유지한다.
- `gender`, `weight`, `animalRegistrationNumber`, `neutered`, `specialNotes`, `diseases`, `profileImageUrl`, 확장 프로필 필드는 nullable이다.
- `/my/profile`는 닉네임 PATCH와 프로필 사진 multipart POST를 순서대로 호출한다. 닉네임 저장 뒤 사진 등록이 실패하면 닉네임과 기존 서버 사진을 유지하고 부분 성공 안내를 표시한다.

---

## 3. 활동 기록

### 요약

현재 사용자 동선은 `/records` 메인과 타입별 전체 화면 입력을 중심으로 한다. `/records?date=YYYY-MM-DD`와 입력 화면의 `date` query를 지원하며, 메인에서 선택한 날짜를 입력 화면의 고정 날짜로 사용한다. 이전 빠른 기록 bottom sheet와 이전 탭 위젯 파일은 남아 있으나 현재 Home과 라우터에서 호출하지 않는다. 기록 목록은 표시되지만 상세, 수정, 삭제 진입 UI는 아직 없다.

활동 기록 타입은 `meal`, `water`, `poop`, `walk`, `medicine`, `weight`, `vet`, `diary`, `etc` 9개만 유지한다. `/records/:typeId/new`으로 `play`, `sleep`, `checkup`, `bath`, `groom`에 직접 접근하면 `/records`로 redirect한다. 일정·지갑의 `grooming`과 병원 방문 사유 `checkup`은 이 정책의 대상이 아니다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 기록 메인/날짜 선택 | ✅ 구현됨 | `/records`, `screens/records/records_screen.dart` |
| 전체 기록 목록 | ✅ 구현됨 | `/records/all`, 날짜별 그룹 표시 |
| 타입별 전체 화면 입력 | 🔌 연동됨 | `meal_record_screen.dart`, `record_category_form_screen.dart`; 현재 진입 가능한 타입은 아래 표 참고 |
| 이전 빠른 기록 bottom sheet | 🧭 진입점 없음 | `widgets/record_modal.dart`, `screens/home/quick_record_row.dart`는 남아 있으나 현재 Home과 라우터에서 호출하지 않음 |
| 오늘 Home 요약 | ✅ 구현됨 | `home_screen.dart`의 오늘 관리 타임라인과 최근 건강 상태 |
| 성장/체중 그래프 | ✅ 구현됨 | `/records/growth`, `GrowthRecordsScreen` |
| 기록 상세/수정/삭제 UI | 🧭 진입점 없음 | provider/service 메서드는 있으나 현재 기록 목록 row에서 들어갈 화면이나 액션 없음 |
| 미디어 업로드 service | 🔌 연동됨 | `services/record_service.dart`, 기록 생성 후 media 업로드 |
| 현재 기록 입력 사진 첨부 | 🚧 부분 구현 | 급식 화면은 사진 1장 첨부 가능. 범용 카테고리 폼은 사진 첨부 없음 |
| 날짜/시간 입력 | ✅ 구현됨 | 전체 화면 기록 입력은 route date를 읽기 전용으로 표시하고 시간만 picker로 수정. 지출 입력은 별도 날짜 picker 유지 |
| 숫자 입력 preview | ✅ 구현됨 | `widgets/record_inputs/record_number_input.dart`, `record_picker_sheet.dart` |
| 저장 후 이동 | ✅ 구현됨 | 급식/카테고리 기록 저장 성공 후 `/records?date=<저장 날짜>`로 이동 |
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

### 현재 `/records` 진입 가능 타입

| typeId | 상태 | 비고 |
|--------|------|------|
| `meal` | 🔌 연동됨 | 급식 전체 화면 입력 |
| `water` | 🔌 연동됨 | 음수 전체 화면 입력 |
| `poop` | 🔌 연동됨 | 배변 전체 화면 입력 |
| `walk` | 🔌 연동됨 | 산책 전체 화면 입력 |
| `medicine` | 🔌 연동됨 | 영양 전체 화면 입력 |
| `weight` | 🔌 연동됨 | 몸무게 전체 화면 입력 |
| `vet` | 🔌 연동됨 | 병원 전체 화면 입력 |
| `diary` | 🔌 연동됨 | 일기 전체 화면 입력, `activity_records.note`만 사용 |
| `etc` | 🔌 연동됨 | 기타 전체 화면 입력, `activity_records.note`만 사용 |

### 기록 메인에서 숨기는 별개 도메인

| 항목 | 상태 | 비고 |
|------|------|------|
| `expense` | 🚧 부분 구현 | 메인 기록 카드에서는 숨김. 별도 지갑 UI가 있으나 저장 계약 미확정 |

### 지갑/지출 UI

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 홈 지갑 진입 | ✅ 구현됨 | 홈 `지갑` 메뉴 → `/wallet` |
| 지갑 요약 | ✅ 구현됨 | `screens/records/expense_wallet_screen.dart`, records 상태의 `expense` 항목 집계 |
| 지출 리포트 | ✅ 구현됨 | `/wallet/report`, 카테고리 합계와 지출 목록 표시 |
| 비용 추가 화면 | ✅ 구현됨 | `/records/expense/new`, 금액/카테고리/기본 정보/메모 UI |
| 지출 저장 | 🟡 Sync 필요 | 저장 버튼은 현재 `준비중`; 백엔드 저장 API/typeId 미확정 |
| 비용 항목 추가, 사진 첨부 | 🚧 부분 구현 | 비용 추가 화면에 표시되지만 현재는 눌리지 않는 정적 UI |

### Backend sync needed

- `ActivityRecord.detail` 키는 프론트 입력 필드 기준이며, 백엔드 개발 시 재정렬 필요.
- 전체 화면 폼 기준 현재 detail: `meal(foodType, servedAmount, consumedPercent, product?, brand?, feedingMethod?)`, `water(amount)`, `walk(distance)`, `poop(poopShape, poopColor)`, `weight(weight)`, `vet(vetClinicName, vetVisitReason, vetTreatment)`, `medicine(medicineName, dosage)`, `diary`/`etc`는 detail 없이 `note`만 사용.
- `water` 단위는 UI에서 `ml` 고정값으로 표시하고, 백엔드에는 `amount`만 저장한다.
- 제거된 기록 타입(`play`, `sleep`, `checkup`, `bath`, `groom`)은 다시 열지 않는다. `expense`는 기록 타입이 아닌 지갑 전용 도메인으로 유지한다.
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
| 루틴 수정 UI | 🧭 진입점 없음 | 수정 화면이나 목록 액션 없음 |
| 루틴 삭제 | 🔌 연동됨 | `routine/routine_screen.dart` |
| 오늘 루틴 | 🔌 연동됨 | `RoutineService.getTodayRoutines()` |
| 완료 체크 | 🔌 연동됨 | completion API 호출 |
| 반복 유형 | ✅ 구현됨 | `daily`, `weekly`, `biweekly`, `monthly`; 백엔드 규칙과 같은 날짜 helper 사용 |
| 달력/일정 탭 | 🚧 부분 구현 | `/routine`, 월간 루틴 달력은 실제 상태 사용. 일정 목록은 고정 샘플 2개 |
| 일정 추가 화면 | 🚧 부분 구현 | `/routine/schedule/new`, 입력 UI는 있으나 저장 시 `준비중` 토스트 후 복귀 |
| 일정 저장 | 🟡 Sync 필요 | 현재 저장 버튼은 `준비중`; 일정 API 계약 미확정 |
| 일정 지도 검색 | 🚧 부분 구현 | `지도에서 찾기` 버튼은 현재 `준비중` 토스트만 표시 |
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

피드 조회, 글쓰기, 좋아요, 이미지 첨부, 투표 작성 payload, 게시글 상세, 댓글, 투표 참여가 연결돼 있다. 피드 카드는 제목/본문 preview와 첫 이미지 썸네일, 이미지 개수, 투표 badge를 표시하고, 상세 화면에서 전체 본문·이미지·투표·댓글을 표시한다. 검색, 알림, 카테고리 필터 동작은 아직 연결되지 않았다.

### 현재 프론트 구현

| 항목 | 상태 | 프론트 기준 |
|------|------|-------------|
| 피드 조회 | 🔌 연동됨 | `screens/community/community_screen.dart`, `services/community_service.dart` |
| 글쓰기 | 🔌 연동됨 | `screens/community/write_screen.dart`, `CommunityService.createPost()` |
| 좋아요 | 🔌 연동됨 | `post_card.dart`, `CommunityService.toggleLike()` |
| 글쓰기 이미지 첨부 | 🔌 연동됨 | `write_screen.dart`, multipart `files` |
| 피드 이미지 표시 | ✅ 구현됨 | `PostCard`가 첫 이미지 썸네일과 2장 이상 개수를 표시 |
| 투표 작성 UI | ✅ 구현됨 | `write_screen.dart`, `PollDraft` 생성 |
| 피드 투표 표시 | ✅ 구현됨 | `PostCard`는 투표 badge, 상세 화면은 투표 문항·항목·비율 표시 |
| 투표 참여 | 🔌 연동됨 | `CommunityService.vote()`, `CommunityProvider.vote()`가 투표 API 호출 후 캐시 갱신 |
| 게시글 상세, 댓글 진입 | 🔌 연동됨 | `/community/posts/:postId`, `CommunityDetailScreen`, 댓글 목록/작성 API 연결 |
| 댓글 수 동기화 | 🔌 연동됨 | 댓글 작성 응답의 서버 `commentsCount`로 피드와 상세 캐시 갱신 |
| 상단 알림, 검색 | 🧭 진입점 없음 | 아이콘은 있으나 `준비중` 토스트만 표시 |
| 카테고리 필터, 이용 가이드 | 🚧 부분 구현 | `전체⌄` pill과 가이드 패널은 표시 전용 |
| 해시태그·팔로우 | ❌ 제외 | MVP 제외 |

### API 요구사항

| 항목 | 엔드포인트/필드 |
|------|----------------|
| 피드 조회 | `GET /api/v1/posts?cursor=&limit=20&sort=latest|popular&category=...` |
| 상세 조회 | `GET /api/v1/posts/{postId}` |
| 글쓰기 | `POST /api/v1/posts` |
| 글쓰기 payload | multipart field `payload`에 JSON 문자열 |
| 이미지 첨부 | multipart field `files` 반복 |
| 좋아요 | `POST /api/v1/posts/{postId}/like` |
| 투표 작성 | `payload.poll: { question, options }` |
| 투표 참여 | `POST /api/v1/posts/{postId}/poll/options/{optionId}/vote` |
| 댓글 목록 | `GET /api/v1/posts/{postId}/comments?cursor=&limit=20` |
| 댓글 작성 | `POST /api/v1/posts/{postId}/comments`, `{ "content": "..." }` |

투표 option 응답의 표시 텍스트는 백엔드 `label` 필드가 기준이다. Flutter `PostPollOption`은 기존 호환을 위해 `text`, `optionText`, `label`을 모두 읽되, 현재 서버 계약은 `label`이다.

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
- 카테고리 enum은 현재 `CARE`, `FOOD`, `OUTING`, `SHOW`, `QUESTION`, `FREE`, `ADOPTION`, `RESCUE`, `NEWS`, `EVENT`를 사용한다.
- 댓글은 현재 단일 단계이며 작성자·내용·시각만 표시한다. 대댓글, 수정, 삭제, 신고는 현재 범위 밖이다.

---

## 6. 프론트 모델 참고

이 섹션은 백엔드 개발 전 프론트 모델을 빠르게 확인하기 위한 참고다. 최종 DB/API 계약은 백엔드 문서와 구현에서 확정한다.

```typescript
interface Pet {
  id: string;              // 백엔드 Long id를 Flutter 모델에서 String으로 변환
  name: string;
  species: string;
  birthDate: string;       // YYYY-MM-DD
  breed?: string;
  adoptionDate?: string;   // YYYY-MM-DD
  accentColor: string;
  bgLight: string;
  gender?: 'male' | 'female';
  weight?: number;
  animalRegistrationNumber?: string;
  neutered?: boolean;
  specialNotes?: string;
  diseases?: string;
  guardianNickname?: string;
  specialStatus?: string;
  personality?: string;
  primaryHospitalName?: string;
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

interface CommunityComment {
  id: string;
  postId: string;
  authorNickname: string;
  content: string;
  createdAt: string;
  commentsCount: number; // 댓글 작성 응답에서 서버 기준 게시글 댓글 수 동기화에 사용
}
```

---

## 7. 남은 검증

백엔드 실행 후 Flutter 앱에서 아래 흐름을 수동 확인한다.

| 범위 | 검증 항목 |
|------|-----------|
| 인증 | 회원가입, 로그인, 카카오 로그인, 토큰 갱신. 로그아웃은 UI 진입점 추가 후 재진입 확인 |
| 펫 | 온보딩, 펫 추가/수정/삭제, 프로필 사진 |
| 기록 | 현재 접근 가능한 타입별 기록, 급식 사진 업로드, 목록/성장 표시. 상세·수정·삭제 UI 추가 후 해당 흐름 확인 |
| 루틴 | 생성/삭제, 오늘 루틴, 완료 체크. 수정 UI와 일정 저장 계약 추가 후 해당 흐름 확인 |
| 지갑 | 홈 지갑 진입, 지갑 요약, 리포트, 비용 추가 UI. 저장 계약 결정 후 실제 저장 |
| 커뮤니티 | 피드, 카테고리 탭, 글쓰기, 이미지 첨부, 좋아요, 상세, 댓글 작성, 투표 참여. 검색/알림/카테고리 필터 연결 후 해당 흐름 확인 |

---

## 8. AI 업데이트 규칙

- 실제 코드 확인 없이 상태를 `🔌 연동됨`으로 바꾸지 않는다.
- service/provider 또는 이전 위젯 파일이 있어도 현재 화면 진입점이 없으면 `🧭 진입점 없음`으로 구분한다.
- 샘플 데이터, 표시 전용 control, `준비중` 토스트로 끝나는 동작은 `🚧 부분 구현`으로 구분한다.
- 백엔드 미확정 항목은 삭제하지 말고 `🟡 Sync 필요`로 남긴다.
- 문서 정리 작업 중 `backend/`, `frontend/`, `DESIGN.md`를 임의 수정하지 않는다.
- 한글 Markdown은 읽을 수 있는 UTF-8로 유지한다.
- 문서 수정 후 `powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1`를 실행한다.
