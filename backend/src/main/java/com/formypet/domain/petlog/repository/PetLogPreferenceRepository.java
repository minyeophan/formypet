package com.formypet.domain.petlog.repository;

import com.formypet.global.time.UtcTime;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.time.Instant;

@Repository
@RequiredArgsConstructor
public class PetLogPreferenceRepository {
    private final JdbcTemplate jdbc;
    public void dismiss(Long userId, Long petId, Instant now) {
        jdbc.update("INSERT INTO pet_log_preferences(pet_id,user_id,example_dismissed,updated_at) VALUES (?,?,TRUE,?) ON DUPLICATE KEY UPDATE example_dismissed=TRUE,updated_at=VALUES(updated_at)",
                petId, userId, UtcTime.toDatabase(now));
    }
    public void dismiss(Long userId, Long petId) {
        jdbc.update("INSERT INTO pet_log_preferences(pet_id,user_id,example_dismissed) VALUES (?,?,TRUE) ON DUPLICATE KEY UPDATE example_dismissed=TRUE,updated_at=VALUES(updated_at)", petId, userId);
    }
    public boolean isDismissed(Long userId, Long petId) {
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM pet_log_preferences WHERE pet_id=? AND user_id=? AND example_dismissed=TRUE", Integer.class, petId, userId);
        return count != null && count > 0;
    }
}
