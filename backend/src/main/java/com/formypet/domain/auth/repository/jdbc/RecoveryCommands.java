package com.formypet.domain.auth.repository.jdbc;

import com.formypet.common.time.UtcTime;
import java.time.Instant;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class RecoveryCommands {
    private final JdbcTemplate jdbc;

    public void invalidatePending(String subject) {
        jdbc.update("UPDATE password_reset_challenges SET state='INVALIDATED' WHERE subject_key=? AND state='PENDING'", subject);
    }

    public void changePasswordAndRevokeSessions(long userId, String passwordHash, Instant now) {
        jdbc.update("UPDATE users SET password_hash=?,auth_version=auth_version+1,updated_at=? WHERE id=?",
                passwordHash, UtcTime.toDatabase(now), userId);
        jdbc.update("DELETE FROM refresh_tokens WHERE user_id=?", userId);
        jdbc.update("UPDATE device_tokens SET enabled=FALSE,updated_at=CURRENT_TIMESTAMP(6) WHERE user_id=?", userId);
        jdbc.update("UPDATE password_reset_challenges SET state='INVALIDATED' WHERE user_id=? AND state IN ('PENDING','VERIFIED')", userId);
    }

    public boolean isPendingCode(String id, Instant now) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE id=? AND state='PENDING' AND expires_at>?",
                Integer.class, id, UtcTime.toDatabase(now)) == 1;
    }

    public void cleanup(Instant instant) {
        var now = UtcTime.toDatabase(instant);
        jdbc.update("""
                DELETE FROM password_reset_challenges
                WHERE expires_at<? AND (reset_expires_at IS NULL OR reset_expires_at<?)
                  AND (completed_at IS NULL OR completed_at<?)
                """, now, now, now.minusMinutes(10));
        jdbc.update("DELETE FROM password_reset_limits WHERE last_request_at<?", now.minusHours(2));
    }
}
