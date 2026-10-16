package com.formypet.domain.auth.repository.jdbc;

import com.formypet.global.time.UtcTime;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class RecoveryLimitRepository {
    private final JdbcTemplate jdbc;
    public record LimitState(Instant windowStart, Instant lastRequestAt, int requestCount) {}

    public void initialize(String bucket, Instant now, int windowSeconds) {
        jdbc.update("INSERT IGNORE INTO password_reset_limits(bucket_key,window_start,last_request_at,request_count) VALUES(?,?,?,0)",
                bucket, UtcTime.toDatabase(now), UtcTime.toDatabase(now.minusSeconds(windowSeconds + 1)));
    }

    public LimitState lock(String bucket) {
        return jdbc.queryForObject("SELECT window_start,last_request_at,request_count FROM password_reset_limits WHERE bucket_key=? FOR UPDATE",
                (rs, row) -> new LimitState(UtcTime.fromDatabase(rs.getObject(1, LocalDateTime.class)),
                        UtcTime.fromDatabase(rs.getObject(2, LocalDateTime.class)), rs.getInt(3)), bucket);
    }

    public void recordAccepted(String bucket, Instant windowStart, Instant now, int count) {
        jdbc.update("UPDATE password_reset_limits SET window_start=?,last_request_at=?,request_count=? WHERE bucket_key=?",
                UtcTime.toDatabase(windowStart), UtcTime.toDatabase(now), count, bucket);
    }
}
