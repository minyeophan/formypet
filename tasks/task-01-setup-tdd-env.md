# Task 01 — TDD 인프라 구축 및 코어 API 설계

## Context & Frontend Sync

**읽은 문서:**
- `docs/CONTEXT.md`: Phase 1 완료. 이후 Phase 2/Auth, Phase 3/Pet까지 완료.
- `docs/FRONTEND_STATUS.md`: 프론트는 로컬 MVP 완성. 이 Phase에서 프론트 연동 없음.
  Swagger UI(`/swagger-ui.html`)로 Mock 엔드포인트 확인 가능 상태가 목표.

**완료 기준(Definition of Done):**
- `./gradlew test` — `SpatialQueryIntegrationTest` 3개 GREEN
- `GET /api/v1/health` → `"Virtual Thread ✅"` 응답 (로컬 Docker MySQL 실행 중)
- `http://localhost:8080/swagger-ui.html` 접속 → Health API 확인
- `docs/CONTEXT.md` 5줄 요약 업데이트

---

## Phase 1-A — 프로젝트 골격 생성
**Verify:** `./gradlew build -x test` 성공 (컴파일 오류 없음)

### 디렉토리 구조
```
backend/
├── src/
│   ├── main/
│   │   ├── java/com/petyilgi/
│   │   │   ├── PetyilgiApplication.java
│   │   │   ├── common/
│   │   │   │   ├── response/ApiResponse.java
│   │   │   │   ├── exception/GlobalExceptionHandler.java
│   │   │   │   └── HealthController.java
│   │   │   └── config/
│   │   │       └── SecurityConfig.java        ← 개발 중 Swagger 허용
│   │   └── resources/
│   │       ├── application.yml
│   │       └── db/migration/
│   │           └── V1__create_spatial_test.sql  ← Flyway 첫 마이그레이션
│   └── test/
│       └── java/com/petyilgi/
│           ├── support/
│           │   └── IntegrationTestSupport.java
│           └── spatial/
│               └── SpatialQueryIntegrationTest.java
│       └── resources/
│           └── init-test.sql                   ← Testcontainers 초기화
├── docker/
│   ├── docker-compose.yml
│   └── init.sql
├── build.gradle
└── settings.gradle
```

### `settings.gradle`
```groovy
rootProject.name = 'petyilgi'
```

### `build.gradle` (Groovy DSL)
```groovy
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.4.1'
    id 'io.spring.dependency-management' version '1.1.7'
}

group = 'com.petyilgi'
version = '0.0.1-SNAPSHOT'

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

configurations {
    compileOnly { extendsFrom annotationProcessor }
}

repositories {
    mavenCentral()
}

dependencies {
    // ── Core ──────────────────────────────────────────────
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    implementation 'org.springframework.boot:spring-boot-starter-security'
    developmentOnly 'org.springframework.boot:spring-boot-devtools'

    // ── Database ──────────────────────────────────────────
    runtimeOnly  'com.mysql:mysql-connector-j'
    implementation 'org.hibernate.orm:hibernate-spatial'   // Spatial POINT 지원
    implementation 'org.flywaydb:flyway-mysql'             // 스키마 버전 관리

    // ── API Docs ──────────────────────────────────────────
    implementation 'org.springdoc:springdoc-openapi-starter-webmvc-ui:2.6.0'

    // ── Util ──────────────────────────────────────────────
    compileOnly    'org.projectlombok:lombok'
    annotationProcessor 'org.projectlombok:lombok'

    // ── Test ──────────────────────────────────────────────
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testImplementation 'org.springframework.security:spring-security-test'
    testImplementation 'org.testcontainers:junit-jupiter'
    testImplementation 'org.testcontainers:mysql'
}

dependencyManagement {
    imports {
        mavenBom "org.testcontainers:testcontainers-bom:1.20.4"
    }
}

tasks.named('test') {
    useJUnitPlatform()
    jvmArgs '-XX:+EnableDynamicAgentLoading'  // JDK 21 에이전트 경고 억제
    // 테스트 병렬 실행 비활성화: Testcontainers 컨테이너 공유 안정성
    maxParallelForks = 1
}
```

---

## Phase 1-B — 인프라 설정
**Verify:** `docker-compose up -d && docker-compose logs -f mysql` → `ready for connections` 확인

### `docker/docker-compose.yml`
```yaml
services:
  mysql:
    image: mysql:8.0
    container_name: petyilgi-mysql
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: petyilgi
      MYSQL_USER: petyilgi
      MYSQL_PASSWORD: petyilgi123
      TZ: Asia/Seoul
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-time-zone=+09:00
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "petyilgi", "-ppetyilgi123"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s   # MySQL 초기화 완료 대기

volumes:
  mysql_data:
```

