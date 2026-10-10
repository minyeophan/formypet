package com.formypet.media;

import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;
import java.util.UUID;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;

class MediaStorageAttemptsIntegrationTest extends IntegrationTestSupport {
    @Autowired JdbcTemplate jdbc;
    @Autowired MediaStorageAttempts attempts;
    @Autowired TransactionTemplate transactions;

    @Test void recoveryQueuesOnlyAbandonedWritesAndSurvivesOuterRollback() {
        String key = "attempt-test/" + UUID.randomUUID() + ".png";
        transactions.executeWithoutResult(tx -> {
            attempts.begin(key);
            tx.setRollbackOnly();
        });
        age(key);
        attempts.recover();
        assertThat(count("media_storage_attempts", key)).isZero();
        assertThat(count("media_cleanup_queue", key)).isEqualTo(1);
        jdbc.update("DELETE FROM media_cleanup_queue WHERE storage_key=?", key);
    }

    @Test void recoverySkipsAnActiveWriterEvenAfterExpiry() throws Exception {
        String key = "attempt-test/" + UUID.randomUUID() + ".png";
        attempts.begin(key);
        age(key);
        var locked = new CountDownLatch(1);
        var release = new CountDownLatch(1);
        try (var executor = Executors.newSingleThreadExecutor()) {
            Future<?> writer = executor.submit(() -> transactions.executeWithoutResult(tx -> {
                jdbc.queryForObject("SELECT storage_key FROM media_storage_attempts WHERE storage_key=? FOR UPDATE", String.class, key);
                locked.countDown();
                try { if (!release.await(20, TimeUnit.SECONDS)) throw new IllegalStateException("test writer timeout"); }
                catch (InterruptedException e) { Thread.currentThread().interrupt(); throw new RuntimeException(e); }
            }));
            try {
                assertThat(locked.await(10, TimeUnit.SECONDS)).isTrue();
                attempts.recover();
                assertThat(count("media_cleanup_queue", key)).isZero();
                assertThat(count("media_storage_attempts", key)).isEqualTo(1);
            } finally { release.countDown(); }
            writer.get(10, TimeUnit.SECONDS);
        }
        attempts.recover();
        assertThat(count("media_cleanup_queue", key)).isEqualTo(1);
        jdbc.update("DELETE FROM media_cleanup_queue WHERE storage_key=?", key);
    }

    private void age(String key) {
        jdbc.update("UPDATE media_storage_attempts SET created_at=UTC_TIMESTAMP(6)-INTERVAL 2 HOUR WHERE storage_key=?", key);
    }
    private int count(String table, String key) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM " + table + " WHERE storage_key=?", Integer.class, key);
    }
}
