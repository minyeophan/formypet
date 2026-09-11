# 프로젝트 미완료 항목 점검

점검일: 2026-09-11. 현재 `C:\formypet` 작업 디렉터리 기준.

작업 순서 확인: 사용자 방침은 **기능·화면 완성 후 서버 연동**이다. 아래 서버 주소·운영 설정·배포·외부 서비스 검증은 후속 단계 체크리스트이며, 현재 화면 작업을 막는 선행 과제로 취급하지 않는다. 기존 API 코드의 존재 여부는 구현 상태를 구분하기 위한 참고다.

전체 실행 계획: `docs/superpowers/plans/2026-09-11-release-completion.md`. 게시글 신고·1대1 문의는 각각 입력 화면을 제공하고, DB 접수 저장과 운영자 이메일 발송을 공통 처리하는 방식으로 계획했다. 이번 계획 작성 시 실제 접수·이메일 기능을 구현하거나 메일을 보내지는 않았다.

사용자 범위 확정 및 후속 반영:

- 게시글에서만 신고·작성자 차단 진입을 제공한다. 댓글·답글의 신고·차단 버튼을 제거했다. 본인 댓글 수정·삭제와 기존 게시글 작성자의 댓글 삭제 권한은 유지한다. 관리 권한이 없는 댓글·답글은 빈 더보기 버튼도 숨긴다.
- 작업 브랜치: `feat/release-scope-cleanup`.
- 테마 설정: 기능 범위에서 삭제하고 설정 메뉴 제거.
- 지도 검색: 일정 만들기·일정 수정의 공통 폼에서 버튼 제거. 장소 직접 입력·저장은 유지.
- 지출 사진: 현재 화면에 없으므로 이번 범위에서 제외.
- 반려로그: 출시 후 추가. 현재 출시 미완료 항목에서 제외.
- 공동집사: 출시 후 추가. 현재 출시 미완료 항목에서 제외.
- 뉴스: 새 화면 추가 없이 기존 게시글 작성 화면에서 관리자 계정이 커뮤니티 `NEWS`(소식) 카테고리에 글을 작성하는 방식. 일반 사용자는 열람 가능, 작성·수정 불가. 권한 필드·API 차단·글쓰기 선택지 제한을 구현했으며 실제 관리자 계정 생성과 홈 뉴스의 서버 데이터 연결은 서버 연동 단계에서 진행.
- 필수 미디어 소스: Git 제외 규칙 수정 및 소스 4개·테스트 1개를 Git 인덱스에 추가. 커밋·push는 하지 않음.

용어 설명: 이 문서의 **검색**은 커뮤니티 상단 돋보기 → 게시글 검색(`/community/search`)이며, **문의**는 마이 → 고객지원 → 1대1 문의하기(`/my/inquiry`)다. 하나의 “검색문의” 기능이 아니다. 지도 버튼은 제거 전 일정 만들기(`/routine/schedule/new`)와 일정 수정(`/routine/schedule/:scheduleId/edit`)에 있었고, 일정 상세는 장소 텍스트만 표시한다.

Flutter 화면·라우터·서비스·상태 관리, Spring Controller·서비스, DB migration, 플랫폼 설정, 테스트와 상태 문서를 대조했다. 파일 목록 기준 Flutter 앱 소스 136개, Flutter 테스트 파일 89개, Java 앱 소스 111개, Java 테스트 파일 24개, migration 26개가 있다. 바이너리 에셋·생성물·과거 worktree는 기능 구현 판정 대상에서 제외했다. 비밀값은 읽거나 보고서에 기록하지 않았다.

아래의 **미구현**은 실제 버튼·메뉴·후속 범위가 있으나 기능이 없는 경우다. **부분 구현**은 동작하는 부분과 남은 부분을 구분했다. **범위 확인**은 현재 코드에는 없지만 필수 요구사항으로 확정할 근거가 부족한 항목이다. 정적 점검이 모든 실행 경로의 정상 동작을 보장하지는 않는다.

## 1. 저장소 및 향후 서버 연동·배포 시 확인할 항목

### P1-01. 필수 미디어 소스가 Git에서 제외됨 — 수정 및 Git 추적 반영

