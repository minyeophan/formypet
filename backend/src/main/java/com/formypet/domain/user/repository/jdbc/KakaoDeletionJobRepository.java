package com.formypet.domain.user.repository.jdbc;

import java.util.function.Function;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class KakaoDeletionJobRepository {
    private final JdbcTemplate jdbc;
    public record Job(long id, String providerUserId) {}
    public record Counts(long total, long overdue) {}

    public Counts counts() {
        return jdbc.queryForObject("""
                SELECT COUNT(*) AS total,
                  COALESCE(SUM(created_at < DATE_SUB(UTC_TIMESTAMP(6), INTERVAL 1 DAY)),0) AS overdue
                FROM account_deletion_jobs
                """, (rs, row) -> new Counts(rs.getLong("total"), rs.getLong("overdue")));
    }

    /** The same physical connection owns the advisory lock across provider I/O and queue updates. */
    public boolean withExclusiveLock(Function<LockedSession, Boolean> work) {
        return Boolean.TRUE.equals(jdbc.execute((ConnectionCallback<Boolean>) connection -> {
            try (var statement = connection.prepareStatement("SELECT GET_LOCK(CONCAT(DATABASE(), ':kakao-unlink'),0)")) {
                try (var result = statement.executeQuery()) {
                    if (!result.next() || result.getInt(1) != 1) return false;
                }
            }
            try {
                return work.apply(new LockedSession(new JdbcTemplate(new SingleConnectionDataSource(connection, true))));
            } finally {
                try (var statement = connection.prepareStatement("SELECT RELEASE_LOCK(CONCAT(DATABASE(), ':kakao-unlink'))")) {
                    statement.execute();
                } catch (java.sql.SQLException releaseFailure) {
                    connection.abort(Runnable::run);
                    throw releaseFailure;
                }
            }
        }));
    }

    /** Valid only within withExclusiveLock; callers never receive the JDBC connection. */
    public static final class LockedSession {
        private final JdbcTemplate jdbc;
        private LockedSession(JdbcTemplate jdbc) { this.jdbc = jdbc; }

        public Job claim() {
            var jobs = jdbc.query("""
                    SELECT id,provider_user_id FROM account_deletion_jobs
                    WHERE next_attempt_at<=UTC_TIMESTAMP(6)
                      AND (locked_until IS NULL OR locked_until<UTC_TIMESTAMP(6))
                    ORDER BY next_attempt_at,id LIMIT 1
                    """, (rs, row) -> new Job(rs.getLong("id"), rs.getString("provider_user_id")));
            if (jobs.isEmpty()) return null;
            Job job = jobs.getFirst();
            jdbc.update("UPDATE account_deletion_jobs SET locked_until=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 5 MINUTE) WHERE id=?", job.id());
            return job;
        }
        public void delete(long id) {
            jdbc.update("DELETE FROM account_deletion_jobs WHERE id=?", id);
        }
        public int attempts(long id) {
            return jdbc.queryForObject("SELECT attempts FROM account_deletion_jobs WHERE id=?", Integer.class, id);
        }
        public void reschedule(long id, long delaySeconds, String errorClass) {
            jdbc.update("""
                    UPDATE account_deletion_jobs SET attempts=attempts+1,
                      next_attempt_at=DATE_ADD(UTC_TIMESTAMP(6), INTERVAL ? SECOND),
                      locked_until=NULL,last_error=? WHERE id=?
                    """, delaySeconds, errorClass, id);
        }
    }
}
