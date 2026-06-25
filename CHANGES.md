# 사용자 프로필 저장·사진 업로드 변경 기록

| 항목 | 값 |
|---|---|
| 대상 커밋 | `1e2928d feat: 사용자 프로필 저장과 사진 업로드 연결` |
| 범위 | 백엔드 사용자 프로필 API 응답·프로필 미디어 교체 정리, Flutter 인증 서비스·상태·프로필 편집 화면, 회귀 테스트 |
| 데이터베이스 마이그레이션 | 없음. 기존 `users.profile_media_id`와 `media_resources`를 사용한다. |
| 사진 삭제 API | 추가하지 않음. 새 사진 업로드가 성공할 때만 이전 프로필 사진을 교체·정리한다. |

## 새로 추가된 기능

| 기능 | 사용자/호출자 관점의 동작 | 관련 파일 |
|---|---|---|
| 사용자 프로필 ID 응답 | `GET`, `PATCH`, 사진 `POST`의 `data`에 백엔드 `Long id`를 포함한다. Flutter는 기존 `UserProfile.fromJson` 규칙대로 문자열 ID로 변환한다. | `UserProfileResponse.java`, `user_profile.dart` |
| 닉네임 저장 API 연결 | 프로필 편집 화면에서 변경된 닉네임을 `PATCH /api/v1/users/me`로 저장하고, 성공 응답으로 인증 상태의 프로필을 교체한다. | `auth_service.dart`, `auth_provider.dart`, `my_profile_screen.dart` |
| 프로필 사진 업로드 API 연결 | 선택한 사진 bytes와 원본 파일명을 multipart `file`로 `POST /api/v1/users/me/profile-image`에 전송하고, 성공 응답으로 인증 상태의 사진 URL을 교체한다. | `auth_service.dart`, `auth_provider.dart` |
| 최신 사진 1장 유지 | 새 프로필 사진 저장 후 이전 프로필 미디어 DB 행을 삭제하고, 트랜잭션 커밋 후 이전 저장 파일을 best-effort로 삭제한다. | `UserProfileService.java`, `MediaService.java` |
| 저장 전 로컬 미리보기 | 사진 선택 직후 `XFile` bytes를 표시하며, 서버 업로드 전에는 서버 사진 URL을 바꾸지 않는다. | `my_profile_screen.dart` |
| 부분 성공 처리 | 닉네임 성공 뒤 사진 업로드가 실패하면 닉네임은 유지하고 선택 사진 미리보기만 제거한 뒤 안내 SnackBar를 표시한다. | `my_profile_screen.dart` |

## 기존 동작 변경 — 중요

| 기존 동작 | 변경된 동작 | 영향/호환성 |
|---|---|---|
| `/my/profile` 저장 버튼은 `준비중` 토스트만 표시했다. | 실제 닉네임 PATCH와 사진 POST를 순서대로 호출한다. | 프로필 편집이 서버 상태를 변경한다. 테스트/수동 QA에서 실제 계정 또는 격리된 API를 사용해야 한다. |
| 사진을 다시 올려도 기존 프로필 미디어는 남았다. | 새 사진 참조를 flush한 뒤 이전 프로필 미디어 행을 삭제하고, 커밋 후 파일을 삭제한다. | 동일 사용자는 최신 사진 URL만 유지한다. 롤백 시 이전 파일은 삭제되지 않는다. |
| 사용자 프로필 응답은 `email`, `nickname`, `profileImageUrl`, `registrationSource`만 반환했다. | 모든 사용자 프로필 응답의 첫 필드에 `id: Long`이 추가됐다. | JSON 소비자는 새 필드를 무시할 수 있어 하위 호환이다. Flutter는 문자열로 변환한다. |
| 프로필 사진 업로드 실패 시 화면의 선택 상태 정책이 없었다. | 선택 사진/미리보기는 제거하고, 기존 서버 사진 URL은 provider 상태에 남긴다. | 기존 사진 교체 실패 시 사용자에게 이전 사진이 계속 보인다. |
| 저장 중 전역 인증 loading 상태를 사용할 가능성이 있었다. | 화면 로컬 `_isSaving`만 사용한다. | 다른 인증 UI의 loading 상태는 프로필 저장으로 바뀌지 않는다. |