- `.gitignore:28`의 `storage/` 규칙이 런타임 업로드 디렉터리뿐 아니라 Java 패키지에도 적용된다.
- `backend/src/main/java/com/formypet/media/storage/`의 `MediaStorage.java`, `LocalMediaStorage.java`, `LoadedMedia.java`, `StoredMedia.java`가 로컬에 존재하지만 Git 추적 대상에 없다.
- 관련 `backend/src/test/java/com/formypet/media/storage/LocalMediaStorageTest.java`도 제외된다.
- `MediaService`와 `MediaCleanupRunner`가 이 타입들을 import하므로 현재 PC의 빌드와 새 clone의 빌드가 달라진다. 새 clone에는 컴파일에 필요한 타입이 빠진다.
- 처리: `storage/`를 `/storage/`로 변경하고 기존 `backend/storage/` 규칙은 유지했다. 아래 소스·테스트 5개를 `git add`로 추적 대상에 추가했다. 런타임 업로드 파일은 계속 제외된다. 새 clone에 전달하려면 이 변경의 커밋·push가 필요하다.
- 확인 명령: `git check-ignore -v backend/src/main/java/com/formypet/media/storage/MediaStorage.java`, `git ls-files --others --ignored --exclude-standard backend/src`.

### P1-02. 운영 서버 접속 설정이 없음 — 확인됨

- `frontend/lib/main.dart:80`에서 Web은 `http://localhost:8080`, 그 외 플랫폼은 `http://10.0.2.2:8080`으로 고정된다.
- 서버 주소를 환경별로 주입하는 경로가 없어 실기기·운영 Web에서 그대로 사용할 수 없다.
- `backend/src/main/java/com/formypet/config/SecurityConfig.java`도 Web 허용 origin이 localhost/127.0.0.1에 한정된다.
- 남은 일: 개발·실기기·운영 API 주소와 운영 Web origin을 설정으로 분리하고 실제 HTTPS 환경에서 확인.

### P1-03. iOS 플랫폼 연결 설정이 미완성 — 저장소 기준 확인됨

- `frontend/ios/Runner/Info.plist`에 사진 접근 사용 설명, 카카오 URL scheme·앱 조회 설정이 없다. 앱은 실제로 갤러리 선택과 카카오 SDK 로그인을 호출한다.
- `GoogleService-Info.plist`는 로컬에 존재하지만 `Runner.xcodeproj/project.pbxproj`에서 리소스 등록을 확인하지 못했다.
- 저장소에 푸시 entitlement 및 프로젝트의 `CODE_SIGN_ENTITLEMENTS`, background notification 설정도 확인되지 않는다.
- 남은 일: Xcode 리소스·권한·카카오 콜백·푸시 capability 연결, iOS 실기기에서 초기 실행/로그인/사진/알림 확인. Apple/Firebase 콘솔 설정 상태는 이번 점검에서 확인하지 않았다.

### P1-04. Android 배포 서명이 개발용 — 확인됨

- `frontend/android/app/build.gradle.kts:38`에서 release도 debug signing config를 사용한다.
- 남은 일: release 서명 주입과 배포 빌드 검증. 앱 ID 옆의 기본 TODO 주석만으로 앱 ID 자체를 오류로 판단하지 않았다.

## 2. 화면에서 실제로 사용할 수 없는 기능

