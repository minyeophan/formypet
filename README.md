# 포마펫 (For My Pet)

반려동물의 일상 기록, 루틴 관리, 커뮤니티 활동을 한 곳에서 관리하는 반려동물 케어 서비스입니다.

[사진 첨부 예정]

## 프로젝트 소개

포마펫(For My Pet)은 반려동물의 급식, 음수, 산책, 건강 상태, 병원 방문, 이상 증상 등을 체계적으로 기록하고, 루틴과 커뮤니티로 관리·정보 공유를 돕는 서비스입니다.

내부 프로젝트명과 기본 데이터베이스 이름은 `formypet`, 백엔드 패키지는 `com.formypet`, Android/iOS 앱 식별자는 `com.formypet.frontend`입니다. 사용자에게 표시되는 서비스명은 포마펫(For My Pet)입니다.

내부 프로젝트명과 외부 서비스 설정값을 변경할 때는 데이터베이스, 앱 식별자, 플랫폼별 서비스 등록값을 함께 확인해야 합니다.

## 주요 기능

| 영역 | 상태 | 설명 |
| --- | --- | --- |
| 반려동물 프로필 | 구현됨 | 반려동물 등록, 조회, 수정, 활성 반려동물 전환, 프로필 사진 업로드를 지원합니다. |
| 활동 기록 | 구현됨 | 급식, 음수, 배변, 산책, 몸무게, 병원, 영양, 일기, 기타 기록을 날짜 기준으로 입력하고 조회합니다. |
| 루틴 | 구현됨 | 루틴 생성·목록·상세·수정·삭제·오늘 조회·완료 체크가 API/UI에 연동되어 있습니다. |
| 커뮤니티 | 구현됨 | 피드·검색·글쓰기·좋아요·상세·이미지·투표·카테고리·댓글·답글을 지원합니다. 게시글 신고, 작성자 차단·해제와 차단 콘텐츠 숨김을 제공합니다. |
| 고객지원 | 구현됨 | 1대1 문의·게시글 신고를 DB에 접수하고 운영자 이메일 발송 대기열에 저장합니다. 실제 Gmail 발송은 로컬 SMTP 설정과 수신 검증이 필요합니다. |
| 나의 커뮤니티 활동 | 구현됨 | 마이페이지에서 작성한 글·공감한 글·댓글 남긴 글을 활동 최신순으로 조회합니다. 탭별 목록 유지, 새로고침·추가 로딩, 게시글 상세와 내 댓글·답글 위치 이동을 지원합니다. |
| 지갑 | 구현됨 | 지갑 요약과 지출 생성·목록·상세·수정·삭제, 기간별 조회가 API/UI에 연결되어 있습니다. 지출 사진 첨부는 현재 범위에서 제외합니다. |
| 일정 | 구현됨 | 반려동물 일정 생성·목록·상세·수정·삭제와 루틴 관리가 API/UI에 연결되어 있습니다. 장소는 직접 입력하며 지도 검색은 제공하지 않습니다. 실제 서버·푸시 연동 검증은 기능과 화면 완성 후 진행합니다. |

## 화면 미리보기

### 홈

[사진 첨부 예정]

### 반려기록

[사진 첨부 예정]

### 루틴

[사진 첨부 예정]

### 커뮤니티

[사진 첨부 예정]

### 마이

[사진 첨부 예정]

## 아키텍처

Flutter 앱이 사용자 화면과 상태 관리를 담당하고, Dio 기반 API 클라이언트로 Spring Boot 백엔드와 통신합니다. 백엔드는 인증, 반려동물, 기록, 루틴, 커뮤니티 도메인 API를 제공하며 JPA와 Flyway를 통해 MySQL 스키마와 데이터를 관리합니다.

```text
Flutter + Riverpod + go_router
        ↓
Spring Boot + JPA + Flyway
        ↓
MySQL
```

[사진 첨부 예정]

## ERD

[사진 첨부 예정]

## CI/CD

현재 자동 배포 파이프라인은 구축 전입니다. 이후 테스트, 빌드, 배포 흐름이 확정되면 이 섹션에 구조와 결과 이미지를 추가합니다.

[사진 첨부 예정]

## 기술 스택

### Frontend

- Flutter
- Riverpod
- go_router
- Dio

### Backend

- Java 21
- Spring Boot
- JPA
- Flyway
- MySQL

### Test

- JUnit
- Testcontainers
- Flutter test

## 로컬 실행

### 1. MySQL 실행

```powershell
cd backend/docker
docker compose up -d
```

MySQL 실행 전 `MYSQL_ROOT_PASSWORD`, `MYSQL_USER`, `MYSQL_PASSWORD` 환경 변수를 설정해야 합니다.

### 2. 백엔드 실행

