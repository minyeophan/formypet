package com.formypet.domain.petlog.repository;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class PetLogPhotoRepository {
    private final JdbcTemplate jdbc;
    public record PhotoRow(long id, int position, int width, int height) {}
    public List<Long> lockMediaIds(Long logId) {
        return jdbc.queryForList("SELECT media_id FROM pet_log_media WHERE pet_log_id=? FOR UPDATE", Long.class, logId);
    }
    public boolean promoteDraft(Long mediaId, Long userId, Long petId) {
        return jdbc.update("UPDATE media_resources SET media_kind='PET_LOG' WHERE id=? AND user_id=? AND pet_id=? AND media_kind='PET_LOG_DRAFT' AND record_id IS NULL", mediaId, userId, petId) > 0;
    }
    public void deleteLinks(Long logId) { jdbc.update("DELETE FROM pet_log_media WHERE pet_log_id=?", logId); }
    public void link(Long mediaId, Long logId, int position, int width, int height) {
        jdbc.update("INSERT INTO pet_log_media(media_id,pet_log_id,position,width,height) VALUES (?,?,?,?,?)", mediaId, logId, position, width, height);
    }
    public List<PhotoRow> find(Long logId) {
        return jdbc.query("SELECT m.id,pm.position,pm.width,pm.height FROM pet_log_media pm JOIN media_resources m ON m.id=pm.media_id WHERE pm.pet_log_id=? ORDER BY pm.position",
                (rs, n) -> new PhotoRow(rs.getLong("id"), rs.getInt("position"), rs.getInt("width"), rs.getInt("height")), logId);
    }
}