## API·응답 계약

| 엔드포인트 | 요청 | 성공 응답 `data` | 상태 코드 | 기본값/제약 |
|---|---|---|---|---|
| `GET /api/v1/users/me` | 없음 | `{ id: Long, email: String, nickname: String, profileImageUrl: String?, registrationSource: String }` | `200` | 사진이 없으면 `profileImageUrl`은 `null`/JSON 미포함 처리 가능 |
| `PATCH /api/v1/users/me` | JSON `{ "nickname": String }` | 위와 동일 | `200` | 서버는 trim 후 1~50자만 허용한다. 공백만 있는 값과 51자 이상은 `400`이다. |
| `POST /api/v1/users/me/profile-image` | multipart `file` 1개 | 위와 동일. 새 URL은 `/api/v1/media/{id}` | `201` | `jpg`, `jpeg`, `png`, `webp`, 최대 5MB. 기존 사진은 새 저장 성공 후에만 정리한다. |

## 함수 시그니처·리턴 형태

| 계층 | 함수/생성자 시그니처 | 리턴 형태 | 변경 내용 |
|---|---|---|---|
| Backend DTO | `UserProfileResponse(Long id, String email, String nickname, String profileImageUrl, String registrationSource)` | JSON object | 첫 필드 `Long id` 추가. `of(User)`는 `user.getId()`를 사용한다. |
| Backend service | `UserProfileResponse uploadProfileImage(String email, MultipartFile file)` | 최신 사용자 프로필 응답 | 기존 시그니처 유지. 이전 `profileMediaId`를 기억하고 새 참조 flush 뒤 정리한다. |
| Backend service | `void deleteUserProfileMedia(Long userId, Long mediaId)` | 없음 | 새 공개 메서드. 해당 사용자가 소유하고 pet/record에 연결되지 않은 미디어만 DB에서 삭제한다. |
| Flutter service | `Future<UserProfile> updateProfile({required String nickname})` | API `data`를 파싱한 `UserProfile` | 새 메서드. PATCH body는 `{ 'nickname': nickname }`이다. |
| Flutter service | `Future<UserProfile> uploadProfileImage({required Uint8List bytes, required String filename})` | API `data`를 파싱한 `UserProfile` | 새 메서드. `FormData`의 `file` 한 개를 전송한다. |
| Flutter notifier | `Future<void> updateProfile({required String nickname})` | 없음 | API 성공 시에만 `state.profile`을 응답 프로필로 교체한다. |
| Flutter notifier | `Future<void> uploadProfileImage({required Uint8List bytes, required String filename})` | 없음 | API 성공 시에만 `state.profile`을 응답 프로필로 교체한다. |
| Flutter screen | `Future<void> _save()` | 없음 | 새 저장 알고리즘. 검증, PATCH, 사진 POST, 부분 성공 SnackBar, 복귀를 수행한다. |
| Flutter screen | `Future<void> _pickPhoto()` | 없음 | 선택한 `XFile`과 미리보기 bytes를 화면 로컬 상태에 보관한다. |
| Flutter screen | `void _showSaveMessage(String message)` | 없음 | floating SnackBar를 표시한다. |

## 분기 조건·기본값

