package com.formypet.global.idempotency.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.Optional;

/** Current reads share the caller's transaction and follow its account lock. */
@Repository
@RequiredArgsConstructor
public class IdempotencyRepository {
    private final JdbcTemplate jdbc;

    public record Receipt(String hash, long resultId, Long resultVersion) {}

    public Optional<Receipt> findCurrent(Long actorId, String operation, String target, String key) {
        return jdbc.query("""
                SELECT request_hash, result_id, result_version FROM idempotency_requests
                WHERE user_id=? AND operation=? AND target=? AND request_key=? FOR UPDATE
                """, (rs, n) -> new Receipt(rs.getString(1), rs.getLong(2), (Long) rs.getObject(3)),
                actorId, operation, target, key).stream().findFirst();
    }

    public void insert(Long actorId, String operation, String target, String key,
                       String fingerprint, long resultId, Long resultVersion) {
        jdbc.update("""
                INSERT INTO idempotency_requests(user_id, operation, target, request_key, request_hash, result_id, result_version)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """, actorId, operation, target, key, fingerprint, resultId, resultVersion);
    }
}
