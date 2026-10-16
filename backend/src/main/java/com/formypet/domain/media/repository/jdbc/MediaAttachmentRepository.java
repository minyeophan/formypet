package com.formypet.domain.media.repository.jdbc;

import com.formypet.domain.media.repository.query.MediaFile;
import com.formypet.domain.media.repository.query.MediaLocation;
import java.util.Collections;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

/** Cross-domain joins and current-read locks used after locking the media owner. */
@Repository
@RequiredArgsConstructor
public class MediaAttachmentRepository {
    private static final RowMapper<MediaFile> FILE = (rs, row) ->
            new MediaFile(rs.getLong("id"), rs.getString("storage_key"), rs.getLong("file_size"));
    private final JdbcTemplate jdbc;

    public boolean recordBelongsToPet(Long recordId, Long petId) {
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM activity_records WHERE id = ? AND pet_id = ?",
                Integer.class, recordId, petId);
        return count != null && count > 0;
    }

    public Optional<MediaLocation> profileImage(Long userId) {
        return jdbc.query("""
                SELECT mr.storage_key, mr.content_type
                FROM users u JOIN media_resources mr ON mr.id = u.profile_media_id
                WHERE u.id = ?
                """, (rs, row) -> new MediaLocation(rs.getString("storage_key"), rs.getString("content_type")),
                userId).stream().findFirst();
    }

    public List<MediaFile> lockRecord(Long userId, Long recordId) {
        return jdbc.query("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND record_id=? FOR UPDATE",
                FILE, userId, recordId);
    }

    public List<MediaFile> lockPetLog(Long userId, Long petLogId) {
        return jdbc.query("""
                SELECT m.id,m.storage_key,m.file_size FROM media_resources m
                JOIN pet_log_media pm ON pm.media_id=m.id
                JOIN pet_logs pl ON pl.id=pm.pet_log_id
                WHERE pl.id=? AND pl.user_id=? AND m.user_id=? AND m.media_kind='PET_LOG' FOR UPDATE
                """, FILE, petLogId, userId, userId);
    }

    public List<MediaFile> lockPetLogIds(Long userId, List<Long> ids) {
        if (ids.isEmpty()) return List.of();
        return jdbc.query("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND media_kind='PET_LOG' AND id IN ("
                + placeholders(ids) + ") FOR UPDATE", FILE, prepend(userId, ids));
    }

    public int deletePetLogIds(Long userId, List<Long> ids) {
        if (ids.isEmpty()) return 0;
        return jdbc.update("DELETE FROM media_resources WHERE user_id=? AND media_kind='PET_LOG' AND id IN ("
                + placeholders(ids) + ")", prepend(userId, ids));
    }

    public List<MediaFile> lockPetLogFilesForPet(Long userId, Long petId) {
        return jdbc.query("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND pet_id=? AND media_kind IN ('PET_LOG_DRAFT','PET_LOG') FOR UPDATE",
                FILE, userId, petId);
    }

    public void deletePetLogData(Long userId, Long petId) {
        jdbc.update("DELETE FROM pet_logs WHERE user_id=? AND pet_id=?", userId, petId);
        jdbc.update("DELETE FROM pet_log_preferences WHERE user_id=? AND pet_id=?", userId, petId);
    }

    public int deletePetLogFilesForPet(Long userId, Long petId) {
        return jdbc.update("DELETE FROM media_resources WHERE user_id=? AND pet_id=? AND media_kind IN ('PET_LOG_DRAFT','PET_LOG')", userId, petId);
    }

    public List<Long> expiredDraftOwners() {
        return jdbc.queryForList("SELECT DISTINCT user_id FROM media_resources WHERE media_kind='PET_LOG_DRAFT' AND created_at < UTC_TIMESTAMP(6)-INTERVAL 24 HOUR ORDER BY user_id", Long.class);
    }

    public List<MediaFile> lockExpiredDrafts(Long userId) {
        return jdbc.query("SELECT id,storage_key,file_size FROM media_resources WHERE user_id=? AND media_kind='PET_LOG_DRAFT' AND created_at < UTC_TIMESTAMP(6)-INTERVAL 24 HOUR FOR UPDATE", FILE, userId);
    }

    public int deleteExpiredDrafts(Long userId) {
        return jdbc.update("DELETE FROM media_resources WHERE user_id=? AND media_kind='PET_LOG_DRAFT' AND created_at < UTC_TIMESTAMP(6)-INTERVAL 24 HOUR", userId);
    }

    private String placeholders(List<Long> ids) {
        return String.join(",", Collections.nCopies(ids.size(), "?"));
    }

    private Object[] prepend(Long userId, List<Long> ids) {
        Object[] parameters = new Object[ids.size() + 1];
        parameters[0] = userId;
        for (int i = 0; i < ids.size(); i++) parameters[i + 1] = ids.get(i);
        return parameters;
    }
}