| ID | 영역 | 현재 상태·근거 | 남은 작업 |
|---|---|---|---|
| F-01 | 홈 반려로그 — 출시 후 | `frontend/lib/screens/home/home_screen.dart`의 메뉴가 `onPreparing`만 호출 | 사용자가 출시 후 추가로 확정. 이번 출시 범위에서 제외 |
| F-02 | 오늘의 뉴스 — 관리자 소식으로 운영 | 현재 홈은 고정 기사 3개. 콘텐츠는 관리자 계정이 커뮤니티 NEWS에 작성하는 방식으로 확정 | 실제 관리자 계정 생성 및 홈 목록/상세를 NEWS 게시글에 연결하는 것은 서버 연동 단계 |
| F-03 | 공동집사 관리 — 출시 후 | `frontend/lib/screens/my/my_screen.dart`에 메뉴만 있고 route 없음. 소유권 로직은 단일 사용자 기준 | 사용자가 출시 후 추가로 확정. 이번 출시 범위에서 제외 |
| F-04 | 지도에서 찾기 — 삭제 완료 | 일정 생성·수정 공통 폼에서 검색 버튼과 검색 안내 제거 | 장소 직접 입력만 유지. 추가 구현 대상에서 제외 |
| F-05 | 1대1 문의 | `frontend/lib/screens/my/my_inquiry_screen.dart:45`에 미제공 안내, 입력과 접수 버튼 비활성. 대응 API 없음 | 입력·DB 접수·운영자 이메일 전달 및 이메일 회신. 앱 내 문의함·답변 화면은 초기 범위 제외 |
| F-06 | 테마 설정 — 삭제 완료 | `frontend/lib/screens/my/my_settings_screen.dart`에서 메뉴 제거 | 추가 구현 대상에서 제외 |
| F-07 | 게시글 신고 | `frontend/lib/screens/community/community_detail_screen.dart:366`이 준비중. 댓글 신고 API와는 별개 | 게시글 신고 접수 API·UI |
| F-08 | 사용자 차단 | `frontend/lib/screens/community/community_comments_screen.dart:574`의 report/block 분기가 모두 준비중 | 댓글 report/block 진입 제거. 게시글 더보기에서 작성자 차단, 관계 저장·콘텐츠 노출 정책·설정에서 해제 |
| F-09 | 댓글 인기순·이미지 첨부 | `community_comments_screen.dart:497`, `community_comments_widgets.dart:665`가 준비중 | 인기 정렬 기준/API, 댓글 이미지 저장·표시 |

## 3. 일부 구현됐지만 연결이 끝나지 않은 기능

### I-01. 댓글 신고 — 출시 범위 제외, UI 진입 제거 완료

- Backend `CommunityController.java:151` 및 Flutter `services/community_service.dart:212`에 댓글 신고가 구현되어 있다.
- 기존 댓글 메뉴는 준비중 토스트로 끝났으며 이번 브랜치에서 신고·차단 메뉴 및 처리 분기를 제거했다. `reportComment`의 앱 내 호출처가 없다.
- 확정 범위: 댓글·답글 신고·차단 버튼을 제거한다. 기존 댓글 신고 API·서비스·테이블은 호환성 유지를 위해 남기되 새 접수 ticket이나 이메일과 연결하지 않는다.
- 이번 출시에서 새로 연결하는 신고 대상은 게시글이다. 게시글 신고를 DB에 저장하고 운영자 이메일로 전달하며 검토·제재는 수동 운영한다.

### I-02. 게시글 상세 댓글 관리 연결 — 수정 완료

- 상세 미리보기의 원댓글·답글 관리 버튼에서 원댓글 ID와 선택한 댓글 ID를 전체 댓글 화면으로 전달한다.
- 선택한 댓글 위치에서 기존 수정·삭제 메뉴를 자동으로 열고, 본인/게시글 작성자의 관리 권한을 다시 검사한다.
- 수정·삭제 후 상세로 돌아오면 댓글 목록을 새로 불러온다. 기존 준비중 삭제 함수는 제거했다.
- 전체 댓글 화면 상단 더보기와 인기순·이미지 첨부는 이번 범위에 포함하지 않았다.

### I-03. 커뮤니티 검색 추가 로딩 — 수정 완료

- 사용자 요청에 따라 처음 10개, '더보기' 클릭 시 다음 10개씩 가져온다. 50개 이후에도 cursor가 있으면 계속 조회한다.
- 검색 화면의 기존 상태에 cursor·추가 로딩·재시도를 추가하고, 공통 provider의 searchPage가 응답을 공유 캐시에 반영한다.
- 추가 로딩 실패 시 기존 결과를 유지하며 같은 cursor로 재시도한다. 중복 게시글은 ID 기준으로 합친다.
- 새 검색·계정 변경·검색 지우기 이후 이전 응답을 무시하고, 진행 중인 같은 요청은 중복 전송하지 않는다.
- 상세에서 돌아올 때 검색어·로드한 목록·스크롤 위치를 유지한다. 삭제된 글과 이미 갱신된 좋아요/댓글 수가 이전 검색 응답으로 복원되지 않게 한다.
### I-04. 사용자 전체 예약 알림 설정 UI가 없음 — 기존 문서상 보류

