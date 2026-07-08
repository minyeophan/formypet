# Java Test Diagnostics Audit

## 기준선과 Gate A

- 기준 branch/HEAD: `develop` / `0f9ab5d4341396b019ab11d978df42794b21bca4`
- 감사 산출물: `C:\tmp\paa-java-test-diagnostics-audit-0f9ab5d-20260707-125531`
- fresh snapshot 2회: Workspace 328개, Java 328개, main 21개, test 307개
- 필수 필드 `resource`, `source`, `code`, `severity`, `message`, `startLineNumber` 누락: 0개
- 식별자 `resource + code + severity + line + message` multiset 차이: 0개
- 동일 식별자 중복: 0개
- 감사 대상은 `source == Java`이면서 정규화 경로가 `backend/src/test/java/` 아래인 항목만 사용했다. main 및 generated/build 혼입은 0개다.

## 자동 집계

### code별

| code | 개수 |
|---:|---:|
| `16778128` | 305 |
| `536871799` | 2 |
| 합계 | 307 |

### exact message별

| exact message | 개수 |
|---|---:|
| `Null type safety: The expression of type 'String' needs unchecked conversion to conform to '@NonNull String'` | 142 |
| `Null type safety: The expression of type 'MediaType' needs unchecked conversion to conform to '@NonNull MediaType'` | 96 |
| `Null type safety: The expression of type 'Matcher<Collection<?>>' needs unchecked conversion to conform to '@NonNull Matcher<? super Collection<?>>'` | 36 |
| `Null type safety: The expression of type 'MockMultipartFile' needs unchecked conversion to conform to '@NonNull MockMultipartFile'` | 10 |
| `Null type safety: The expression of type 'Matcher<String>' needs unchecked conversion to conform to '@NonNull Matcher<? super String>'` | 8 |
| `Null type safety: The expression of type 'MockMultipartHttpServletRequestBuilder' needs unchecked conversion to conform to '@NonNull RequestBuilder'` | 6 |
| `Null type safety: The expression of type 'Class<String>' needs unchecked conversion to conform to '@NonNull Class<String>'` | 5 |
| `Null type safety: The expression of type 'byte[]' needs unchecked conversion to conform to '@NonNull byte[]'` | 2 |
| `Resource leak: '<unassigned Closeable value>' is never closed` | 2 |
| 합계 | 307 |

### 파일별

| 파일 | 개수 | 파일 | 개수 |
|---|---:|---|---:|
| `ActivityRecordIntegrationTest.java` | 47 | `PetIntegrationTest.java` | 41 |
| `AuthIntegrationTest.java` | 41 | `CommunityIntegrationTest.java` | 40 |
| `WalletExpenseIntegrationTest.java` | 38 | `RoutineIntegrationTest.java` | 31 |
| `CareScheduleIntegrationTest.java` | 22 | `MediaIntegrationTest.java` | 18 |
| `MediaCleanupRunnerTest.java` | 11 | `UserProfileIntegrationTest.java` | 10 |
| `MediaStorageFailureIntegrationTest.java` | 4 | `SecurityCorsIntegrationTest.java` | 2 |
| `FlywayMigrationTest.java` | 1 | `IntegrationTestSupport.java` | 1 |
| 합계 | 307 | | |

### 파일 × exact message별

아래 형식에서 `String`, `MediaType` 등은 위 exact message의 expression type이며, `Resource`는 resource leak exact message다.

| 파일 | String | MediaType | Collection matcher | String matcher | Multipart file | Request builder | Class<String> | byte[] | Resource | 합계 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `ActivityRecordIntegrationTest` | 29 | 14 | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 47 |
| `AuthIntegrationTest` | 21 | 20 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 41 |
| `CareScheduleIntegrationTest` | 14 | 6 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 22 |
| `CommunityIntegrationTest` | 4 | 9 | 18 | 1 | 1 | 6 | 0 | 1 | 0 | 40 |
| `FlywayMigrationTest` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 |
| `IntegrationTestSupport` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 |
| `MediaCleanupRunnerTest` | 6 | 0 | 0 | 0 | 0 | 0 | 5 | 0 | 0 | 11 |
| `MediaIntegrationTest` | 4 | 3 | 0 | 4 | 6 | 0 | 0 | 1 | 0 | 18 |
| `MediaStorageFailureIntegrationTest` | 2 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 4 |
| `PetIntegrationTest` | 19 | 19 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 41 |
| `RoutineIntegrationTest` | 18 | 11 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 31 |
| `SecurityCorsIntegrationTest` | 1 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 2 |
| `UserProfileIntegrationTest` | 3 | 3 | 0 | 1 | 3 | 0 | 0 | 0 | 0 | 10 |
| `WalletExpenseIntegrationTest` | 21 | 9 | 7 | 1 | 0 | 0 | 0 | 0 | 0 | 38 |
| 합계 | 142 | 96 | 36 | 8 | 10 | 6 | 5 | 2 | 2 | 307 |