> **주의:** Spring Boot 기동 전 `docker-compose ps`로 mysql 컨테이너 상태가 `healthy`인지 확인한다.  
> `starting` 상태에서 앱을 기동하면 `Communications link failure` 발생.

### `docker/init.sql` (로컬 개발용 — 스키마는 Flyway 관리)
```sql
-- 개발 환경 추가 설정만 여기에. 테이블 생성은 Flyway가 담당.
SET GLOBAL log_bin_trust_function_creators = 1;
SET GLOBAL explicit_defaults_for_timestamp = 1;
```

### `application.yml`
```yaml
spring:
  application:
    name: petyilgi

  threads:
    virtual:
      enabled: true          # Java 21 Virtual Thread 활성화

  datasource:
    url: jdbc:mysql://localhost:3306/petyilgi?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Seoul&characterEncoding=UTF-8
    username: petyilgi
    password: petyilgi123
    driver-class-name: com.mysql.cj.jdbc.Driver
    hikari:
      maximum-pool-size: 10
      minimum-idle: 2
      connection-timeout: 3000
      # Virtual Thread 환경: HikariCP가 platform thread를 점유하지 않도록 설정
      # Pinning 방지: synchronized 내부에서 HikariCP lock 획득 금지 (HikariCP 5.1+은 자동 처리)

  jpa:
    hibernate:
      ddl-auto: validate     # Flyway가 스키마 관리 → JPA는 검증만
    properties:
      hibernate:
        dialect: org.hibernate.dialect.MySQLDialect
        format_sql: true
        default_batch_fetch_size: 100
    show-sql: false

  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: false  # 신규 DB이므로 baseline 불필요

springdoc:
  swagger-ui:
    path: /swagger-ui.html
    operations-sorter: method
    tags-sorter: alpha
  api-docs:
    path: /v3/api-docs
  default-produces-media-type: application/json

logging:
  pattern:
    console: "%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n"
  level:
    com.petyilgi: DEBUG
    org.hibernate.SQL: DEBUG
    org.flywaydb: INFO

---
spring:
  config:
    activate:
      on-profile: test

  flyway:
    enabled: false           # Testcontainers: init-test.sql로 직접 초기화

  jpa:
    hibernate:
      ddl-auto: none         # init-test.sql에서 CREATE TABLE 처리
```

### `db/migration/V1__create_spatial_test.sql` (Flyway 첫 마이그레이션)
```sql
-- Phase 1 공간 쿼리 검증용 테이블 (운영 배포 시 V2에서 DROP 예정)
CREATE TABLE IF NOT EXISTS spatial_test (
    id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    location POINT        NOT NULL SRID 4326,
    SPATIAL INDEX idx_location (location)
) ENGINE = InnoDB;

INSERT INTO spatial_test (name, location) VALUES
    ('서울역',   ST_GeomFromText('POINT(126.9726 37.5547)', 4326)),
    ('강남역',   ST_GeomFromText('POINT(127.0276 37.4979)', 4326)),
    ('홍대입구', ST_GeomFromText('POINT(126.9228 37.5571)', 4326)),
    ('잠실역',   ST_GeomFromText('POINT(127.1000 37.5133)', 4326)),
    ('판교역',   ST_GeomFromText('POINT(127.1109 37.3952)', 4326));
```

### `SecurityConfig.java` ← 없으면 Spring Security가 Swagger/health를 403 차단
```java
package com.petyilgi.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    // Phase 1: 인증 미구현 — 모든 요청 허용 (Phase 2에서 JWT 추가)
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
                .csrf(AbstractHttpConfigurer::disable)
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .build();
    }
}
```

---

## Phase 1-C — [RED] 실패하는 테스트 먼저 작성
**Verify:** `./gradlew test` 실행 시 3개 테스트 **FAIL** (구현 코드 없으므로 예상된 실패)

> **규칙 확인:** 이 단계에서는 Repository, Entity, Service를 작성하지 않는다.  
> JdbcTemplate만 사용 — JPA 인프라 없이 순수 SQL로 공간 쿼리를 검증한다.

### `IntegrationTestSupport.java` — Testcontainers 베이스 클래스
```java
package com.petyilgi.support;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
public abstract class IntegrationTestSupport {

    // static: JVM당 컨테이너 1개 재사용 → 테스트 전체 속도 2~3배 향상
    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.0")
            .withDatabaseName("petyilgi_test")
            .withUsername("test")
            .withPassword("test")
            .withInitScript("init-test.sql")          // test/resources/init-test.sql
            .withCommand(
                "--character-set-server=utf8mb4",
                "--collation-server=utf8mb4_unicode_ci",
                "--log-bin-trust-function-creators=1"  // Spatial 함수 허용
            );

    @DynamicPropertySource
    static void overrideProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url",      MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        // Flyway 비활성화는 application.yml의 test profile에서 처리
    }
}
```