- Backend `/api/v1/notifications/settings`의 조회·변경 API는 있다.
- Flutter `notification_service.dart`는 목록·읽음 처리만 제공하며 설정 화면에 전체 수신 스위치가 없다.
- 개별 루틴의 알림 선택과 사용자 전체 설정은 다른 기능이다.
- `docs/api-screen-inventory.md`는 이 UI를 명시적으로 제외했던 기록을 갖고 있다. 누락 상태로 기록하되, 구현 재개 여부는 범위 결정이 필요하다.

### I-05. 푸시는 루틴·일정 중심으로 연결됨

- `NotificationService.createReminder`는 FCM을 호출하지만 커뮤니티 이벤트용 `create`는 DB 알림만 저장한다.
- `frontend/lib/main.dart`의 푸시 대상 이동도 `CARE_SCHEDULE_REMINDER`, `ROUTINE_REMINDER` 두 종류만 처리한다.
- Web은 `main.dart`와 `push_notification_service.dart`에서 푸시 초기화·토큰 등록 대상에서 제외한다.
- 남은 일: 커뮤니티/Web 외부 푸시까지 제품 범위인지 결정 후 발송·토큰·대상 이동 연결. 현재 인앱 커뮤니티 알림은 구현되어 있다.

### I-06. 푸시 발송 실패 복구와 예약 누락 보완이 없음

- `NotificationService.createReminder`는 DB에 새 알림이 삽입될 때만 푸시를 보낸다.
- `sendEachForMulticast` 결과를 확인하지 않고 예외는 로그만 남긴다. 실패 토큰 정리·발송 상태 저장·재시도 경로가 없다.
- 같은 알림은 중복 삽입 방지 때문에 다음 scheduler 실행에서 푸시만 재시도하지 않는다.
- 예약 작업은 현재 시각에서 `lookback-minutes: 1` 구간만 조회한다. 서버가 더 오래 중단되면 지난 알림을 따라잡는 처리가 없다.
- 남은 일: 발송 결과와 재시도 정책, 무효 토큰 정리, 서버 재시작 후 누락 알림 처리 기준.

### I-07. 지갑 월 예산은 기기 로컬 저장만 구현

- `frontend/lib/services/wallet_budget_service.dart:5`에 명시된 대로 계정·월 기준 SharedPreferences 저장이다.
- 지출 자체는 서버 저장이나 예산 서버 API/테이블은 없다.
- 영향: 다른 기기와 예산이 동기화되지 않고 앱 데이터 삭제 후 서버에서 복원할 수 없다.
- 남은 일: 예산도 계정 데이터로 동기화할지 결정하고 필요하면 API/DB 연결. 로컬 저장 기능 자체의 미구현으로 분류하지 않는다.

### I-08. 일부 이미지 수정 흐름의 지원 범위

- 지출 사진은 사용자가 범위에서 제외했으므로 미완료 작업으로 계산하지 않는다.
- 게시글 수정은 `write_screen.dart`에서 “사진과 투표는 수정할 수 없어요”로 명시적으로 제한한다. 생성 시 사진/투표는 구현되어 있다.
- 활동 기록의 사진 선택은 급식 입력에 있고, 일반 기록 입력·기존 기록 편집에서는 사진 추가/삭제 흐름을 확인하지 못했다. 급식 편집의 기존 사진도 읽기 전용이다.
- 남은 일: 기록 사진 지원 범위, 게시글 사진 교체·삭제와 투표 수정 허용 정책을 각각 결정.

## 4. 계정·운영 콘텐츠·문서

