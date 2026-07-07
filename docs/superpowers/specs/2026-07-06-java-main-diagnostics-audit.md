# Java Main Diagnostics Audit

## 기준선

- 기준 commit: `b1e6857`
- Workspace 336개, Java 336개, main 29개, test 307개
- 필수 JSON 필드 누락 0개
- 이전 안정 snapshot과 path·code·severity·line·message 기준 차이 0개
- 감사 산출물: `C:\tmp\paa-java-main-diagnostics-audit-b1e6857-20260706-164131`

## 분류 결과

| 분류 | 개수 | 결론 |
|---|---:|---|
| BLOCKER | 0 | 명확한 런타임 NPE, 보안 또는 데이터 손상 위험 없음 |
| ACTIONABLE | 0 | 즉시 수정해야 할 프로젝트 null 처리 오류 없음 |
| CONTRACT_CANDIDATE | 8 | 프로젝트가 통제하는 계약이지만 경고 이동 가능성을 고려해 별도 파일럿 필요 |
| EXTERNAL_BOUNDARY | 21 | JDK·Spring·JDBC generic 또는 null annotation 차이 |
| UNKNOWN | 0 | 추가 자료 없이 분류 불가능한 항목 없음 |

합계는 main Java 진단 29개와 일치한다.

## 진단별 근거

| 파일과 line | code | 개수 | 분류 | 근거와 후속 조치 |
|---|---:|---:|---|---|
| `AuthService.java:67` | 16778128 | 1 | CONTRACT_CANDIDATE | `@NotBlank` access token을 `KakaoUserClient`의 non-null parameter에 전달한다. validation 전 DTO 직접 생성 가능성을 검토한 뒤 record component 계약을 별도 실험한다. |
| `RestClientKakaoUserClient.java:70,80,81` | 16778128 | 3 | EXTERNAL_BOUNDARY | `Map.of()`와 `Duration.ofSeconds()`는 null을 반환하지 않지만 JDK 반환 annotation과 Spring non-null 소비 경계가 일치하지 않는다. cast나 `requireNonNull`로 보정하지 않는다. |
| `GlobalExceptionHandler.java:27,28,39,45,60,70,80,90,100,109` | 16778128, 67109822 | 10 | EXTERNAL_BOUNDARY | `HttpStatus`, `URI.create()`와 `FieldError` method reference의 JDK·Spring generic annotation 차이다. 실제 null 생산 경로가 없으며 진단만 위한 handler 리팩터링은 하지 않는다. |
| `CommunityService.java:103,142,187,546` | 16778128 | 4 | EXTERNAL_BOUNDARY | `StringBuilder.toString()` 또는 구성된 SQL을 `JdbcTemplate` non-null SQL parameter에 전달한다. SQL 문자열은 항상 생성되며 프로젝트 DTO 계약 문제가 아니다. |
| `SecurityConfig.java:54` | 67109822 | 1 | EXTERNAL_BOUNDARY | Spring Security `AbstractHttpConfigurer::disable` method descriptor의 generic null annotation 차이다. |
| `MediaController.java:41,49`, `UserProfileImageController.java:22` | 16778128 | 3 | CONTRACT_CANDIDATE | `LoadedMedia.contentType()`을 `MediaType.parseMediaType()`에 전달한다. DB `media_resources.content_type`은 `NOT NULL`이고 storage load 경로도 값을 그대로 보존하므로 가장 강한 다음 후보다. |
| `MediaService.java:283`, `PetService.java:82`, `ActivityRecordService.java:332`, `RoutineService.java:262` | 16778128 | 4 | CONTRACT_CANDIDATE | private helper의 `Long petId`를 Spring Data `findById()`에 전달한다. helper만 annotation하면 public service나 controller 호출자로 경고가 이동할 수 있어 단일 파일 수정 후보가 아니다. |
| `ActivityRecordService.java:103` | 16778128 | 1 | EXTERNAL_BOUNDARY | 구성된 SQL 문자열을 `JdbcTemplate.query()`에 전달하는 JDK·Spring 경계다. |
| `CareScheduleService.java:46` | 16778128 | 1 | EXTERNAL_BOUNDARY | JDBC `prepareStatement()` 반환을 Spring callback non-null 반환으로 전달하는 annotation 차이다. JDBC는 실패 시 예외를 사용한다. |
| `WalletExpenseService.java:99` | 16778128 | 1 | EXTERNAL_BOUNDARY | 구성된 SQL 문자열을 `JdbcTemplate.query()`에 전달하는 JDK·Spring 경계다. |

