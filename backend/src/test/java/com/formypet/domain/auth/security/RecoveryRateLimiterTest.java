package com.formypet.domain.auth.security;

import org.junit.jupiter.api.Test;
import com.formypet.domain.auth.repository.jdbc.RecoveryLimitRepository;
import org.springframework.transaction.PlatformTransactionManager;
import java.time.*;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.*;

class RecoveryRateLimiterTest {
    @Test void noCooldownDoesNotRejectAnEarlierArrivingConcurrentRequest() {
        var repository = mock(RecoveryLimitRepository.class);
        var crypto = mock(RecoveryCrypto.class);
        var instant = Instant.parse("2026-09-28T00:00:00Z");
        when(crypto.digest(anyString(), anyString())).thenReturn("bucket");
        // Another request can obtain the row lock first despite starting later.
        when(repository.lock("bucket")).thenReturn(new RecoveryLimitRepository.LimitState(
                instant, instant.plusNanos(1000), 1));
        var limits = new RecoveryRateLimiter(repository, mock(PlatformTransactionManager.class), crypto,
                Clock.fixed(instant, ZoneOffset.UTC));
        assertThatCode(() -> limits.consume("confirm-ip", "test", 10, 60, 0)).doesNotThrowAnyException();
    }
}