| ID | 상태 | 내용 및 근거 |
|---|---|---|
| O-01 | 임시 콘텐츠 | `frontend/lib/screens/my/my_policy_data.dart`의 이용약관·개인정보·운영·위치·마케팅 문구는 모두 “추후 확정된 전문으로 교체” 상태. 서비스명이 `펫일기`로 남은 문구도 있음 |
| O-02 | 부분 구현 | 공지/FAQ 화면은 `my_support_data.dart`의 정적 목록을 표시. 서버 콘텐츠 관리 API 없음. 문의 미제공인데 FAQ는 문의를 권하고, 이미 가능한 투표를 준비중으로 설명하는 등 내용 갱신 필요 |
| O-03 | 범위 확인 | 이메일 소유 확인, 비밀번호 찾기/재설정·변경, 회원 탈퇴, 약관 동의 버전/시각 저장 흐름을 앱·API·migration에서 확인하지 못함. 이메일/비밀번호 로그인과 소유 확인 메일 인증은 구분해야 함 |
| O-04 | 배포 준비 | CI/CD workflow·배포 설정 없음. Docker Compose는 MySQL만 실행. 운영 앱 배포·백업·미디어 보존 절차는 별도 정리 필요 |
| O-05 | 실행 안내 누락 | `main.dart:82`는 `KAKAO_NATIVE_APP_KEY`가 없으면 시작 시 예외 발생. README의 단순 `flutter run` 안내에는 dart-define이 없고, Android는 별도로 환경변수에서 키를 읽음. Firebase 파일 준비 안내도 보완 필요 |
| O-06 | 문서 불일치 | README는 커뮤니티 검색과 실제 알림 실행을 후속으로 표시하지만 구현 코드가 있음. `BACKEND_STATUS.md`는 migration V24, 실제 최신 V26. `NOTIFICATIONS_STATUS.md`는 이미 있는 알림 UI를 보류로 표시 |
| O-07 | 재현성·문서 공유 | 상태 문서 상당수가 `.gitignore`로 제외되어 새 clone에 전달되지 않음. README에서 안내하는 `scripts/check-korean-mojibake.ps1`와 `docs/ERD.md`는 현재 경로에 없음. `ARCHITECTURE.md`의 과거 화면 경로도 갱신 필요 |
| O-08 | 기본 템플릿 잔존 | `frontend/README.md`, `frontend/web/manifest.json`에 Flutter 기본 프로젝트 설명·이름이 남아 있고 루트 README의 화면/ERD 이미지도 예정 표시 상태 |

## 5. 테스트 구성에서 확인된 미완료 항목

### Q-01. 테스트용 스키마와 외부 푸시 격리가 최신 코드와 맞지 않음

- `backend/src/main/resources/db/migration/V25__add_device_tokens.sql`에는 `device_tokens`가 있지만 `backend/src/test/resources/init-test.sql`에는 없다.
- `IntegrationTestSupport`는 이 초기화 SQL을 사용하며 `application.yml`의 test profile은 Flyway를 끈다. 따라서 일반 통합 테스트가 자동으로 V25를 적용하지 않는다.
- `FirebaseConfiguration`은 test profile에서 제외되지 않으므로 로컬 서비스 계정 파일이 있으면 테스트에서도 Firebase를 초기화할 수 있다.
- `NotificationService.sendPush`의 토큰 SELECT는 예외를 처리하는 try 바깥에 있다. Firebase가 활성화된 환경에서는 누락 테이블 조회 오류가 상위 알림 처리로 전파된다.
- Docker 재실행에서 `NotificationIntegrationTest`의 예약 알림 관련 3개 테스트가 모두 `Table 'formypet_test.device_tokens' doesn't exist`로 실패했다. 스택의 `NotificationService.java:35`는 위 토큰 SELECT와 일치한다.
- 남은 일: 테스트 DB 스키마를 migration과 일치시키고, 테스트의 Firebase/푸시를 실제 로컬 자격증명 유무에 의존하지 않도록 격리. 디바이스 토큰 등록·해제 및 FCM 실패 경로 테스트 추가.

## 6. 미구현으로 잘못 분류하면 안 되는 항목

- 이메일/비밀번호 로그인, 카카오 서버 로그인 처리, 토큰 갱신, 사용자 프로필.
- 반려동물 등록·수정·삭제와 사진 업로드, 지원 활동 기록 CRUD, 성장 기록 화면.
- 루틴 생성·수정·삭제·완료와 케어 일정 CRUD.
- 커뮤니티 기본 검색, 피드·상세·작성·좋아요·투표, 전체 댓글 화면의 댓글/답글 작성·수정·삭제, 나의 활동 목록.
- 지출 CRUD·요약·기간 조회·리포트·달력, 기기 로컬 월 예산.
- 인앱 알림 목록·읽음·대상 이동, 예약 작업 및 루틴/일정 FCM 발송 코드.

