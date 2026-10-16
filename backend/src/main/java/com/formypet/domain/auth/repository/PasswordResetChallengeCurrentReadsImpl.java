package com.formypet.domain.auth.repository;

import com.formypet.domain.auth.entity.PasswordResetChallenge;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;

public class PasswordResetChallengeCurrentReadsImpl implements PasswordResetChallengeCurrentReads {
    private final EntityManager entities;
    private final JdbcTemplate jdbc;

    public PasswordResetChallengeCurrentReadsImpl(EntityManager entities, JdbcTemplate jdbc) {
        this.entities = entities;
        this.jdbc = jdbc;
    }

    public Optional<ChallengeOwner> findOwnerById(String id) { return owner("id", id); }
    public Optional<ChallengeOwner> findOwnerByResetHash(String hash) { return owner("reset_hash", hash); }
    public Optional<PasswordResetChallenge> findCurrentById(String id) { return current("id", id); }
    public Optional<PasswordResetChallenge> findCurrentByResetHash(String hash) { return current("reset_hash", hash); }

    private Optional<ChallengeOwner> owner(String column, String value) {
        // The column comes exclusively from the internal constants above.
        return jdbc.query("SELECT user_id FROM password_reset_challenges WHERE " + column + "=?",
                (rs, row) -> new ChallengeOwner(rs.getObject(1, Long.class)), value).stream().findFirst();
    }

    private Optional<PasswordResetChallenge> current(String column, String value) {
        var rows = entities.createNativeQuery("SELECT * FROM password_reset_challenges WHERE "
                        + column + "=? FOR UPDATE", PasswordResetChallenge.class)
                .setParameter(1, value).getResultList();
        if (rows.isEmpty()) return Optional.empty();
        var challenge = (PasswordResetChallenge) rows.getFirst();
        // Native current reads can still return an entity already held in the persistence context.
        refreshCurrent(challenge);
        return Optional.of(challenge);
    }

    public void refreshCurrent(PasswordResetChallenge challenge) {
        entities.refresh(challenge, LockModeType.PESSIMISTIC_WRITE);
    }
}
