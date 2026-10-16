package com.formypet.global.ratelimit.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;

/** Atomic bucket and event access; transaction and admission policy belong to the limiter. */
@Repository
@RequiredArgsConstructor
public class RequestRateLimitRepository {
    private final JdbcTemplate jdbc;
    public record BucketState(double available, Instant updatedAt) {}

    public void initializeAndLock(String scope, String key, int capacity, Instant now) {
        jdbc.update("""
                INSERT IGNORE INTO request_rate_limits(scope,bucket_key,available_tokens,updated_at)
                VALUES(?,?,?,?)
                """, scope, key, capacity, Timestamp.from(now));
        jdbc.queryForObject("""
                SELECT available_tokens FROM request_rate_limits
                WHERE scope=? AND bucket_key=? FOR UPDATE
                """, Double.class, scope, key);
    }

    public BucketState lockState(String scope, String key) {
        return jdbc.queryForObject("""
                SELECT available_tokens,updated_at FROM request_rate_limits
                WHERE scope=? AND bucket_key=? FOR UPDATE
                """, (rs, row) -> new BucketState(rs.getDouble("available_tokens"),
                toInstant(rs.getObject("updated_at"))), scope, key);
    }

    public int countEventsAfter(String scope, String key, Instant start) {
        Integer count = jdbc.queryForObject("""
                SELECT COUNT(*) FROM request_rate_limit_events
                WHERE scope=? AND bucket_key=? AND occurred_at>?
                """, Integer.class, scope, key, Timestamp.from(start));
        return count == null ? 0 : count;
    }

    public Long oldestEventOffset(String scope, String key, Instant start, Instant now, int limit) {
        return jdbc.queryForObject("""
                SELECT TIMESTAMPDIFF(SECOND, ?, MIN(occurred_at)) FROM (
                  SELECT occurred_at FROM request_rate_limit_events
                  WHERE scope=? AND bucket_key=? AND occurred_at>? ORDER BY occurred_at LIMIT ?
                ) active_events
                """, Long.class, Timestamp.from(now), scope, key, Timestamp.from(start), limit);
    }

    public void updateTokens(String scope, String key, double available, Instant now) {
        jdbc.update("""
                UPDATE request_rate_limits SET available_tokens=?,updated_at=?
                WHERE scope=? AND bucket_key=?
                """, available, Timestamp.from(now), scope, key);
    }

    public void addEvent(String scope, String key, Instant now) {
        jdbc.update("INSERT INTO request_rate_limit_events(scope,bucket_key,occurred_at) VALUES(?,?,?)",
                scope, key, Timestamp.from(now));
    }

    public void touch(String scope, String key, Instant now) {
        jdbc.update("UPDATE request_rate_limits SET updated_at=? WHERE scope=? AND bucket_key=?",
                Timestamp.from(now), scope, key);
    }

    public void deleteEventsBefore(Instant before) {
        jdbc.update("DELETE FROM request_rate_limit_events WHERE occurred_at < ?", Timestamp.from(before));
    }

    public void deleteBucketsBefore(Instant before) {
        jdbc.update("DELETE FROM request_rate_limits WHERE updated_at < ?", Timestamp.from(before));
    }

    private Instant toInstant(Object value) {
        if (value instanceof Timestamp timestamp) return timestamp.toInstant();
        if (value instanceof LocalDateTime local) return local.toInstant(ZoneOffset.UTC);
        throw new IllegalStateException("Unexpected request limit timestamp type");
    }
}