### `test/resources/init-test.sql`
```sql
-- Testcontainers 전용 초기화 (Flyway 대체)
CREATE TABLE IF NOT EXISTS spatial_test (
    id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    location POINT NOT NULL SRID 4326,
    SPATIAL INDEX idx_location (location)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

INSERT INTO spatial_test (name, location) VALUES
    ('강남역',   ST_GeomFromText('POINT(127.0276 37.4979)', 4326)),
    ('서울역',   ST_GeomFromText('POINT(126.9726 37.5547)', 4326)),
    ('홍대입구', ST_GeomFromText('POINT(126.9228 37.5571)', 4326)),
    ('잠실역',   ST_GeomFromText('POINT(127.1000 37.5133)', 4326)),
    ('판교역',   ST_GeomFromText('POINT(127.1109 37.3952)', 4326));
```

### `SpatialQueryIntegrationTest.java` [RED 단계 — 구현 없이 먼저 작성]
```java
package com.petyilgi.spatial;

import com.petyilgi.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("[통합] MySQL Spatial 쿼리 검증")
@Transactional  // 각 테스트 후 롤백 → 데이터 격리 보장
class SpatialQueryIntegrationTest extends IntegrationTestSupport {

    @Autowired
    JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanInsertedData() {
        // init-test.sql 외 테스트 중 삽입된 데이터만 정리 (이름으로 식별)
        jdbcTemplate.update("DELETE FROM spatial_test WHERE name = '테스트장소'");
    }

    @Test
    @DisplayName("ST_Distance_Sphere: 강남역 ↔ 서울역 거리가 9~11km 사이다")
    void stDistanceSphereReturnsReasonableResult() {
        // given: 강남역(127.0276, 37.4979) ↔ 서울역(126.9726, 37.5547) ≈ 9.7km
        String sql = """
            SELECT ST_Distance_Sphere(
                ST_GeomFromText('POINT(127.0276 37.4979)', 4326),
                ST_GeomFromText('POINT(126.9726 37.5547)', 4326)
            ) AS dist
            """;

        // when
        Double distMeters = jdbcTemplate.queryForObject(sql, Double.class);

        // then
        assertThat(distMeters)
                .as("강남역-서울역 거리 (9~11km 기대)")
                .isNotNull()
                .isBetween(9_000.0, 11_000.0);
    }

    @Test
    @DisplayName("POINT SRID 4326 저장 후 ST_X/ST_Y로 좌표를 정확히 조회한다")
    void insertPointWithSrid4326AndRetrieveCoordinates() {
        // given
        double expectedLng = 127.123;
        double expectedLat = 37.456;
        jdbcTemplate.update("""
            INSERT INTO spatial_test (name, location)
            VALUES ('테스트장소', ST_GeomFromText(?, 4326))
            """, String.format("POINT(%f %f)", expectedLng, expectedLat));

        // when
        Map<String, Object> row = jdbcTemplate.queryForMap("""
            SELECT ST_X(location) AS lng, ST_Y(location) AS lat
            FROM spatial_test WHERE name = '테스트장소'
            """);

        // then
        assertThat((Double) row.get("lng")).isEqualTo(expectedLng, org.assertj.core.data.Offset.offset(0.0001));
        assertThat((Double) row.get("lat")).isEqualTo(expectedLat, org.assertj.core.data.Offset.offset(0.0001));
    }

    @Test
    @DisplayName("반경 5km 내 검색: 강남역 기준으로 강남역만 포함, 서울역·홍대·판교는 제외된다")
    void radiusSearchReturnsOnlyNearbyPlaces() {
        // given: 기준점 = 강남역 (127.0276, 37.4979), 반경 5km
        // 예상 포함: 강남역(0m)
        // 예상 제외: 서울역(≈9.7km), 홍대입구(≈13.6km), 잠실역(≈9.0km), 판교역(≈18km)
        String sql = """
            SELECT name FROM spatial_test
            WHERE ST_Distance_Sphere(
                location,
                ST_GeomFromText('POINT(127.0276 37.4979)', 4326)
            ) <= 5000
            ORDER BY name
            """;

        // when
        List<String> result = jdbcTemplate.queryForList(sql, String.class);

        // then
        assertThat(result)
                .as("5km 반경 내: 강남역만 포함")
                .containsExactly("강남역")
                .doesNotContain("서울역", "홍대입구", "잠실역", "판교역");
    }
}
```

---

## Phase 1-D — [GREEN] 테스트 통과 확인
**Verify:** `./gradlew test --tests "*.SpatialQueryIntegrationTest"` → 3 tests PASSED

GREEN 조건은 **추가 구현이 필요 없다** — 위 테스트는 순수 JdbcTemplate + MySQL 내장 Spatial 함수를 사용하므로, init-test.sql이 올바르게 로드되면 바로 통과된다.

