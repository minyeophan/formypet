package com.formypet.media;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Durable intent precedes I/O; the writer holds the intent row lock until its DB transaction ends. */
@Service
@RequiredArgsConstructor
public class MediaStorageAttempts {
    private final JdbcTemplate jdbc;

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void begin(String key) {
        jdbc.update("INSERT INTO media_storage_attempts(storage_key) VALUES (?)", key);
    }

    @Transactional
    public void recover() {
        var keys = jdbc.queryForList("""
                SELECT storage_key FROM media_storage_attempts
                WHERE created_at < UTC_TIMESTAMP(6) - INTERVAL 1 HOUR
                ORDER BY created_at LIMIT 100 FOR UPDATE SKIP LOCKED
                """, String.class);
        for (String key : keys) {
            Integer references = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM media_resources WHERE storage_key=?", Integer.class, key);
            if (references != null && references == 0) {
                jdbc.update("INSERT IGNORE INTO media_cleanup_queue(storage_key) VALUES (?)", key);
            }
            jdbc.update("DELETE FROM media_storage_attempts WHERE storage_key=?", key);
        }
    }
}
