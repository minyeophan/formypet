package com.formypet.global.idempotency.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.Optional;

/** Read projections for verifying that a receipt's resource still exists. */
@Repository
@RequiredArgsConstructor
public class ReplayTargetRepository {
    private final JdbcTemplate jdbc;
    public record StoredMedia(long id, String originalName, String contentType, long fileSize, String status) {}

    public boolean petExists(Long actorId, Long petId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM pets WHERE id=? AND user_id=? AND is_deleted=false",
                Long.class, petId, actorId) > 0;
    }

    public boolean recordExists(Long petId, Long recordId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM activity_records WHERE id=? AND pet_id=?",
                Long.class, recordId, petId) > 0;
    }

    public boolean postExists(Long actorId, Long postId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM posts WHERE id=? AND user_id=?",
                Long.class, postId, actorId) > 0;
    }

    public Optional<StoredMedia> findStoredMedia(Long actorId, Long mediaId) {
        return jdbc.query("""
                SELECT id, original_name, content_type, file_size, status FROM media_resources
                WHERE id=? AND user_id=? AND status='STORED'
                """, (rs, n) -> new StoredMedia(rs.getLong("id"), rs.getString("original_name"),
                rs.getString("content_type"), rs.getLong("file_size"), rs.getString("status")),
                mediaId, actorId).stream().findFirst();
    }
}