위 항목은 대응 코드가 있다는 뜻이며 실기기·외부 서비스까지 모두 검증됐다는 뜻은 아니다. 준비중 토스트 검색 결과 중 라우터가 없을 때의 fallback, 미지원 기록 타입 방어 분기는 정상 기능 누락에서 제외했다.

## 7. 검증 결과

### 최초 전체 점검 결과 — 아래 후속 수정 전

- 정적 분석: 권한 적용 후 `flutter analyze --no-fatal-infos` → **No issues found**, 종료 코드 0. 앞선 직접 Dart SDK 실행의 telemetry 권한 오류는 최종 분석에서 해소됐다.
- 최초 Backend 테스트: 163개 중 16개 통과, 147개 실패. 실패는 Docker/Testcontainers 환경 초기화 단계에서 발생해 기능 결함 수로 해석하지 않는다.
- Docker 실행 후 Flutter 전체 테스트: `flutter test --no-pub --reporter compact` → **773개 전체 통과**, 종료 코드 0.
- Docker 실행 후 Backend 전체 테스트: `gradlew.bat test` → **166개 중 163개 통과, 3개 실패**, 종료 코드 1. 실패는 모두 `NotificationIntegrationTest`의 다음 테스트이며 원인은 Q-01의 테스트 테이블 누락이다.
  - `deletingPendingRemindersKeepsReadAndPastReminders`
  - `reminderWithNullSocialFieldsIsReturnedByNotificationFeed`
  - `reminderInsertIsIdempotentButAllowsDifferentRecipients`
- 재실행 중 겹친 프로세스의 결과 파일 잠금 오류는 해당 프로세스가 종료된 후 단독 실행으로 해소했다. 위 수치는 마지막 실행의 결과다.
- Backend HTML 결과: `backend/build/reports/tests/test/index.html`. 실행 로그: `backend/build/audit-test-final.log`, `frontend/audit-test.log`, `frontend/audit-analyze.log`.
- 이번 점검은 iOS/Android 실기기, 실제 카카오 인증, FCM 실수신, 운영 배포와 백업 복구를 검증하지 않았다. 단위·위젯·API 통합 테스트 통과와 별개로 남는 검증 범위다.

### 사용자 요청 후속 수정 검증

- 브랜치: `feat/release-scope-cleanup`.
- 소식 제한 수정 전: 일반 사용자의 소식 작성 요청이 201로 성공하는 것과 글쓰기에서 소식 선택지가 노출되는 것을 실패 테스트로 재현했다.
- 수정 후 Flutter 관련 화면 테스트 **94개 통과**: 소식 권한, 글쓰기·커뮤니티, My 하위 화면, 일정 생성·수정, 아이콘 화면 회귀. 정적 분석 `No issues found`, 종료 코드 0.
- 수정 후 Backend 관련 테스트 **64개 통과**: 인증 15, 커뮤니티 35, 소식 권한 3, 프로필 6, migration 4, 미디어 저장 1. V27의 기존/신규 계정 기본 USER 권한, 관리자 작성·수정, 일반 사용자 소식 열람과 작성/카테고리 변경 거절을 확인했다.
- Backend 첫 실행은 테스트 완료 후 Gradle 진단 HTML 저장 충돌로 종료 코드 1이었다. 동일 명령 재확인은 테스트가 up-to-date인 상태로 `BUILD SUCCESSFUL`, 종료 코드 0이었다. 실제 64개 테스트 결과는 직전 실행 XML에서 확인했다.
- Git: 소스 4개·테스트 1개의 추적 등록을 `git ls-files`로 확인. 실제 업로드 경로 `/storage/`, `backend/storage/`는 계속 제외되며 `git diff --check`와 cached diff 점검 통과.
- 별도 읽기 전용 코드 검토에서 추가 수정 사항 없음.
- 이번 수정 후 전체 테스트를 다시 실행한 것은 아니며, 최초 점검에서 발견한 Q-01 알림 테스트 문제는 이번 범위에서 수정하지 않았다.
- 로그: `frontend/release-scope-tests.log`, `frontend/release-scope-analyze.log`, `backend/build/release-scope-tests.log`, `backend/build/release-scope-verification.log`.

## 8. 권장 처리 순서

