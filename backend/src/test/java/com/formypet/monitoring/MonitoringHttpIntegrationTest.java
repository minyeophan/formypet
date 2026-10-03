package com.formypet.monitoring;

import com.formypet.auth.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.http.*;
import java.util.List;
import java.time.Duration;
import io.micrometer.core.instrument.MeterRegistry;
import static org.awaitility.Awaitility.await;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(classes = MonitoringTestApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "app.jwt.secret=test-only-jwt-secret-for-automated-tests",
        "MONITORING_ENABLED=true", "MONITORING_USERNAME=monitor-test",
        "MONITORING_PASSWORD=test-only-monitoring-password", "MONITORING_ENVIRONMENT=test"
})
@AutoConfigureObservability
class MonitoringHttpIntegrationTest {
    @Autowired TestRestTemplate http;
    @Autowired JwtService jwt;
    @Autowired MeterRegistry registry;

    @Test
    void oneSecondBucketSeparatesStrictlySlowRequests() {
        var timer = registry.timer("http.server.requests", "uri", "/boundary", "method", "GET", "status", "200",
                "exception", "none", "error", "none", "outcome", "SUCCESS");
        timer.record(Duration.ofMillis(999));
        timer.record(Duration.ofMillis(1000));
        timer.record(Duration.ofMillis(1001));
        String body = scrape();
        assertThat(sample(body, "http_server_requests_seconds_bucket", "uri=\"/boundary\"", "le=\"1.0\"")).isEqualTo(2);
        assertThat(sample(body, "http_server_requests_seconds_count", "uri=\"/boundary\"")).isEqualTo(3);
    }

    @Test
    void blockedDynamicPathsUseBoundedAuthenticationLabel() {
        for (int i = 0; i < 12; i++) {
            assertThat(http.getForEntity("/private-user-" + i + "?token=never-export-this", String.class)
                    .getStatusCode().value()).isEqualTo(401);
        }
        await().atMost(Duration.ofSeconds(5)).untilAsserted(() -> {
            String body = scrape();
            assertThat(body).doesNotContain("private-user-", "never-export-this");
            assertThat(sample(body, "http_server_requests_seconds_count", "uri=\"AUTHENTICATION\"", "status=\"401\""))
                    .isGreaterThanOrEqualTo(12);
        });
    }

    private static double sample(String body, String metric, String... labels) {
        String line = body.lines().filter(s -> s.startsWith(metric + "{"))
                .filter(s -> java.util.Arrays.stream(labels).allMatch(s::contains)).findFirst().orElseThrow();
        return Double.parseDouble(line.substring(line.lastIndexOf(' ') + 1));
    }

    private String scrape() {
        return http.withBasicAuth("monitor-test", "test-only-monitoring-password")
                .getForObject("/actuator/prometheus", String.class);
    }

    @Test
    void recordsHandledStatusesOnceWithoutPersonalLabelsAndUsesOnlyFixedBuckets() {
        for (int status : new int[]{200, 400, 401, 403, 404, 500}) {
            assertThat(http.getForEntity("/api/v1/auth/monitoring-test/private-person-923?status=" + status
                    + "&email=private@example.test", String.class).getStatusCode().value()).isEqualTo(status);
        }
        await().atMost(Duration.ofSeconds(5)).untilAsserted(() -> {
            String body = scrape();
            assertThat(body).doesNotContain("private-person-923", "private@example.test", "test-only-monitoring-password");
            for (int status : new int[]{200, 400, 401, 403, 404, 500}) {
                List<String> samples = body.lines().filter(line -> line.startsWith("http_server_requests_seconds_count{"))
                        .filter(line -> line.contains("uri=\"/api/v1/auth/monitoring-test/{id}\""))
                        .filter(line -> line.contains("status=\"" + status + "\"")).toList();
                assertThat(samples).hasSize(1);
                assertThat(Double.parseDouble(samples.getFirst().substring(samples.getFirst().lastIndexOf(' ') + 1))).isEqualTo(1);
            }
            var buckets = body.lines().filter(line -> line.startsWith("http_server_requests_seconds_bucket{"))
                    .filter(line -> line.contains("uri=\"/api/v1/auth/monitoring-test/{id}\"") && line.contains("status=\"200\""))
                    .map(line -> line.replaceFirst(".*le=\"([^\"]+)\".*", "$1")).toList();
            assertThat(buckets).containsExactlyInAnyOrder("0.025", "0.05", "0.1", "0.25", "0.5", "1.0", "2.0", "5.0", "10.0", "30.0", "+Inf");
            assertThat(body.lines().filter(line -> line.startsWith("http_server_requests_seconds_count{")))
                    .noneMatch(line -> line.contains("uri=\"/api/v1/health\"") || line.contains("uri=\"/actuator"));
            assertThat(body.lines().filter(line -> !line.isBlank() && !line.startsWith("#")).count()).isLessThan(5000);
        });
    }

    @Test
    void onlyDedicatedCredentialsCanScrapeAndCannotAuthenticateToApp() {
        assertThat(http.getForEntity("/actuator/prometheus", String.class).getStatusCode().value()).isEqualTo(401);
        assertThat(http.withBasicAuth("monitor-test", "wrong")
                .getForEntity("/actuator/prometheus", String.class).getStatusCode().value()).isEqualTo(401);
        var monitor = http.withBasicAuth("monitor-test", "test-only-monitoring-password");
        var scrape = monitor.getForEntity("/actuator/prometheus", String.class);
        assertThat(scrape.getStatusCode().value()).isEqualTo(200);
        assertThat(scrape.getBody()).contains("jvm_memory_used_bytes");
        assertThat(monitor.getForEntity("/api/v1/pets", String.class).getStatusCode().value()).isEqualTo(401);
        for (String path : new String[]{"/actuator", "/actuator/health", "/actuator/env", "/actuator/metrics"}) {
            assertThat(monitor.getForEntity(path, String.class).getStatusCode().is4xxClientError()).isTrue();
        }
        for (HttpMethod method : new HttpMethod[]{HttpMethod.POST, HttpMethod.PUT, HttpMethod.DELETE, HttpMethod.HEAD}) {
            assertThat(monitor.exchange("/actuator/prometheus", method, HttpEntity.EMPTY, String.class)
                    .getStatusCode().is4xxClientError()).isTrue();
        }
        assertThat(http.getForEntity("/api/v1/health", String.class).getStatusCode().value()).isEqualTo(200);
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(jwt.generateAccessToken(42L, 0L));
        var appAuth = new HttpEntity<>(headers);
        assertThat(http.exchange("/api/v1/pets", HttpMethod.GET, appAuth, String.class)
                .getStatusCode().value()).isEqualTo(200);
        assertThat(http.exchange("/actuator/prometheus", HttpMethod.GET, appAuth, String.class)
                .getStatusCode().value()).isEqualTo(401);
    }
}
