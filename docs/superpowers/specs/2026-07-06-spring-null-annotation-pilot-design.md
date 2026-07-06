# Spring 6.2 Null Annotation Pilot Design

## 목적

Spring Framework 6.2.1과 Eclipse JDT가 인식하는 null 계약을 작은 범위에 도입해 진단 품질이 실제로 개선되는지 검증한다. Problems 총개수 감소는 목표가 아니며, suppression이나 JDT 경고 비활성화 없이 신규 ACTIONABLE·BLOCKER가 발생하지 않는 것을 우선한다.

## 범위

- 대표 package는 `com.petyilgi.auth.client` 하나로 제한한다.
- `package-info.java`에 Spring `@NonNullApi`를 적용한다.
- `KakaoUserInfo`의 `email`, `nickname`만 nullable로 선언한다.
- `RestClientKakaoUserClient`에서 실제로 null을 허용하는 `parse()` body, `asMap()` 입력, `asString()` 입력·반환만 `@Nullable`로 선언한다.
- 별도 검증 대상으로 `JwtAuthFilter` override parameter 3개의 `jakarta.annotation.Nonnull`을 Spring `@NonNull`로 교체한다.
- test package, 다른 main package, Gradle dependency, `.vscode` 설정은 변경하지 않는다.

## 진단 검증

- 변경 직전 전체 Problems snapshot을 저장하고 Workspace와 Backend Java 개수를 분리한다.
- Java indexing 완료 후 사후 snapshot을 두 번 수집해 안정성을 확인한다.
- 동일 source 상태의 안정성은 위치를 포함한 key로 비교하고, 변경 전후는 줄 이동을 제외한 path·code·severity·message multiset으로 비교한다.
- `JwtAuthFilter` override 경고 3개와 `auth.client` 기존 경고 3개의 변화를 개별 기록한다.
- 새 NON_BLOCKING은 분류해 기록하며 신규 ACTIONABLE·BLOCKER가 있으면 확대하지 않는다.

## 테스트와 합격 기준

- 기존 `RestClientKakaoUserClientTest`와 `AuthIntegrationTest`로 nullable 응답과 인증 흐름을 검증한다.
- 선택 테스트, Java compile, backend 전체 테스트를 통과해야 한다.
- suppression, cast, `Objects.requireNonNull` 추가 없이 계약을 표현한다.
- 파일럿 결과가 개선되더라도 다른 package로 자동 확대하지 않고 별도 후속 결정을 내린다.

## 롤백 기준

- 파일럿 적용 후 신규 ACTIONABLE 또는 BLOCKER가 발생하면 annotation 확대를 중단하고, 이번 변경은 원복하거나 원인 분석 후 별도 PR로 분리한다.

## 실행 결과

- baseline은 Java 341개(main 35, test 306)였다.
- `auth.client` package 파일럿 적용 후 안정화 snapshot은 343개였다. `JwtAuthFilter` 경고 3개는 제거됐지만 `OAuthSignupService`에서 nullable record accessor 반복 호출로 잠재 NPE 2개가 새로 발생했고, 그 밖의 unchecked conversion도 증가했다.
- 롤백 기준에 따라 `auth.client`의 `@NonNullApi`와 `@Nullable` 변경은 원복했다. package 단위 확대는 후속 소비자 정리 전까지 중단한다.
- 독립적으로 개선된 `JwtAuthFilter`의 Spring `@NonNull` 교체만 유지했다. 최종 snapshot 2회는 Java 338개(main 32, test 306)로 일치했고 신규 ACTIONABLE·BLOCKER는 없었다.
- 선택 테스트, Java compile, backend 전체 테스트가 모두 통과했다.

## 비범위

- 남은 341개 진단 일괄 수정
- JSpecify 또는 NullAway 도입
- Spring Boot·Spring Framework 업그레이드
- API·DB·Flyway·frontend 변경
