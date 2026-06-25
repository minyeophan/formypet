# 포마펫 (For My Pet)

반려동물의 일상 기록, 루틴 관리, 커뮤니티 활동을 한 곳에서 관리하는 반려동물 케어 서비스입니다.

[사진 첨부 예정]

## 프로젝트 소개

포마펫(For My Pet)은 반려동물의 급식, 음수, 산책, 건강 상태, 병원 방문, 이상 증상 등을 체계적으로 기록하고, 루틴과 커뮤니티로 관리·정보 공유를 돕는 서비스입니다.

현재 저장소 내부 패키지명, 앱 식별자, 데이터베이스 이름에는 기존 개발명인 `petyilgi`가 남아 있습니다. 외부 서비스명은 포마펫(For My Pet)으로 표기합니다.

## 주요 기능

| 영역 | 상태 | 설명 |
| --- | --- | --- |
| 반려동물 프로필 | 구현됨 | 반려동물 등록, 조회, 수정, 활성 반려동물 전환, 프로필 사진 업로드를 지원합니다. |
| 활동 기록 | 구현됨 | 급식, 음수, 배변, 산책, 몸무게, 병원, 영양, 일기, 기타 기록을 날짜 기준으로 입력하고 조회합니다. |
| 루틴 | 부분 구현 | 루틴 생성, 삭제, 오늘 루틴 조회, 완료 체크는 API와 연동되어 있습니다. 루틴 수정 화면과 일정 저장은 아직 준비 중입니다. |
| 커뮤니티 | 부분 구현 | 피드 조회, 글쓰기, 좋아요는 API와 연동되어 있습니다. 상세, 댓글, 이미지·투표 표시와 투표 참여는 추가 구현이 필요합니다. |
| 지갑 | 진행 중 | 지갑 요약, 지출 리포트, 비용 추가 화면은 있으나 지출 저장, 항목 추가, 사진 첨부는 아직 준비 중입니다. |
| 일정 | 진행 중 | 루틴 화면에서 일정 목록과 일정 추가 UI를 제공하지만, 목록은 샘플이며 저장 API 연동은 아직 준비 중입니다. |

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
- [프론트엔드 구현 현황](docs/FRONTEND_STATUS.md)

## 이미지 추가 방법

현재 README의 이미지 영역은 `[사진 첨부 예정]`으로 남겨두었습니다. 이후 대표 이미지, 화면 미리보기, 아키텍처, ERD, CI/CD 이미지가 준비되면 해당 문구만 이미지 Markdown으로 교체하면 됩니다.
