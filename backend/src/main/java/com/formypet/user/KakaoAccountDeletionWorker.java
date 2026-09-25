package com.formypet.user;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoAccountDeletionWorker {
    private final JdbcTemplate jdbc;
    private final TransactionTemplate transactionTemplate;
    private final KakaoAccountUnlinker unlinker;
    private final AtomicBoolean running = new AtomicBoolean();

    private record Job(long id, String providerUserId) {}

    @Scheduled(fixedDelayString = "${app.account-deletion.interval-ms:30000}")
    public void dispatch() {
        if (!unlinker.isConfigured()) return;
        processOne();
    }

    public boolean processOne() {
        if (!running.compareAndSet(false, true)) return false;
        try {
            Job job = claim();
            if (job == null) return false;
            try {
                unlinker.unlink(job.providerUserId());
                jdbc.update("DELETE FROM account_deletion_jobs WHERE id=?", job.id());
                return true;
            } catch (RuntimeException failure) {
                int attempts = jdbc.queryForObject("SELECT attempts FROM account_deletion_jobs WHERE id=?", Integer.class, job.id());
                long delaySeconds = Math.min(86400L, 30L << Math.min(attempts, 11));
                jdbc.update("""
                        UPDATE account_deletion_jobs
                        SET attempts=attempts+1,
                            next_attempt_at=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL ? SECOND),
                            locked_until=NULL,last_error=?
                        WHERE id=?
                        """, delaySeconds, failure.getClass().getSimpleName(), job.id());
                log.warn("Kakao unlink retry scheduled: attempt={}, error={}", attempts + 1,
                        failure.getClass().getSimpleName());
                return false;
            }
        } finally {
            running.set(false);
        }
    }

    private Job claim() {
        return transactionTemplate.execute(status -> {
            var jobs = jdbc.query("""
                    SELECT id,provider_user_id FROM account_deletion_jobs
                    WHERE next_attempt_at<=UTC_TIMESTAMP(6)
                      AND (locked_until IS NULL OR locked_until<UTC_TIMESTAMP(6))
                    ORDER BY next_attempt_at,id LIMIT 1 FOR UPDATE SKIP LOCKED
                    """, (rs, row) -> new Job(rs.getLong("id"), rs.getString("provider_user_id")));
            if (jobs.isEmpty()) return null;
            Job job = jobs.getFirst();
            jdbc.update("UPDATE account_deletion_jobs SET locked_until=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 5 MINUTE) WHERE id=?", job.id());
            return job;
        });
    }
}
