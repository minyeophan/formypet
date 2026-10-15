package com.formypet.domain.media;

import com.formypet.domain.media.repository.jdbc.MediaWorkRepository;
import com.formypet.support.IntegrationTestSupport;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class MediaWorkRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired MediaWorkRepository work;
    @Autowired JdbcTemplate jdbc;

    @Test
    void attemptMustAgeBeforeRecoveryAndCanBeLockedAndFinished() {
        String key = "work/" + UUID.randomUUID() + ".png";
        work.beginAttempt(key);
        work.lockAttempt(key);
        assertThat(work.abandonedKeys()).doesNotContain(key);
        jdbc.update("UPDATE media_storage_attempts SET created_at=UTC_TIMESTAMP(6)-INTERVAL 2 HOUR WHERE storage_key=?", key);
        assertThat(work.abandonedKeys()).contains(key);
        work.finishAttempt(key);
        assertThat(work.abandonedKeys()).doesNotContain(key);
    }

    @Test
    void cleanupEnqueueIsIdempotentAndPendingKeysHaveStableOrder() {
        String prefix = "queue/" + UUID.randomUUID();
        String first = prefix + "a.png";
        String second = prefix + "b.png";
        work.enqueue(second);
        work.enqueue(first);
        work.enqueue(first);
        jdbc.update("UPDATE media_cleanup_queue SET created_at='2026-01-01 00:00:00' WHERE storage_key IN (?,?)", first, second);
        assertThat(work.pendingKeys().stream().filter(k -> k.startsWith(prefix)).toList())
                .containsExactly(first, second);
        assertThat(work.referenceCount(first)).isZero();
        work.deleteQueued(first);
        assertThat(work.pendingKeys()).doesNotContain(first).contains(second);
    }
}