## 초기 우선순위

1. `LoadedMedia.contentType` 계약 파일럿: 3개, 단일 record 경계, DB·storage 불변식 근거가 명확하다. 후속 파일럿으로 완료했다.
2. `KakaoLoginRequest.accessToken` 계약 파일럿: 1개, Bean Validation 전 객체 상태와 직접 호출 계약을 먼저 결정해야 한다.
3. `petId` 전달 계약: 4개, controller부터 private helper까지 호출 체인을 함께 설계해야 한다.

외부 경계 21개는 suppression, cast, `Objects.requireNonNull` 또는 동작과 무관한 리팩터링으로 제거하지 않는다. 향후 JSpecify·외부 annotation 전략을 별도 채택할 때 다시 검토한다.

## LoadedMedia 파일럿 결과

- `LoadedMedia.contentType` record component에 Spring `@NonNull`을 적용하고 `LocalMediaStorage.load()`가 null content type을 파일 접근 전에 거부하도록 했다.
- production 변경 전에 null 입력이 `NoSuchFileException`으로 진행되는 RED 테스트를 확인했고, null guard 적용 후 `IllegalArgumentException` 계약으로 GREEN을 확인했다.
- 최종 안정 snapshot 2회는 Java 333개(main 26, test 307)로 일치했다.
- `MediaController` 2개와 `UserProfileImageController` 1개의 content type 경고가 제거됐고 신규 진단이나 경고 이동은 없다.
- 잔여 분류는 CONTRACT_CANDIDATE 5개, EXTERNAL_BOUNDARY 21개이며 BLOCKER·ACTIONABLE·UNKNOWN은 0개다.
- Java compile, storage·media·profile 선택 테스트와 backend 전체 테스트가 통과했다.

## 잔여 계약 후보 처리 결과

- `KakaoLoginRequest.accessToken`에 `@NotBlank`와 함께 Spring `@NonNull`을 선언했다. Java 진단은 333개에서 332개로 감소했고 `AuthService` 경고 1개만 제거됐다.
- `MediaService`, `PetService`, `ActivityRecordService`, `RoutineService`의 `findOwnedPet()`에서 기존 사용자 조회 순서를 유지한 채 repository 호출 직전에 null pet ID를 거부하도록 했다.
- pet ID guard 적용 후 Java 진단은 332개에서 328개(main 21, test 307)로 감소했고 repository 경계 경고 4개만 제거됐다.
- 두 단계 모두 신규·이동 진단은 없었고 Java compile과 관련 선택 테스트가 통과했다.
- 초기 CONTRACT_CANDIDATE 8개는 모두 처리됐다. 잔여 main 21개는 EXTERNAL_BOUNDARY이며 BLOCKER·ACTIONABLE·UNKNOWN은 0개다.

## 변경 제한

- 초기 감사 단계에서는 코드를 변경하지 않았고, 후속 파일럿은 `LoadedMedia`, `LocalMediaStorage`와 전용 단위 테스트로 제한했다. migration, frontend, dependency와 JDT 설정은 변경하지 않았다.
- 다음 파일럿도 한 번에 단일 경계만 적용하고 fresh Problems snapshot으로 경고 제거와 이동 여부를 확인한다.
