package com.formypet.domain.auth.repository.jdbc;

import com.formypet.domain.auth.entity.SessionSnapshot;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Current authentication reads must not reuse JPA's managed User state. */
@Repository
@RequiredArgsConstructor
public class SessionSnapshotRepository {
    private final JdbcTemplate jdbc;
    private static final String SELECT = "SELECT id,email,password_hash,registration_source,auth_version FROM users ";

    public Optional<SessionSnapshot> findByEmail(String email) {
        return read("WHERE email=? AND account_status='ACTIVE'", email, false);
    }

    public Optional<SessionSnapshot> findById(long id) {
        return read("WHERE id=? AND account_status='ACTIVE'", id, false);
    }

    public Optional<SessionSnapshot> lockByEmail(String email) {
        return read("WHERE email=? AND account_status='ACTIVE'", email, true);
    }

    public Optional<SessionSnapshot> lockById(long id) {
        return read("WHERE id=? AND account_status='ACTIVE'", id, true);
    }

    private Optional<SessionSnapshot> read(String where, Object key, boolean lock) {
        return jdbc.query(SELECT + where + (lock ? " FOR UPDATE" : ""), (rs, row) -> new SessionSnapshot(
                rs.getLong("id"), rs.getString("email"), rs.getString("password_hash"),
                rs.getString("registration_source"), rs.getLong("auth_version")), key).stream().findFirst();
    }
}
