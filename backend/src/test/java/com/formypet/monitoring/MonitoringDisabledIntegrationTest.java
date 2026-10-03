package com.formypet.monitoring;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(classes = MonitoringTestApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"MONITORING_ENABLED=false", "app.jwt.secret=test-only-jwt-secret-for-automated-tests"})
class MonitoringDisabledIntegrationTest {
    @Autowired TestRestTemplate http;

    @Test
    void disabledMonitoringExposesNoActuatorEvenWithBasicCredentials() {
        for (String path : new String[]{"/actuator/prometheus", "/actuator/health", "/actuator/env"}) {
            assertThat(http.withBasicAuth("monitor-test", "test-only-monitoring-password")
                    .getForEntity(path, String.class).getStatusCode().is4xxClientError()).isTrue();
        }
        assertThat(http.getForEntity("/api/v1/health", String.class).getStatusCode().value()).isEqualTo(200);
    }
}
