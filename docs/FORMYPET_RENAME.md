# 포마펫 이름 변경 후 설정

## 현재 이름

- 백엔드 패키지 및 Gradle group: `com.formypet`
- 백엔드 실행 클래스: `com.formypet.FormypetApplication`
- Android applicationId / namespace: `com.formypet.frontend`
- iOS Bundle ID: `com.formypet.frontend`
- 기본 DB 이름 및 개발용 DB 사용자: `formypet`
- 앱 표시 이름: `포마펫`

Flutter 패키지 이름 `frontend`는 그대로 유지합니다. `package:frontend/...`는 이전 브랜드명이 아니라 프로젝트 모듈 이름입니다.

## 기존 데이터베이스 보존

이번 변경은 기존 DB, 사용자, Docker 볼륨을 삭제하거나 이전하지 않습니다.
기존 MySQL 데이터가 있는 볼륨에서는 Compose의 `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`를 변경해도 새 DB나 사용자가 자동 생성되지 않습니다.

기존 데이터를 계속 사용할 때에는 실행 환경의 `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`에 기존 연결 정보를 설정하세요. 연결 정보는 Git에 커밋하지 마세요.
Compose를 다시 실행할 때에도 셸 환경변수 `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`를 기존 DB 값으로 지정할 수 있습니다. 기본값은 새 이름을 사용하며 헬스 체크도 지정한 사용자 정보를 따릅니다.
새 이름의 DB로 완전히 전환하려면 백업 후 새 DB/사용자를 생성하고 데이터를 복원하는 별도 이전 작업이 필요합니다. `docker compose down -v`로 볼륨을 지워서 해결하지 마세요.

기본 application.yml은 로컬 MySQL 3306 포트입니다. 저장소의 Docker Compose는 호스트 3307 포트를 사용하므로 이 구성으로 실행할 때에는 `SPRING_DATASOURCE_URL`에서 포트를 3307로 지정하세요.

기본 개발용 JWT 비밀값도 이름이 변경됩니다. 기존 기본값으로 발급된 로그인 토큰은 다시 로그인해야 합니다. 운영에서는 기존 `JWT_SECRET` 환경변수를 유지하세요.

## 외부 서비스와 앱 설치

- 네이버 Maps에 Android 패키지 이름과 iOS Bundle ID를 새 값으로 등록합니다.
- 카카오 개발자센터의 Android/iOS 플랫폼 설정도 새 앱 식별자로 갱신합니다. Android 키 해시와 iOS URL scheme 등 별도 값은 해당 설정을 확인하고 유지합니다.
- Firebase, 푸시, 서명 프로필, 스토어 등록을 이미 구성했다면 새 식별자에 대한 설정을 별도로 확인해야 합니다.
- 앱 식별자 변경은 기존 설치 앱의 업데이트와 다릅니다. 새 앱으로 설치되며 로컬 데이터와 로그인 정보는 자동 이전되지 않습니다. 기존 앱은 확인이 끝날 때까지 삭제하지 마세요.
- 이미 출시한 앱은 이 변경을 기존 앱 업데이트로 올리기 전에 스토어 식별자 제약을 확인해야 합니다.
- Hot Reload 대신 앱 실행을 종료한 뒤 다시 빌드하세요. IDE의 이전 Java 실행 설정이 남아 있으면 새 실행 클래스를 선택하세요.
