# Auth Domain Factory Null Contract Design

## 목적

항상 새 entity를 반환하는 auth domain factory의 반환 계약을 Spring `@NonNull`로 명시해 Spring Data repository 경계의 JDT unchecked-conversion 진단을 제거한다.

## 설계

- `User.create()`, `User.createOAuth()`, `RefreshToken.create()`, `OAuthAccount.create()` 반환에만 `org.springframework.lang.NonNull`을 적용한다.
- entity field, factory parameter, Lombok getter와 update method의 계약은 변경하지 않는다.
- package `@NonNullApi`는 사용하지 않는다. JPA ID는 영속화 전 null일 수 있고 `User.profileMediaId`와 `updateProfileMediaId()`는 실제로 null을 허용하기 때문이다.
- suppression, cast, `Objects.requireNonNull`, JDT 설정과 dependency는 변경하지 않는다.

## 검증 결과

- fresh baseline은 Java 340개(main 33, test 307)였다.
- 최종 안정 snapshot 2회는 Java 336개(main 29, test 307)로 일치했다.
- `AuthService`의 `User`·`RefreshToken`, `OAuthSignupService`의 `User`·`OAuthAccount` factory 반환 경고 4개가 제거됐고 신규 진단은 없다.
- Java compile, `AuthIntegrationTest`와 backend 전체 테스트가 통과했다.

## 제한

- 이번 결과를 근거로 다른 domain package나 entity에 자동 확대하지 않는다.
- nullable JPA lifecycle 상태를 package 기본 non-null로 덮지 않는다.
- 다음 대상은 남은 main Java 진단을 다시 분류한 뒤 별도 범위와 snapshot 기준으로 결정한다.
