package com.formypet.monitoring;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.boot.test.context.runner.WebApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;

class MonitoringConfigurationTest {
    @ParameterizedTest
    @CsvSource(value = {"'',test-only-password", "monitor-test,''", "'',''"})
    void enabledMonitoringFailsClosedWhenEitherCredentialIsMissing(String username, String password) {
        new WebApplicationContextRunner().withUserConfiguration(SecurityInfrastructure.class,
                        MonitoringSecurityConfiguration.class)
                .withPropertyValues("app.monitoring.enabled=true", "app.monitoring.username=" + username,
                        "app.monitoring.password=" + password)
                .run(context -> assertThat(context).hasFailed()
                        .getFailure().hasRootCauseMessage("Monitoring requires MONITORING_USERNAME and MONITORING_PASSWORD"));
    }

    @TestConfiguration(proxyBeanMethods = false)
    @EnableWebSecurity
    @org.springframework.web.servlet.config.annotation.EnableWebMvc
    static class SecurityInfrastructure {
        @Bean PasswordEncoder encoder() { return new BCryptPasswordEncoder(); }
    }
}
