package com.formypet.common.ratelimit;

import com.formypet.support.IntegrationTestSupport;
import com.formypet.common.exception.ApiException;
import org.springframework.http.HttpStatus;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class RequestRateLimiterIntegrationTest extends IntegrationTestSupport {
    @Autowired RequestRateLimiter limiter;
    @Autowired JdbcTemplate jdbc;

    @Test
    void deletionEmailLimitIsStrictAcrossRollingHourBoundary() {
        Instant start = Instant.parse("2026-01-01T00:00:00Z");
        var window = new RequestRateLimiter.SlidingWindow("deletion-email-hour", "fake@example.test", 3, 3600, 1);
        for (int i = 0; i < 3; i++) {
            limiter.consumeAt(List.of(), List.of(window), start.plusSeconds(i));
        }

        var sentinel = new RequestRateLimiter.Bucket("sentinel", "same-request", 1, 3600);
        assertThatThrownBy(() -> limiter.consumeAt(List.of(sentinel), List.of(window), start.plusSeconds(3599)))
                .isInstanceOf(ApiException.class)
                .extracting(failure -> ((ApiException) failure).status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        limiter.consumeAt(List.of(sentinel), List.of(window), start.plusSeconds(3600));

        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM request_rate_limit_events", Integer.class)).isEqualTo(4);
    }

    @Test
    void clientAndGlobalLimitsAreStrictAcrossTheSameRollingHour() {
        Instant start = Instant.parse("2026-01-03T00:00:00Z");
        var global = new RequestRateLimiter.SlidingWindow("deletion-global", "all", 100, 3600, 1);
        for (int i = 0; i < 100; i++) {
            var distinctClient = new RequestRateLimiter.SlidingWindow("deletion-client", "client-" + i,
                    10, 3600, 1);
            limiter.consumeAt(List.of(), List.of(distinctClient, global), start.plusSeconds(i));
        }

        var newClient = new RequestRateLimiter.SlidingWindow("deletion-client", "client-new", 10, 3600, 1);
        assertThatThrownBy(() -> limiter.consumeAt(List.of(), List.of(newClient, global), start.plusSeconds(3599)))
                .isInstanceOf(ApiException.class)
                .extracting(failure -> ((ApiException) failure).status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        limiter.consumeAt(List.of(), List.of(newClient, global), start.plusSeconds(3600));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM request_rate_limit_events", Integer.class)).isEqualTo(202);
    }

    @Test
    void clientLimitDoesNotRefillBeforeItsOldestEventExpires() {
        Instant start = Instant.parse("2026-01-04T00:00:00Z");
        var client = new RequestRateLimiter.SlidingWindow("deletion-client", "shared-client", 10, 3600, 1);
        for (int i = 0; i < 10; i++) {
            limiter.consumeAt(List.of(), List.of(client), start.plusSeconds(i));
        }

        assertThatThrownBy(() -> limiter.consumeAt(List.of(), List.of(client), start.plusSeconds(3599)))
                .isInstanceOf(ApiException.class)
                .extracting(failure -> ((ApiException) failure).status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        limiter.consumeAt(List.of(), List.of(client), start.plusSeconds(3600));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM request_rate_limit_events", Integer.class)).isEqualTo(11);
    }

    @Test
    void concurrentRequestsCannotExceedTheSlidingWindowLimit() throws Exception {
        Instant now = Instant.parse("2026-01-02T00:00:00Z");
        var window = new RequestRateLimiter.SlidingWindow("deletion-email-hour", "race@example.test", 3, 3600, 1);
        var ready = new CountDownLatch(8);
        var start = new CountDownLatch(1);
        var accepted = new AtomicInteger();
        try (var executor = Executors.newFixedThreadPool(8)) {
            for (int i = 0; i < 8; i++) {
                executor.submit(() -> {
                    ready.countDown();
                    try {
                        start.await();
                        limiter.consumeAt(List.of(), List.of(window), now);
                        accepted.incrementAndGet();
                    } catch (ApiException limited) {
                        assertThat(limited.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    } catch (InterruptedException interrupted) {
                        Thread.currentThread().interrupt();
                        throw new RuntimeException(interrupted);
                    }
                });
            }
            ready.await();
            start.countDown();
        }
        assertThat(accepted.get()).isEqualTo(3);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM request_rate_limit_events", Integer.class)).isEqualTo(3);
    }
}
