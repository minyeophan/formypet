package com.formypet.user;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicBoolean;

@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "app.account-deletion.scheduler-enabled", havingValue = "true", matchIfMissing = true)
public class KakaoAccountDeletionWorker {
    private final JdbcTemplate jdbc;
    private final KakaoAccountUnlinker unlinker;
    private final AtomicBoolean running = new AtomicBoolean();

    private record Job(long id, String providerUserId) {}

    @Scheduled(fixedDelayString = "${app.account-deletion.interval-ms:30000}")
    public void dispatch() {
        if (!unlinker.isConfigured()) return;
        processOne();
    }

    @Scheduled(fixedDelayString = "${app.account-deletion.monitor-interval-ms:3600000}")
    public void monitorPending() {
        var counts = jdbc.queryForMap("""
                SELECT COUNT(*) AS total,
                       COALESCE(SUM(created_at < DATE_SUB(UTC_TIMESTAMP(6), INTERVAL 1 DAY)),0) AS overdue
                FROM account_deletion_jobs
                """);
        long total = ((Number) counts.get("total")).longValue();
        long overdue = ((Number) counts.get("overdue")).longValue();
        if (total > 0 && (!unlinker.isConfigured() || overdue > 0)) {
            // One day is an operational alert threshold, not a retention period or deletion promise.
            log.warn("Account cleanup needs operator attention: pending={}, olderThanOneDay={}, unlinkConfigured={}",
                    total, overdue, unlinker.isConfigured());
        }
    }

    public boolean processOne() {
        if (!running.compareAndSet(false, true)) return false;
        try {
            // A renewable row lease alone cannot stop an old HTTP call after lease expiry.
            // Keep one database session lock across dispatch, without holding row locks
            // during provider I/O. The connection is reserved only by the elected worker.
            return Boolean.TRUE.equals(jdbc.execute((org.springframework.jdbc.core.ConnectionCallback<Boolean>) connection -> {
                try (var statement = connection.prepareStatement("SELECT GET_LOCK(CONCAT(DATABASE(), ':kakao-unlink'),0)")) {
                    try (var result = statement.executeQuery()) {
                        if (!result.next() || result.getInt(1) != 1) return false;
                    }
                }
                try {
                    var workerJdbc = new JdbcTemplate(new org.springframework.jdbc.datasource.SingleConnectionDataSource(connection, true));
                    return processClaimed(workerJdbc);
                }
                finally {
                    try (var statement = connection.prepareStatement("SELECT RELEASE_LOCK(CONCAT(DATABASE(), ':kakao-unlink'))")) {
                        statement.execute();
                    } catch (java.sql.SQLException releaseFailure) {
                        connection.abort(Runnable::run);
                        throw releaseFailure;
                    }
                }
            }));
        } finally { running.set(false); }
    }

    private boolean processClaimed(JdbcTemplate workerJdbc) {
            Job job = claim(workerJdbc);
            if (job == null) return false;
            try {
                unlinker.unlink(job.providerUserId());
                workerJdbc.update("DELETE FROM account_deletion_jobs WHERE id=?", job.id());
                return true;
            } catch (RuntimeException failure) {
                int attempts = workerJdbc.queryForObject("SELECT attempts FROM account_deletion_jobs WHERE id=?", Integer.class, job.id());
                long delaySeconds = Math.min(86400L, 30L << Math.min(attempts, 11));
                workerJdbc.update("""
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
    }

    private Job claim(JdbcTemplate workerJdbc) {
            var jobs = workerJdbc.query("""
                    SELECT id,provider_user_id FROM account_deletion_jobs
                    WHERE next_attempt_at<=UTC_TIMESTAMP(6)
                      AND (locked_until IS NULL OR locked_until<UTC_TIMESTAMP(6))
                    ORDER BY next_attempt_at,id LIMIT 1
                    """, (rs, row) -> new Job(rs.getLong("id"), rs.getString("provider_user_id")));
            if (jobs.isEmpty()) return null;
            Job job = jobs.getFirst();
            workerJdbc.update("UPDATE account_deletion_jobs SET locked_until=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 5 MINUTE) WHERE id=?", job.id());
            return job;
    }
}
