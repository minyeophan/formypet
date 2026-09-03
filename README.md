# 포마펫 (For My Pet)

반려동물의 일상 기록, 루틴 관리, 커뮤니티 활동을 한 곳에서 관리하는 반려동물 케어 서비스입니다.

[사진 첨부 예정]

## 프로젝트 소개

포마펫(For My Pet)은 반려동물의 급식, 음수, 산책, 건강 상태, 병원 방문, 이상 증상 등을 체계적으로 기록하고, 루틴과 커뮤니티로 관리·정보 공유를 돕는 서비스입니다.

내부 프로젝트명과 기본 데이터베이스 이름은 `formypet`, 백엔드 패키지는 `com.formypet`, Android/iOS 앱 식별자는 `com.formypet.frontend`입니다. 사용자에게 표시되는 서비스명은 포마펫(For My Pet)입니다.

기존 개발 환경을 사용 중이라면 [이름 변경 후 설정 안내](docs/FORMYPET_RENAME.md)를 확인하세요. 코드 이름 변경만으로 기존 데이터베이스나 외부 서비스 등록값이 자동 변경되지는 않습니다.

## 주요 기능

| 영역 | 상태 | 설명 |
| --- | --- | --- |
| 반려동물 프로필 | 구현됨 | 반려동물 등록, 조회, 수정, 활성 반려동물 전환, 프로필 사진 업로드를 지원합니다. |
| 활동 기록 | 구현됨 | 급식, 음수, 배변, 산책, 몸무게, 병원, 영양, 일기, 기타 기록을 날짜 기준으로 입력하고 조회합니다. |
| 루틴 | 부분 구현 | 루틴 생성·삭제·오늘 조회·완료 체크와 별도 일정 CRUD가 API에 연동되어 있습니다. 루틴 수정 화면은 아직 없습니다. |
| 커뮤니티 | 구현됨 | 피드·글쓰기·좋아요·상세·이미지·투표·카테고리·댓글·답글 API/UI가 연동되어 있습니다. 인앱 알림 백엔드도 구현되어 있으며 UI는 보류 중입니다. |
| 지갑 | 부분 구현 | 지갑 요약과 지출 생성·목록·상세·수정·삭제 API/UI가 연동되어 있습니다. 항목·사진 첨부는 후속 범위입니다. |
| 일정 | 부분 구현 | 반려동물 일정 생성·목록·상세·수정·삭제 API/UI가 연동되어 있습니다. 지도 검색과 알림 실행은 후속 범위입니다. |

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

### 2. 백엔드 실행

```powershell
cd backend
.\gradlew.bat bootRun
```

운영 환경에서는 `JWT_SECRET` 환경 변수를 반드시 설정해야 합니다. 로컬 개발 설정에는 기본값이 있지만, 운영 배포에 그대로 사용하면 안 됩니다.

### 3. 프론트엔드 실행

```powershell
cd frontend
flutter pub get
flutter run
```

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