| 위치 | 조건 | 결과 | 기본값/실패 시 상태 |
|---|---|---|---|
| `MyProfileScreen._save` | `_isSaving == true` | 즉시 반환하여 중복 요청을 막는다. | `_isSaving` 초기값은 `false`다. |
| `MyProfileScreen._save` | 닉네임 trim 결과가 빈 값 | API를 호출하지 않고 인라인 오류를 표시한다. | 오류: `닉네임을 입력해 주세요.` |
| `MyProfileScreen._save` | 닉네임 길이 `> 50` | API를 호출하지 않고 인라인 오류를 표시한다. | 오류: `닉네임은 50자 이하로 입력해 주세요.` |
| `MyProfileScreen._save` | 기존 닉네임과 같고 선택 사진도 없음 | SnackBar/API 호출 없이 설정 화면으로 복귀한다. | `_selectedPhoto` 초기값은 `null`이다. |
| `MyProfileScreen._save` | 닉네임이 변경됨 | 사진 처리 전에 PATCH를 완료한다. | PATCH 실패 시 화면에 남고 사진 POST를 호출하지 않는다. |
| `MyProfileScreen._save` | PATCH 실패 | `_isSaving`을 해제하고 오류를 표시한다. | 오류: `프로필을 저장하지 못했어요. 다시 시도해 주세요.` |
| `MyProfileScreen._save` | 선택 사진의 bytes 읽기 실패 | 선택 사진과 미리보기를 제거하고 화면에 남는다. | 오류: `사진을 불러오지 못했어요.` |
| `MyProfileScreen._save` | 사진 POST 실패 | 선택 사진과 미리보기만 제거한다. | provider의 기존 서버 `profileImageUrl`과 저장된 nickname은 유지한다. |
| `MyProfileScreen` 렌더링 | 로컬 `_previewBytes` 존재 | `Image.memory`로 로컬 미리보기를 표시한다. | `_previewBytes` 초기값은 `null`이다. |
| `MyProfileScreen` 렌더링 | 로컬 미리보기 없음 | `AuthenticatedNetworkImage`로 서버 URL을 표시한다. | URL이 없거나 로딩 실패하면 `Icons.person_outline_rounded` fallback을 표시한다. |
| `UserProfileService.uploadProfileImage` | 이전 미디어 ID가 `null` | 이전 미디어 정리를 건너뛴다. | 첫 사진 등록은 새 미디어만 생성한다. |
| `UserProfileService.uploadProfileImage` | 이전/새 미디어 ID가 같음 | 정리를 건너뛴다. | 방어 분기이며 일반 업로드에서는 새 ID가 생성된다. |
| `MediaService.deleteUserProfileMedia` | 소유자·프로필 미디어 조건에 맞는 행이 없음 | 즉시 반환한다. | 예외 없이 멱등적으로 취급한다. |
| `MediaService.deleteUserProfileMedia` | 트랜잭션 synchronization 활성 | DB 삭제 후 `afterCommit`에서 파일을 삭제한다. | 롤백이면 이전 파일은 보존된다. |
| `MediaService.deleteUserProfileMedia` | transaction synchronization 비활성 | DB 삭제 뒤 즉시 파일 삭제를 시도한다. | 파일 삭제 실패는 best-effort로 무시한다. |

## 회귀 위험·수동 QA

