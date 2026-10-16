package com.formypet.domain.auth.repository.jdbc;

import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Preliminary ownership lookup and current read after the caller locks the user. */
@Repository
@RequiredArgsConstructor
public class RefreshTokenCurrentReadRepository {
    private final JdbcTemplate jdbc;

    public Optional<Long> findOwner(String token) {
        return jdbc.queryForList("SELECT user_id FROM refresh_tokens WHERE token=?", Long.class, token)
                .stream().findFirst();
    }

    public boolean lockExists(String token, long userId) {
        return !jdbc.queryForList("SELECT id FROM refresh_tokens WHERE token=? AND user_id=? FOR UPDATE",
                Long.class, token, userId).isEmpty();
    }
}
