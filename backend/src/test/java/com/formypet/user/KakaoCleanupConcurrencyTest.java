package com.formypet.user;

import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import static org.assertj.core.api.Assertions.assertThat;

class KakaoCleanupConcurrencyTest extends IntegrationTestSupport {
    @Autowired JdbcTemplate jdbc;
    @Autowired TransactionTemplate transactions;
    @Test void expiredLeaseDoesNotStartAnotherUnlinkWhileFirstWorkerIsStillCallingProvider() throws Exception {
        jdbc.update("DELETE FROM account_deletion_jobs");
        jdbc.update("INSERT INTO account_deletion_jobs(provider_user_id,next_attempt_at) VALUES ('cleanup-race',UTC_TIMESTAMP(6))");
        var entered = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        var calls = new AtomicInteger();
        KakaoAccountUnlinker unlinker = new KakaoAccountUnlinker() {
            public boolean isConfigured() { return true; }
            public void unlink(String id) {
                if (calls.incrementAndGet() == 1) {
                    entered.countDown();
                    try { if (!release.await(15, TimeUnit.SECONDS)) throw new IllegalStateException("timeout"); }
                    catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new IllegalStateException(e); }
                }
            }
        };
        var first = new KakaoAccountDeletionWorker(jdbc, unlinker);
        var second = new KakaoAccountDeletionWorker(jdbc, unlinker);
        try (var executor = Executors.newSingleThreadExecutor()) {
            var running = executor.submit(first::processOne);
            try {
                assertThat(entered.await(10, TimeUnit.SECONDS)).isTrue();
                jdbc.update("UPDATE account_deletion_jobs SET locked_until=DATE_SUB(UTC_TIMESTAMP(6),INTERVAL 1 MINUTE)");
                assertThat(second.processOne()).isFalse();
                assertThat(calls.get()).isEqualTo(1);
            } finally { release.countDown(); }
            assertThat(running.get(10, TimeUnit.SECONDS)).isTrue();
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM account_deletion_jobs", Integer.class)).isZero();
    }
}