| 위험 시나리오 | 예상 결과 | 수동 QA 절차 |
|---|---|---|
| 첫 사진 등록 | 닉네임은 유지되고 새 사진 URL이 표시된다. | 사진 없는 계정으로 `/my/profile` 진입 → 사진 선택 → 저장 → 설정 화면 재진입 후 새 사진 확인 |
| 기존 사진 교체 성공 | 새 사진만 표시되고 이전 URL은 더 이상 프로필에 연결되지 않는다. | 기존 사진 계정에서 다른 사진 선택 → 저장 → 화면 재진입 → 새 사진만 표시되는지 확인 |
| 기존 사진 교체 실패 | 이전 서버 사진이 유지되고 선택 미리보기는 사라진다. | 네트워크를 차단하거나 사진 POST를 5xx로 만들기 → 닉네임과 사진 변경 후 저장 → 부분 성공 안내·이전 사진 확인 |
| 닉네임 PATCH 실패 | 사진 POST가 호출되지 않고 화면에 오류가 남는다. | PATCH를 4xx/5xx로 만들기 → 닉네임·사진 변경 후 저장 → 오류와 사진 업로드 미호출 확인 |
| 빈/51자 닉네임 | HTTP 요청 없이 입력 오류가 표시된다. | 각각 빈 문자열, 51자 문자열 입력 후 저장 → 네트워크 로그에 PATCH/POST가 없는지 확인 |
| 저장 중 연속 탭 | PATCH/POST가 각각 한 번만 호출된다. | 느린 PATCH 응답을 만들기 → 저장 버튼을 연속 탭 → 버튼·사진 선택 비활성 및 요청 1회 확인 |
| 사진 파일 형식/크기 오류 | 서버가 사진을 거부하고 기존 서버 사진은 유지된다. | 지원하지 않는 확장자 또는 5MB 초과 파일 선택 → 저장 → 실패 안내와 기존 사진 확인 |
| 인증 상태 갱신 | 성공 응답의 nickname/URL이 My·Home 등 auth profile 소비 화면에 반영된다. | 저장 후 화면을 나갔다가 프로필을 표시하는 다른 화면으로 이동 → 최신 nickname/사진 확인 |
| 직접 URL 진입 | pop 가능한 스택이 없으면 `/my/settings`로 이동한다. | 브라우저/딥링크로 `/my/profile` 직접 진입 → 저장 또는 뒤로가기 → 설정 화면 도착 확인 |

## 테스트 변경·삭제 내역

| 구분 | 파일 | 변경 | 이유 |
|---|---|---|---|
| 추가 | `frontend/test/services/auth_service_test.dart` | PATCH method/path/body, multipart `file` 필드·원본 파일명, ID·사진 URL 파싱 테스트 | 서비스 요청 계약을 고정한다. |
| 수정 | `frontend/test/providers/auth_provider_test.dart` | 닉네임 성공, 사진 성공, 사진 실패 후 최신 nickname 유지 테스트 추가 | 실패 시 인증 상태가 되돌아가지 않는 정책을 검증한다. |
| 수정 | `frontend/test/screens/my/my_subscreens_test.dart` | 로컬 미리보기, PATCH→POST 순서, 사진 실패 fallback, PATCH 실패 시 사진 미호출, 입력 검증, 중복 저장 잠금 테스트 추가 | 화면 저장 알고리즘과 사용자 피드백 회귀를 방지한다. |
| 수정 | `backend/src/test/java/com/petyilgi/user/UserProfileIntegrationTest.java` | GET/PATCH/POST의 `id` assertion과 사진 2회 업로드 후 이전 DB 행·파일 정리 테스트 추가 | API 응답 호환성과 최신 사진 1장 정책을 검증한다. |
| 삭제 | 없음 | 삭제된 테스트 없음 | 기존 테스트를 무력화하거나 제거하지 않았다. |

## 검증 기록·남은 확인

| 명령/검사 | 결과 | 비고 |
|---|---|---|
| `backend\\gradlew.bat testClasses` | 통과 | 백엔드 코드와 테스트 컴파일 확인 |
| 대상 Flutter 서비스/provider/화면 테스트 | 통과(30개) | Flutter cached tool을 Dart에서 직접 실행해 wrapper 정지를 우회했다. |
| 대상 Dart analyze | 통과 | 이후 중복 저장 회귀 테스트를 추가한 뒤에는 실행 승인 한도로 재실행하지 못했다. |
| `UserProfileIntegrationTest` | 미통과(환경 차단) | Docker daemon이 없어 Testcontainers 초기화 전 실패했다. `127.0.0.1:2375`, `docker_engine` pipe 모두 미가동이었다. |
| 전체 `flutter test`, `flutter analyze --no-fatal-infos` | 미실행 | 마지막 테스트 변경 후 실행 승인 한도 제한으로 수행하지 못했다. |
| Korean mojibake 검사, `git diff --check` | 통과 | 문서 UTF-8 및 공백 오류를 확인했다. |
