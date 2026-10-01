package com.formypet.auth.recovery;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import java.time.*;
import java.util.Map;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.*;

class RecoveryRateLimiterTest {
    @Test void noCooldownDoesNotRejectAnEarlierArrivingConcurrentRequest() {
        var jdbc = mock(JdbcTemplate.class);
        var crypto = mock(RecoveryCrypto.class);
        var instant = Instant.parse("2026-09-28T00:00:00Z");
        var now = LocalDateTime.ofInstant(instant, ZoneOffset.UTC);
        when(crypto.digest(anyString(), anyString())).thenReturn("bucket");
        // Another request can obtain the row lock first despite starting later.
        when(jdbc.queryForMap(anyString(), eq("bucket"))).thenReturn(Map.of(
                "window_start", now, "last_request_at", now.plusNanos(1000), "request_count", 1));
        var limits = new RecoveryRateLimiter(jdbc, mock(PlatformTransactionManager.class), crypto,
                Clock.fixed(instant, ZoneOffset.UTC));
        assertThatCode(() -> limits.consume("confirm-ip", "test", 10, 60, 0)).doesNotThrowAnyException();
    }
}
