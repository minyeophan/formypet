package com.formypet.monitoring;

import com.formypet.auth.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.actuate.observability.AutoConfigureObservability;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.*;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(classes = MonitoringTestApplication.class,
        webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "MONITORING_ENABLED=true", "MONITORING_USERNAME=monitor-test",
        "MONITORING_PASSWORD=test-only-monitoring-password",
        "app.jwt.secret=test-only-jwt-secret-for-automated-tests",
        "management.endpoints.web.base-path=/api/v1/auth"
})
@AutoConfigureObservability
class MonitoringRelocatedEndpointTest {
    @Autowired TestRestTemplate http;
    @Autowired JwtService jwt;

    @Test
    void relocatingIntoPublicApplicationPathsCannotBypassMonitoringPolicy() {
        String path = "/api/v1/auth/prometheus";
        assertThat(http.getForEntity(path, String.class).getStatusCode().is4xxClientError()).isTrue();
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(jwt.generateAccessToken(42L, 0L));
        assertThat(http.exchange(path, HttpMethod.GET, new HttpEntity<>(headers), String.class)
                .getStatusCode().is4xxClientError()).isTrue();
        assertThat(http.withBasicAuth("monitor-test", "test-only-monitoring-password")
                .getForEntity(path, String.class).getStatusCode().is4xxClientError()).isTrue();
    }
}