> 만약 실패한다면 체크:
> 1. `--log-bin-trust-function-creators=1` 옵션 적용 여부 (ST_ 함수 허용)
> 2. `init-test.sql`이 `src/test/resources/`에 위치하는지
> 3. SRID 4326 컬럼 정의가 올바른지 (`POINT NOT NULL SRID 4326`)

---

## Phase 1-E — [REFACTOR] 공통 구조 정의
**Verify:** `./gradlew test` 전체 통과 + `/api/v1/health` 응답 확인

### `ApiResponse.java` — 공통 응답 record
```java
package com.petyilgi.common.response;

/**
 * 모든 API 성공 응답의 공통 래퍼.
 * 변환: Entity → DTO record의 of() 팩토리에서 처리. Service에서 직접 생성 금지.
 */
public record ApiResponse<T>(T data, String message) {

    public static <T> ApiResponse<T> of(T data) {
        return new ApiResponse<>(data, "success");
    }

    public static <T> ApiResponse<T> of(T data, String message) {
        return new ApiResponse<>(data, message);
    }

    /** 빈 성공 응답 (DELETE 등) */
    public static ApiResponse<Void> empty() {
        return new ApiResponse<>(null, "success");
    }
}
```

### `GlobalExceptionHandler.java` — RFC 7807 ProblemDetail
```java
package com.petyilgi.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;
import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final String ERROR_BASE = "https://petyilgi.com/errors/";

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        Map<String, String> fieldErrors = ex.getBindingResult()
                .getFieldErrors().stream()
                .collect(Collectors.toMap(
                        FieldError::getField,
                        fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid"
                ));
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, "입력값 검증 실패");
        problem.setType(URI.create(ERROR_BASE + "validation-failed"));
        problem.setTitle("Validation Failed");
        problem.setProperty("fieldErrors", fieldErrors);
        return problem;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail handleIllegalArgument(IllegalArgumentException ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.BAD_REQUEST, ex.getMessage());
        problem.setType(URI.create(ERROR_BASE + "invalid-input"));
        problem.setTitle("잘못된 입력값");
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleGeneral(Exception ex) {
        ProblemDetail problem = ProblemDetail.forStatusAndDetail(
                HttpStatus.INTERNAL_SERVER_ERROR, "서버 오류가 발생했습니다.");
        problem.setType(URI.create(ERROR_BASE + "internal"));
        problem.setTitle("Internal Server Error");
        return problem;
    }
}
```

### `HealthController.java`
```java
package com.petyilgi.common;

import com.petyilgi.common.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Health", description = "서버 상태 확인")
@RestController
@RequestMapping("/api/v1")
public class HealthController {

    @Operation(summary = "Health Check",
               description = "Virtual Thread 동작 및 서버 상태 확인. 'Virtual Thread ✅' 반환 시 정상.")
    @GetMapping("/health")
    public ApiResponse<String> health() {
        String threadInfo = Thread.currentThread().isVirtual()
                ? "Virtual Thread ✅" : "Platform Thread ⚠️";
        return ApiResponse.of(threadInfo);
    }
}
```

---

## 완료 체크리스트

```
Phase 1-A  [x] ./gradlew build -x test 성공
Phase 1-B  [x] docker-compose up -d → mysql healthy
Phase 1-C  [x] SpatialQueryIntegrationTest 3개 RED 확인 (init-test.sql 없는 상태)
           [x] init-test.sql 작성
Phase 1-D  [x] ./gradlew test → 3개 GREEN
Phase 1-E  [x] GET /api/v1/health → "Virtual Thread ✅"
           [x] /swagger-ui.html 접속 → Health 엔드포인트 확인
           [x] docs/CONTEXT.md 5줄 요약 업데이트
```

---

## 알려진 주의사항 (Gotchas)

| 증상 | 원인 | 해결 |
|------|------|------|
| `FlywayException: validate failed` | 테이블 없이 `ddl-auto: validate` | `application.yml`의 test profile에서 Flyway disabled 확인 |
| `Communications link failure` | MySQL 컨테이너 아직 healthy 아님 | `docker-compose ps` → `healthy` 확인 후 기동 |
| `403 Forbidden` on Swagger | Spring Security 기본 차단 | `SecurityConfig` permitAll 적용 확인 |
| `ST_Distance_Sphere not allowed` | `log_bin_trust_function_creators=0` | `--with-command` 옵션 또는 init.sql에서 SET GLOBAL |
| `Testcontainers pull timeout` | Docker Hub rate limit | `docker pull mysql:8.0` 미리 실행 |

---

## 다음 태스크 예고

**task-02-auth-domain.md**: Spring Security 6 + JWT.  
첫 RED: `AuthIntegrationTest#registerWithValidEmailAndPasswordReturnsAccessAndRefreshTokens()`