## 분류 결과

| 분류 | 개수 | 결론 |
|---|---:|---|
| BLOCKER | 0 | 확실한 컴파일·런타임·데이터 손상 위험 없음 |
| ACTIONABLE | 0 | 현재 근거로 즉시 수정해야 할 프로젝트 결함 없음 |
| CONTRACT_CANDIDATE | 49 | 프로젝트 URL helper 반환 계약을 명시하면 줄일 수 있지만 호출자 방향으로 경고가 이동할 수 있음 |
| TEST_FRAMEWORK_BOUNDARY | 256 | Spring MockMvc·Jackson·Hamcrest·Mockito·JDBC test API 사이의 null annotation/generic 차이 |
| MANAGED_LIFECYCLE | 1 | Testcontainers JUnit extension이 종료를 관리 |
| LIFECYCLE_POLICY_CANDIDATE | 1 | JVM 수명 공유 컨테이너 정책과 명시적 종료 규칙을 별도 결정해야 함 |
| UNKNOWN | 0 | 추가 자료 없이는 분류할 수 없는 항목 없음 |
| 합계 | 307 | fresh test Java 진단 개수와 일치 |

## 그룹별 근거

### CONTRACT_CANDIDATE 49개

| 파일과 대표 위치 | 개수 | 호출 대상과 판정 근거 |
|---|---:|---|
| `ActivityRecordIntegrationTest.java:46,90` | 15 | 프로젝트 helper `recordsUrl()` 반환을 Spring `post()`·`get()`에 전달한다. helper는 유효 URL을 조립하지만 반환 null 계약을 선언하지 않았다. |
| `CareScheduleIntegrationTest.java:52,75` | 8 | 프로젝트 helper `schedulesUrl()`과 Spring request builder의 경계다. |
| `RoutineIntegrationTest.java:46,103` | 7 | 프로젝트 helper `routinesUrl()`과 Spring request builder의 경계다. |
| `WalletExpenseIntegrationTest.java:53,142` | 17 | 프로젝트 helper `expensesUrl()`과 Spring request builder의 경계다. |
| `MediaIntegrationTest.java:229` | 1 | 프로젝트에서 조립한 `publicUrl`을 Spring `get()`에 전달한다. |
| `SecurityCorsIntegrationTest.java:30` | 1 | 프로젝트 test parameter `path`를 Spring `options()`에 전달한다. |

helper 또는 parameter에 계약을 추가하면 helper 내부 조립식이나 호출자로 진단이 이동할 수 있다. 따라서 이번 감사에서는 수정하지 않고, helper별 단일 파일럿과 전후 snapshot 비교를 후속 조건으로 둔다.

### TEST_FRAMEWORK_BOUNDARY 256개

| 호출 대상과 대표 위치 | 개수 | 판정 근거 |
|---|---:|---|
| MockMvc `.content(...)`, Jackson `writeValueAsString(...)` 및 고정 body | 92 | Jackson·프로젝트 변수의 String을 Spring의 non-null content parameter로 전달하는 외부 annotation 경계다. 실제 body 생산 경로는 고정 map/DTO 직렬화이며 nullable 생산 경로는 발견되지 않았다. |
| Mockito `anyString()` → `KakaoUserClient.fetchUser(...)` | 1 | matcher는 호출 시 null placeholder를 반환하는 Mockito annotation/동작 경계다. |
| `MediaType.APPLICATION_JSON` → MockMvc `.contentType(...)` | 96 | 상수 값은 non-null이며 Spring test API 내부 annotation 차이다. |
| Hamcrest matcher → `jsonPath().value(...)`, `hasSize(...)`, header matcher | 44 | `hasSize`, `matchesPattern`, `containsString`, `not(blankOrNullString())`가 생성한 matcher와 MockMvc assertion signature의 generic null annotation 차이다. |
| `MockMultipartFile` 및 multipart request helper → MockMvc | 16 | test fixture가 항상 객체를 생성하며 multipart builder의 반환 annotation 차이다. |
| `JdbcTemplate.queryForList(anyString(), eq(String.class))` | 5 | Mockito matcher와 Spring JDBC의 `Class<String>` parameter annotation 차이다. |
| 고정 UTF-8 byte 배열 → AssertJ/MockMvc byte consumer | 2 | 문자열 상수의 `getBytes(UTF_8)`는 null을 생산하지 않으며 test assertion API 경계다. |

