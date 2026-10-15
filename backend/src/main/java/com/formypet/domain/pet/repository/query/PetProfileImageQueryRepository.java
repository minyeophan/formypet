package com.formypet.domain.pet.repository.query;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.Optional;

/** Read projection across media metadata; media lifecycle remains owned by media. */
@Repository
@RequiredArgsConstructor
public class PetProfileImageQueryRepository {
    private final JdbcTemplate jdbcTemplate;

    public Optional<Long> findLatestId(Long petId) {
        return jdbcTemplate.queryForList("""
                SELECT id
                FROM media_resources
                WHERE pet_id = ? AND record_id IS NULL AND media_kind = 'PET_PROFILE' AND status = 'STORED'
                ORDER BY created_at DESC, id DESC
                LIMIT 1
                """, Long.class, petId).stream().findFirst();
    }
}
