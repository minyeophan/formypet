package com.formypet.domain.routine.repository.query;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
@RequiredArgsConstructor
public class RoutineActivityTypeRepository {
    private final JdbcTemplate jdbc;
    public boolean exists(String typeId) {
        Integer count = jdbc.queryForObject("SELECT COUNT(*) FROM activity_types WHERE id = ?", Integer.class, typeId);
        return count != null && count > 0;
    }
}