동일 message의 String 142개를 일괄 판정하지 않았다. project URL helper 49개, MockMvc content/Jackson 경계 92개, Mockito matcher 1개로 호출 대상을 분리했다. 다른 message도 파일 × message × 호출 대상별 대표 위치를 확인했다.

### 리소스 수명 2개

| 위치 | 분류 | 근거와 후속 확인 |
|---|---|---|
| `FlywayMigrationTest.java:19` | MANAGED_LIFECYCLE | 클래스에 `@Testcontainers`, static field에 `@Container`가 있어 JUnit Testcontainers extension이 container start/stop을 관리한다. JDT는 생성식의 close ownership을 추론하지 못한다. |
| `IntegrationTestSupport.java:18` | LIFECYCLE_POLICY_CANDIDATE | static block에서 직접 `start()`하고 명시적 `stop()`은 없다. 주석상 클래스 간 재시작을 피하고 JVM 종료 시 cleanup하는 의도지만, 현재 코드만으로 종료 hook 소유권과 재사용 JVM 정책을 확정할 수 없다. |

`IntegrationTestSupport`는 `docs/BACKEND_RULES.md`의 “Testcontainers container는 static `@Container`로 선언하고 클래스 안에서 재사용” 규칙과 충돌한다. 코드를 `@Container`로 바꿀지, JVM 수명 공유를 문서상 예외로 둘지는 이 감사에서 결정하거나 수정하지 않는다. 후속 작업에서는 Gradle test JVM 종료 후 container/process 잔존 여부와 여러 통합 테스트 클래스 실행 시 재시작 횟수를 먼저 계측해야 한다.

## 잔여 위험과 후속 후보

- BLOCKER·ACTIONABLE·UNKNOWN은 0개지만, 이는 null annotation 진단이 전부 무의미하다는 뜻이 아니다. project helper 계약 49개는 경고 이동 없는 단일 파일럿으로만 검토한다.
- `IntegrationTestSupport`의 수명 정책과 `BACKEND_RULES` 충돌은 2026-07-08 후속 작업에서 전용 `SharedMySqlContainer` JVM singleton과 Ryuk cleanup 정책으로 정리했다. 진단 총수는 유지되고 lifecycle warning 1개만 owner class로 이동했다.
- 후속 수정은 이번 문서 변경에 포함하지 않는다. 실제 변경을 선택하면 실패 검증 조건과 전후 Problems snapshot을 포함한 별도 TDD 작업으로 진행한다.
- suppression, cast, `Objects.requireNonNull`, dependency 또는 JDT 설정 변경으로 진단만 숨기지 않는다.

## 후속 작업 우선순위

- 제품 기능 작업을 우선한다. BLOCKER·ACTIONABLE이 0개인 현재 test 진단만을 줄이기 위한 일괄 수정은 진행하지 않는다.
- 계약 후보 49개는 기능 작업에서 해당 URL helper를 직접 수정할 때 함께 검토하거나, 별도 요청이 있을 때 파일 하나의 TDD 파일럿으로만 진행한다.
- 파일럿은 전후 안정 Problems snapshot에서 대상 경고만 제거되고 신규·이동 진단이 없을 때만 유지한다.
- 새 BLOCKER·ACTIONABLE 진단이 발생하면 이 우선순위를 중단하고 즉시 재현 테스트와 수정 작업으로 전환한다.

## 완료 검증

- 분류 합계, 파일별, code별, exact message별, 파일 × message별 합계가 모두 307개다.
- main 혼입 0개, 필수 필드 누락 0개, 동일 식별자 중복 0개, 안정 snapshot multiset 차이 0개다.
- 시작 HEAD는 `0f9ab5d4341396b019ab11d978df42794b21bca4`다. 종료 검증에서 같은 HEAD인지 다시 확인한다.
- 코드 변경이 없는 감사이므로 Gradle과 Flutter 검증은 실행하지 않는다.
