# Flutter API–화면 연결 현황

점검 기준: 현재 backend Controller, Flutter service/model/provider/router/screen 파일을 정적 대조했다. `알림 설정 UI`는 Goal의 제외 범위이며, 아래의 미연결 항목은 임의의 화면을 만들기 전에 실제 제품 요구사항을 확인해야 한다.

## 기능별 현황

| 기능 | Backend/Flutter 연결 | 현재 화면 | 판단 |
|---|---|---|---|
| 인증·프로필 | `auth_service.dart`, `AuthScreen`, `MyProfileScreen`, `MySettingsScreen` | 로그인/회원가입/프로필/로그아웃 | 기존 흐름 보완 대상 |
| 반려동물 | `pet_service.dart`, `pet_provider.dart` | `MyPetsScreen`, `PetDetailScreen`, `PetEditScreen`, onboarding | 기존 화면 재사용 |
| 활동 기록 | `record_service.dart` | `RecordsScreen`, `RecordDetailScreen`, `RecordEditScreen`, category/meal 화면 | 기존 화면 재사용 |
| 루틴 | `routine_service.dart` | `RoutineScreen`, `RoutineCreateScreen` | 기존 화면 재사용 |
| 케어 일정 | `care_schedule_service.dart` | `RoutineScheduleCreateScreen`, `RoutineScheduleDetailScreen/Edit` | 기존 화면 재사용 |
| 지출 | `wallet_expense_service.dart`, `wallet_expense_provider.dart` | wallet/add/detail/edit/report | 기존 화면 재사용 |
| 커뮤니티 | `community_service.dart`, `community_provider.dart` | feed/detail/write/comments | 기존 화면 재사용 |
| 미디어 | `media_service.dart` | pet/record/profile 입력 화면에서 사용 | 기존 흐름 점검 |
| 알림 목록/읽음 | `notification_service.dart`, `notification_provider.dart`, backend `NotificationController` | `NotificationScreen` | 목록·개별 읽음·전체 읽음 연결 완료 |
| 알림 설정 | backend settings API 존재, Flutter UI 없음 | 없음 | 명시적 제외, 구현하지 않음 |
| 공지·정책·문의 | Flutter `my_*` 화면은 존재하나 현재 backend Controller/service API와 직접 연결되지 않음 | 정적/로컬 콘텐츠 화면 | 새 API 화면으로 만들지 않음 |

## 라우팅 현황

`frontend/lib/router/app_router.dart`에 인증, onboarding, home, records, wallet, routine, community, pet, my, notifications 흐름이 등록되어 있다. 기록·지출·루틴·커뮤니티의 생성/상세/수정 route와 알림 목록 route가 존재한다.

## 우선 점검 순서

1. 기존 화면의 service 호출과 provider 상태가 실제 endpoint/request/response model과 일치하는지 확인한다.
2. 기존 화면의 저장·수정·삭제 후 새로고침, 로딩, 빈 상태, 오류/재시도 흐름을 테스트로 확인한다.
3. 위 점검에서 실제 결함이 확인된 화면만 보완한다.
4. 알림 목록 화면은 backend 목록·개별 읽음·전체 읽음 API와 연결되어 있다. 사용자 전체 알림 설정 UI는 계속 제외한다.
5. 공지·정책·문의 화면은 현재 backend API가 없으므로 임의 API를 만들거나 새 화면을 추가하지 않는다.
