package com.formypet.domain.auth;

import com.formypet.domain.auth.repository.jdbc.RecoveryLimitRepository;
import com.formypet.support.IntegrationTestSupport;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class RecoveryLimitRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired RecoveryLimitRepository limits;

    @Test void insertIfAbsentPreservesExistingWindowAndLockedStateRoundTripsUtcMicroseconds() {
        String bucket = "b".repeat(64);
        Instant now = Instant.parse("2026-10-16T04:05:06.123456Z");
        limits.initialize(bucket, now, 60);
        var first = limits.lock(bucket);
        assertThat(first.windowStart()).isEqualTo(now);
        assertThat(first.lastRequestAt()).isEqualTo(now.minusSeconds(61));
        assertThat(first.requestCount()).isZero();
        limits.recordAccepted(bucket, now, now.plusSeconds(2), 3);
        limits.initialize(bucket, now.plusSeconds(20), 600);
        var retained = limits.lock(bucket);
        assertThat(retained.windowStart()).isEqualTo(now);
        assertThat(retained.lastRequestAt()).isEqualTo(now.plusSeconds(2));
        assertThat(retained.requestCount()).isEqualTo(3);
    }
}
