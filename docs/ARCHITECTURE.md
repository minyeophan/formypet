# 코드 구조

## 백엔드

Java 21, Spring Boot 3.5.16, Spring Data JPA, MySQL, Flyway를 사용한다.

`backend/src/main/java/com/formypet/`:

- `domain/`: auth, user, pet, wallet, routine, record, community, media, notification, policy, support, petlog.
- 각 도메인의 `controller`, `dto/request`, `dto/response`, `entity`, `repository`, `service`, `service/impl`에 역할을 나눈다. 필요에 따라 config, scheduling, storage 등 하위 패키지를 둔다.
- `global/`: 공통 설정, 예외/응답, 시간 처리, 멱등 요청, 요청 제한, health, monitoring.

기본 CRUD는 JPA로 처리한다. 커서·통계 조회, 원자적 upsert/용량 제한, current read/잠금, outbox/cleanup 등은 전용 repository의 SQL을 사용한다. 서비스와 컨트롤러에서 직접 SQL이나 DB 행 매핑을 수행하지 않는다.

JPA와 일괄 SQL을 혼용하는 코드는 flush·refresh·잠금 순서를 보존해야 한다. 엔티티는 API DTO에 의존하지 않는다. 스키마 변경은 `backend/src/main/resources/db/migration`의 Flyway migration으로 관리한다.

미디어 저장소는 Local과 Cloudflare R2 구현이 있다. 설정과 실행 환경에 따라 선택하며, 외부 파일 작업과 DB rollback의 차이는 정리 큐와 저장 시도 이력으로 처리한다. [사진 저장 계약](photo-save-contract.md)을 참고한다.

## 프런트엔드

Flutter 화면 → Riverpod provider → service → Dio → 백엔드 API 흐름이다.

- `frontend/lib/core`: API 클라이언트, 토큰, 테마 및 공통 값.
- `models`, `services`, `providers`: 모델, API 호출, 화면 상태.
- `router/app_router.dart`: 인증·온보딩 리다이렉트와 경로.
- `screens`, `widgets`: 화면과 공통 UI.
- API 주소는 빌드 시 `API_BASE_URL`로 지정한다. 외부 로그인·푸시는 각 환경의 별도 설정이 필요하다.

## 검증

저장소 루트에서 실행한다. 백엔드 통합 테스트에는 Docker가 필요하다.

```powershell
.\backend\gradlew.bat -p backend test bootJar --no-daemon
.\backend\gradlew.bat -p backend test --tests 'com.formypet.domain.*' --tests 'com.formypet.global.*' -PtestTimezone=Asia/Seoul --rerun-tasks --no-daemon
flutter analyze frontend --no-fatal-infos
```

Flutter 전체 테스트는 `frontend`에서 `flutter test --no-pub`로 실행한다. `frontend/integration_test`의 Android 검사는 테스트용 앱·격리 DB·명시적인 기기 ID를 사용한다. `*_migration_test.dart`의 전체 실행 직후 기존 데이터 확인 모드로 다시 실행해 저장 결과를 검증한다. 운영 계정/DB에 테스트 fixture를 쓰지 않는다.

CI 정의는 `.github/workflows/formypet-ci.yml`을 따른다. [모니터링 운영 문서](monitoring/grafana.md)는 지표 인증, 수집, 검증 및 운영 점검 절차를 설명한다. 실제 외부 로그인·메일·푸시 전송과 운영 부하는 단위/통합 테스트 통과와 별도로 확인한다.
