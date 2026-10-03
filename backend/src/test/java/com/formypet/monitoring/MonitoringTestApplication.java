package com.formypet.monitoring;

import com.formypet.auth.JwtAuthFilter;
import com.formypet.auth.JwtService;
import com.formypet.auth.SessionGuard;
import com.formypet.common.exception.GlobalExceptionHandler;
import com.formypet.config.SecurityConfig;
import org.springframework.boot.autoconfigure.EnableAutoConfiguration;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;
import org.springframework.boot.test.context.TestComponent;
import org.springframework.context.annotation.*;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.annotation.*;

import static org.mockito.Mockito.*;

/** Real embedded HTTP/security stack; only the DB-backed session lookup is replaced. */
@Configuration(proxyBeanMethods = false)
@TestComponent
@EnableAutoConfiguration(exclude = DataSourceAutoConfiguration.class)
@ComponentScan(basePackages = "com.formypet.monitoring",
        excludeFilters = @ComponentScan.Filter(type = FilterType.ANNOTATION, classes = TestComponent.class))
@Import({SecurityConfig.class, JwtAuthFilter.class, JwtService.class, GlobalExceptionHandler.class,
        MonitoringTestApplication.FixtureController.class})
class MonitoringTestApplication {
    @Bean SessionGuard sessions() {
        var sessions = mock(SessionGuard.class);
        when(sessions.accepts(42L, 0L)).thenReturn(true);
        return sessions;
    }

    @RestController
    @TestComponent
    static class FixtureController {
        @GetMapping("/api/v1/health") String health() { return "ok"; }
        @GetMapping("/api/v1/pets") String pets() { return "protected"; }
        @GetMapping("/api/v1/auth/monitoring-test/{id}")
        ResponseEntity<String> response(@PathVariable String id, @RequestParam(defaultValue = "200") int status,
                                        @RequestParam(defaultValue = "0") long delay) throws InterruptedException {
            if (delay > 0) Thread.sleep(delay);
            if (status == 400) throw new IllegalArgumentException("test input");
            if (status == 403) throw new AccessDeniedException("test denied");
            if (status == 500) throw new IllegalStateException("test failure");
            return ResponseEntity.status(status).body("fixture");
        }
    }
}
