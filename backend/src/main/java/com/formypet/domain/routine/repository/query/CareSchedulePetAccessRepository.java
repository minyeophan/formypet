package com.formypet.domain.routine.repository.query;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.Optional;

/** Read access facts including deleted pets, preserving the API's error precedence. */
@Repository
@RequiredArgsConstructor
public class CareSchedulePetAccessRepository {
    private final JdbcTemplate jdbcTemplate;

    public boolean userExists(Long userId) {
        return !jdbcTemplate.queryForList("SELECT id FROM users WHERE id = ?", Long.class, userId).isEmpty();
    }

    public Optional<PetRow> findPet(Long petId) {
        return jdbcTemplate.query("SELECT id, user_id, is_deleted FROM pets WHERE id = ?",
                (rs, rowNum) -> new PetRow(rs.getLong("id"), rs.getLong("user_id"),
                        rs.getBoolean("is_deleted")), petId).stream().findFirst();
    }

    public record PetRow(Long id, Long userId, boolean deleted) {}
}