```powershell
cd backend
.\gradlew.bat bootRun
```

백엔드 실행 전 `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `JWT_SECRET` 환경 변수를 설정해야 합니다. 비밀번호와 JWT 비밀값은 저장소에 기록하지 않습니다.

### 3. 프론트엔드 실행

```powershell
cd frontend
flutter pub get
flutter run
```

## 신고·문의 운영

신고·문의는 인증된 사용자 기준으로 DB에 접수합니다. 접수 성공과 이메일 발송 성공은 별개이며, 메일 장애가 나도 접수는 유지됩니다. 같은 요청의 재시도는 같은 접수번호를 반환합니다. 신고만으로 게시글이 삭제되거나 작성자가 차단되지는 않습니다. 운영자가 접수 메일을 확인하고 수동으로 대응하며 문의 메일의 답장 주소는 사용자가 입력한 이메일입니다.

백엔드 작업 디렉터리의 `.env.support`는 Git에서 제외됩니다. 다음 항목을 로컬에 설정합니다. Gmail은 2단계 인증을 설정한 계정의 앱 비밀번호를 사용하며 일반 로그인 비밀번호를 넣지 않습니다. 계정 정책상 앱 비밀번호를 사용할 수 없다면 발송 인증 방식을 별도로 구성해야 합니다.

```properties
SUPPORT_MAIL_ENABLED=false
SUPPORT_MAIL_USERNAME=
SUPPORT_MAIL_RECIPIENT=
SUPPORT_MAIL_PASSWORD=
```

발신·수신 주소와 앱 비밀번호를 입력한 뒤 `SUPPORT_MAIL_ENABLED=true`로 변경하고 백엔드를 재시작합니다. 발송자는 포마펫 고객지원으로 표시됩니다. Gmail SMTP 587 포트와 필수 STARTTLS를 사용합니다. 실제 앱 비밀번호와 로컬 설정 파일은 커밋하지 않습니다. 자동 테스트에서는 실제 이메일을 보내지 않습니다.

실패한 메일은 1분·5분·30분·2시간 간격으로 재시도하며 총 5회 시도 후 `FAILED`로 남습니다. 서버가 중단된 작업은 5분 임대 만료 후 다시 처리합니다. SMTP 특성상 발송 직후 서버 중단 시 중복 메일이 가능하므로 접수번호로 구분합니다. 차단 관계는 한 방향이며, 차단 대상의 글·알림은 숨기고 댓글은 내용 없는 자리표시자로 남겨 다른 사용자의 답글을 보존합니다. 해제하면 기존 콘텐츠를 다시 조회할 수 있으며 차단 중 생성하지 않은 알림은 소급 발송하지 않습니다.

운영 DB에서 발송 실패를 확인하는 조회:

```sql
SELECT id, ticket_id, attempts, last_error
FROM support_mail_outbox WHERE status = 'FAILED' ORDER BY id;
```

원인을 해결한 뒤 선택한 항목만 재처리합니다. 다음 `?`에는 위 조회로 확인한 outbox ID를 바인딩합니다. 이미 수신된 메일인지 접수번호로 먼저 확인합니다.

```sql
UPDATE support_mail_outbox
SET status = 'PENDING', attempts = 0, next_attempt_at = UTC_TIMESTAMP(6),
    lease_until = NULL, claim_token = NULL, last_error = NULL
WHERE id = ? AND status = 'FAILED';
```

소식은 기존 커뮤니티의 `NEWS` 게시판을 사용하며 `users.role=ADMIN`인 계정만 작성·수정할 수 있습니다. 운영 계정의 소유자를 확인한 뒤 DB 담당자가 권한을 지정하고 다시 로그인해 반영합니다. 일반 사용자가 스스로 권한을 올리는 API는 제공하지 않으며, 관리자도 다른 작성자의 글 수정 권한을 얻지는 않습니다.

## 검증 명령

### Backend

```powershell
cd backend
.\gradlew.bat test
```

### Frontend

```powershell
cd frontend
flutter test
flutter analyze --no-fatal-infos
```

### 문서와 한글 인코딩

```powershell
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-korean-mojibake.ps1
```

## 참고 문서

- [문서 목록](docs/README.md)
- [아키텍처](docs/ARCHITECTURE.md)
- [백엔드 상태](docs/BACKEND_STATUS.md)
- [프론트엔드 상태](docs/FRONTEND_STATUS.md)
- [알림 상태](docs/NOTIFICATIONS_STATUS.md)

## 이미지 추가 방법

현재 README의 이미지 영역은 `[사진 첨부 예정]`으로 남겨두었습니다. 이후 대표 이미지, 화면 미리보기, 아키텍처, ERD, CI/CD 이미지가 준비되면 해당 문구만 이미지 Markdown으로 교체하면 됩니다.