1. 기존 화면 마무리: 게시글 신고·작성자 차단·댓글 신고/차단 진입 제거·댓글 수정/삭제·검색 추가 로딩·1대1 문의의 사용자 흐름을 정리한다. 테마·지도 검색·지출 사진은 제외하고 반려로그·공동집사는 출시 후로 둔다. 뉴스는 관리자 소식 게시글 방식으로 진행한다.
2. 기존 화면 마무리: 게시글 신고·작성자 차단·댓글 신고/차단 진입 제거·댓글 수정/삭제·검색 추가 로딩, 로딩·빈 상태·오류·재시도 흐름을 점검한다. 서버가 필요한 실제 저장·조회 검증은 연동 단계에서 진행한다.
3. 콘텐츠와 UI 검증: 정책·공지·FAQ의 임시 문구를 정리하고 화면 전환·입력·반응형·위젯 테스트를 확인한다. 전체 알림 설정 UI는 기존 보류 범위를 재개할지 결정한다.
4. 기능·화면 완성 후 서버 연동: API 계약·실제 저장/조회·예산 동기화 범위·알림 설정/발송·실패 복구를 검증하고 테스트 스키마 불일치를 해결한다.
5. 연동 이후 운영 준비: 운영 서버 주소·CORS·실행 안내·iOS 외부 서비스 설정·Android release 서명·CI/CD·실기기 검증을 진행한다.

필수 미디어 소스의 Git 누락은 이 브랜치에서 추적 등록까지 마쳤다. 새 clone에도 전달하려면 이 브랜치 변경사항을 커밋·push해야 한다. 운영 서버 연결과 실제 관리자 계정 생성은 아직 진행하지 않았다.

최초 점검에서는 기능 코드를 수정하지 않았으며, 이후 사용자 요청으로 테마·지도 검색 제거, 소식 작성 권한 및 미디어 Git 제외 문제를 이 브랜치에서 수정했다.

### 댓글 신고·차단 메뉴 제거 검증

- 현재 브랜치 범위에 맞춰 댓글·답글의 신고·차단 메뉴와 준비중 처리 분기를 제거했다.
- 본인 수정·삭제, 게시글 작성자의 댓글 삭제 권한은 기존 관리 권한 판단을 재사용한다. 권한이 없는 댓글·답글은 더보기 버튼을 숨긴다.
- 상세 댓글 미리보기는 기존부터 관리 권한에 따른 삭제 메뉴만 제공했다. 실제 삭제 흐름 연결은 다음 브랜치로 남긴다.
- 관련 Flutter 화면 테스트 103개 통과, 종료 코드 0. 댓글/답글 수정·삭제, 게시글 상세, 댓글 작성, 소식 권한, 글쓰기, My, 일정 생성·수정을 포함한다.
- 로그: frontend/release-scope-final-tests.log, frontend/release-scope-final-analyze.log.
- 이번 변경은 Flutter 메뉴와 문서이며 backend 코드는 추가 수정하지 않았다. 기존 Q-01 알림 테스트 결함은 다음 검증 범위로 유지한다.
- 최종 정적 분석: No issues found, 종료 코드 0. git diff --check 및 cached 점검 통과. 커밋·push·병합은 하지 않았다.

### 커뮤니티 상호작용 후속 검증

- 작업 브랜치: fix/community-interactions. 앞선 release-scope-cleanup 변경이 develop에 머지된 상태에서 생성했다.
- 검색 페이지 크기는 사용자 확정값 10개다. 60개까지 추가 조회, 오류 후 재시도, 목록 복귀, 중복 요청/결과, 계정 전환, 삭제/좋아요/댓글 수 경합을 검증했다.
- 상세의 답글 ID 전달, 선택한 댓글 관리 메뉴, 댓글 삭제 후 상세 갱신 및 기존 권한별 수정·삭제를 검증했다.
- 커뮤니티 화면 및 공통 상태 테스트 138개 통과, 종료 코드 0. Flutter 정적 분석 No issues found, 종료 코드 0. git diff --check 통과.
- 로그: frontend/community-interactions-final-tests.log, frontend/community-interactions-analyze.log.
- Backend 변경·실서버/실기기 검증·커밋·push·병합은 이번 실행에서 진행하지 않았다.