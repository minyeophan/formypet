package com.formypet.domain.policy.repository.jdbc;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Database clock and singleton lock independent of the JPA first-level cache. */
@Repository
@RequiredArgsConstructor
public class PolicyDatabaseAccess {
    private final JdbcTemplate jdbc;

    public void lockPublication() {
        jdbc.queryForObject("SELECT id FROM policy_runtime WHERE id=1 FOR UPDATE", Integer.class);
    }

    public Instant now() {
        return jdbc.queryForObject("SELECT UTC_TIMESTAMP(6)", LocalDateTime.class).toInstant(ZoneOffset.UTC);
    }
}
