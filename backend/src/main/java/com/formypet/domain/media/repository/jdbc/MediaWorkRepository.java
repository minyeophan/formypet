package com.formypet.domain.media.repository.jdbc;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** SQL for durable storage intents and committed cleanup work; callers own transactions. */
@Repository
@RequiredArgsConstructor
public class MediaWorkRepository {
    private final JdbcTemplate jdbc;

    public void beginAttempt(String key) {
        jdbc.update("INSERT INTO media_storage_attempts(storage_key) VALUES (?)", key);
    }

    public void lockAttempt(String key) {
        jdbc.queryForObject("SELECT storage_key FROM media_storage_attempts WHERE storage_key=? FOR UPDATE",
                String.class, key);
    }

    public void finishAttempt(String key) {
        jdbc.update("DELETE FROM media_storage_attempts WHERE storage_key=?", key);
    }

    public List<String> abandonedKeys() {
        return jdbc.queryForList("""
                SELECT storage_key FROM media_storage_attempts
                WHERE created_at < UTC_TIMESTAMP(6) - INTERVAL 1 HOUR
                ORDER BY created_at LIMIT 100 FOR UPDATE SKIP LOCKED
                """, String.class);
    }

    public Integer referenceCount(String key) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM media_resources WHERE storage_key=?", Integer.class, key);
    }

    public void enqueue(String key) {
        jdbc.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)", key);
    }

    public List<String> pendingKeys() {
        return jdbc.queryForList("""
                SELECT storage_key
                FROM media_cleanup_queue
                ORDER BY created_at, storage_key
                """, String.class);
    }

    public void deleteQueued(String key) {
        jdbc.update("DELETE FROM media_cleanup_queue WHERE storage_key = ?", key);
    }
}
