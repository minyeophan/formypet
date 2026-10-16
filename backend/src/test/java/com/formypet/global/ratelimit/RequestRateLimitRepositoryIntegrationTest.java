package com.formypet.global.ratelimit;

import com.formypet.global.ratelimit.repository.RequestRateLimitRepository;
import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class RequestRateLimitRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired RequestRateLimitRepository limits;
    @Autowired JdbcTemplate jdbc;

    @Test
    void initializationAndCurrentStatePreserveFractionalTokensAndUtcMicroseconds() {
        Instant now = Instant.parse("2026-10-16T04:05:06.123456Z");
        String key = "a".repeat(64);
        limits.initializeAndLock("test", key, 10, now);
        limits.updateTokens("test", key, 2.5, now.plusSeconds(1));
        limits.initializeAndLock("test", key, 100, now.plusSeconds(5));
        var state = limits.lockState("test", key);
        assertThat(state.available()).isEqualTo(2.5);
        assertThat(state.updatedAt()).isEqualTo(now.plusSeconds(1));
        limits.touch("test", key, now.plusSeconds(2));
        assertThat(limits.lockState("test", key).updatedAt()).isEqualTo(now.plusSeconds(2));
    }

    @Test
    void windowAndCleanupBoundariesRemainStrict() {
        Instant now = Instant.parse("2026-10-16T04:05:06Z");
        String key = "b".repeat(64);
        limits.initializeAndLock("test", key, 0, now);
        limits.addEvent("test", key, now.minusSeconds(1));
        limits.addEvent("test", key, now);
        limits.addEvent("test", key, now.plusSeconds(1));
        assertThat(limits.countEventsAfter("test", key, now)).isEqualTo(1);
        assertThat(limits.oldestEventOffset("test", key, now.minusSeconds(2), now.plusSeconds(10), 2)).isEqualTo(-11L);
        limits.deleteEventsBefore(now);
        assertThat(limits.countEventsAfter("test", key, now.minusSeconds(2))).isEqualTo(2);
        limits.deleteBucketsBefore(now);
        assertThat(limits.lockState("test", key)).isNotNull();
        limits.deleteBucketsBefore(now.plusSeconds(1));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM request_rate_limits WHERE scope='test'", Integer.class)).isZero();
    }
}
