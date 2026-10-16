package com.formypet.domain.media.repository.jdbc;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Atomic counters and owner-first locks share the caller's media transaction. */
@Repository
@RequiredArgsConstructor
public class MediaQuotaRepository {
    private final JdbcTemplate jdbc;

    public int reserve(Long userId, long bytes, int items, long maxBytes, int maxItems) {
        return jdbc.update("""
                UPDATE users SET media_bytes_used=media_bytes_used+?, media_items_used=media_items_used+?
                WHERE id=? AND media_bytes_used+? BETWEEN 0 AND ? AND media_items_used+? BETWEEN 0 AND ?
                """, bytes, items, userId, bytes, maxBytes, items, maxItems);
    }

    public void decrement(Long userId, long bytes, int items) {
        jdbc.update("""
                UPDATE users SET media_bytes_used=GREATEST(media_bytes_used-?,0),
                                 media_items_used=GREATEST(media_items_used-?,0)
                WHERE id=?
                """, bytes, items, userId);
    }

    public boolean lockOwner(Long userId) {
        return !jdbc.queryForList("SELECT id FROM users WHERE id=? FOR UPDATE", Long.class, userId).isEmpty();
    }
}
