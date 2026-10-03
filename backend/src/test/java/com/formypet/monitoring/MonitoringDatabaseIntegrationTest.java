package com.formypet.monitoring;

import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import javax.sql.DataSource;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "MONITORING_ENABLED=true", "MONITORING_USERNAME=monitor-test",
        "MONITORING_PASSWORD=test-only-monitoring-password", "MONITORING_ENVIRONMENT=test"
})
@AutoConfigureObservability
class MonitoringDatabaseIntegrationTest extends IntegrationTestSupport {
    @Autowired TestRestTemplate http;
    @Autowired DataSource database;

    @Test
    void realApplicationExportsPoolMetricsWithoutDatabaseCredentials() throws Exception {
        try (var connection = database.getConnection(); var statement = connection.createStatement()) {
            assertThat(statement.executeQuery("SELECT 1").next()).isTrue();
            var response = http.withBasicAuth("monitor-test", "test-only-monitoring-password")
                    .getForEntity("/actuator/prometheus", String.class);
            assertThat(response.getStatusCode().value()).isEqualTo(200);
            assertThat(response.getBody()).contains("hikaricp_connections_active", "hikaricp_connections_idle",
                    "hikaricp_connections_max", "hikaricp_connections_pending", "hikaricp_connections_acquire_seconds_count",
                    "hikaricp_connections_timeout_total", "jvm_memory_used_bytes")
                    .doesNotContain("jdbc:mysql", "test-only-monitoring-password");
            assertThat(response.getBody().lines().filter(line -> !line.isBlank() && !line.startsWith("#")).count())
                    .isLessThan(5000);
        }
    }
}
