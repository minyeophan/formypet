# 포마펫 (For My Pet)

반려동물의 활동 기록, 루틴·일정, 커뮤니티, 지출을 관리하는 Flutter / Spring Boot 서비스입니다.

점검 기준: 2026-09-29, 현재 develop 코드와 대조했습니다. 핵심 API와 화면은 구현되어 있으나 운영 출시 준비는 남아 있습니다.

## 현재 상태

| 영역 | 구현 범위 | 남은 부분 |
| --- | --- | --- |
| 인증·계정 | 이메일·비밀번호 가입/로그인, JWT 갱신·로그아웃, 카카오 로그인, 비밀번호 복구 API(기본 비활성화), 회원 탈퇴 API·Android 화면 | 이메일 소유 확인, 복구 기능의 SMTP·HTTPS 운영 설정, 카카오 TEST 앱·실기기 검증, 탈퇴 후 외부 정리 운영 확인 |
| 반려동물·기록 | 프로필·사진, 9종 기록 CRUD, 상세·수정, 성장 조회 | 대량 기록 조회 성능 검증 |
| 루틴·일정 | 생성·조회·수정·삭제, 완료 체크, Android 예약 알림 | 푸시 장애 재시도·장시간 중단 복구 |
| 커뮤니티 | 피드·검색·글·이미지·투표·댓글·답글·좋아요, 신고·차단·내 활동 | 운영자 신고 처리 화면 |
| 지갑 | 지출 CRUD·달력·요약·리포트, 월 예산 | 예산은 계정/월별 기기 로컬 저장 |
| 고객지원·My | 문의 접수 API, 메일 발송 큐, 프로필·설정·공개 약관·개인정보 페이지와 가입 동의 흐름 | 운영 SMTP 설정·처리 절차, 실제 운영 정보를 반영한 정책 전문 최종 게시 |
| 인프라 | 로컬 MySQL Compose, Flyway V1–V37 | 운영 주소·HTTPS·배포·CI/CD·서명·백업·모니터링 |

홈의 ‘반려로그’는 준비중입니다. 지도 검색, 지출 사진 첨부, iOS/APNs·웹 푸시는 현재 구현 범위에 포함되지 않습니다.

카카오 로그인은 Android 에뮬레이터에서 확인했습니다. 이 확인은 운영용 카카오 앱 설정을 사용했으며, TEST 앱 설정과 실기기 검증은 남아 있습니다.

## 구조와 기술

- Flutter: Riverpod 2, go_router 14, Dio 5, Secure Storage, Firebase Messaging, Kakao SDK.
- Backend: Java 21, Spring Boot 3.4.1, Spring Security, JPA와 JdbcTemplate, Flyway.
- DB: 로컬 Compose MySQL 8.0, 호스트 포트 3308.
- 검증: JUnit / Testcontainers, Flutter 단위·위젯 테스트, Android 통합 테스트 소스.
- 백엔드 패키지: `com.formypet`; 앱 식별자: `com.formypet.frontend`.

## 로컬 실행

아래 명령은 각각 프로젝트 루트에서 시작합니다. 실제 비밀번호와 서비스 키는 Git에 기록하지 않습니다.

### MySQL

`MYSQL_ROOT_PASSWORD`, `MYSQL_USER`, `MYSQL_PASSWORD`를 환경 변수로 설정한 뒤 실행합니다. Compose는 루트 `.env`를 자동으로 찾는다는 전제 없이 명시적으로 전달합니다.

```powershell
docker compose --env-file .env -f backend/docker/docker-compose.yml up -d
```

루트 `.env`에 Compose용 변수가 없다면 먼저 환경 변수로 지정하거나 별도 env 파일을 사용합니다. 기본 DB 이름은 `formypet`입니다.

### 백엔드

`SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`, `JWT_SECRET`이 필요합니다. 계정은 Compose에서 생성한 계정과 일치해야 합니다. JWT 서명에 충분한 길이의 비밀값을 사용합니다.

```powershell
cd backend
.\gradlew.bat bootRun
```

기본 포트는 8083입니다. Spring은 실행 위치의 `.env`, 상위 `.env`, 실행 위치의 `.env.support`를 선택적으로 읽습니다. 기본 JDBC 주소는 `localhost:3308/formypet`입니다. API 문서는 실행한 서버의 `/swagger-ui.html`, 상태 확인은 `/api/v1/health`입니다.

### Flutter (Android 에뮬레이터 기준)

Flutter SDK와 Android SDK, 앱에 맞는 `frontend/android/app/google-services.json`이 필요합니다. 카카오 키는 **OS 환경 변수와 Dart define 양쪽**에 같은 값을 전달합니다.

```powershell
cd frontend
flutter pub get
$env:KAKAO_NATIVE_APP_KEY = '<등록된 네이티브 앱 키>'
flutter run --dart-define="KAKAO_NATIVE_APP_KEY=$env:KAKAO_NATIVE_APP_KEY"
```

현재 `main.dart`는 웹에 `http://localhost:8083`, 그 외 플랫폼에 `http://10.0.2.2:8083`을 고정 사용합니다. 실제 휴대폰·운영 환경에는 주소 설정 개선이 필요합니다. 카카오 키가 비어 있으면 앱 시작이 중단됩니다. 비웹에서는 Firebase 초기화도 앱 시작 전에 수행하므로 플랫폼 설정 누락 시 실행을 보장하지 않습니다.

서버 FCM은 `FIREBASE_CREDENTIALS_PATH`의 서비스 계정 파일이 있어야 발송됩니다. 파일이 없으면 서버는 푸시를 비활성화합니다. 고객지원 메일은 `SUPPORT_MAIL_ENABLED=true`와 `SUPPORT_MAIL_USERNAME/PASSWORD/RECIPIENT` 설정이 필요합니다.

## 검증

```powershell
cd backend
.\gradlew.bat test --no-daemon
```

백엔드 통합 테스트에는 Docker가 필요합니다. 일반 통합 테스트는 격리 MySQL과 `init-test.sql`을 사용하고, `FlywayMigrationTest`는 실제 마이그레이션을 검증합니다.

```powershell
cd frontend
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

테스트 통과는 카카오 콘솔 설정, 실제 FCM·SMTP 전송, 운영 배포 성공을 뜻하지 않습니다.

## 문서

- [아키텍처와 미완성 항목](docs/ARCHITECTURE.md)

로컬 점검 문서 `docs/BACKEND_STATUS.md`, `FRONTEND_STATUS.md`, `NOTIFICATIONS_STATUS.md`, `BACKEND_RULES.md`, `api-screen-inventory.md`도 2026-09-22 기준으로 갱신했습니다. 이 다섯 파일은 기존 `.gitignore` 정책에 따라 Git 추적 대상이 아닙니다.

2026-09-22 실행 기록: 백엔드 213개 통과(실패·오류·건너뜀 0), Flutter 1,043개 통과, Flutter 정적 분석 문제 없음. 이후 변경분을 포함한 현재 전체 테스트 결과는 아닙니다.
