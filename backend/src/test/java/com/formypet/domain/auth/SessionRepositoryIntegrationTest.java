package com.formypet.domain.auth;

import com.formypet.domain.auth.repository.jdbc.SessionSnapshotRepository;
import com.formypet.domain.auth.repository.jdbc.RefreshTokenCurrentReadRepository;
import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class SessionRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired SessionSnapshotRepository sessions;
    @Autowired RefreshTokenCurrentReadRepository refresh;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    @Test void snapshotReadsCurrentVersionWithoutReusingManagedUser() {
        var user = users.saveAndFlush(User.create(UUID.randomUUID() + "@example.test", "before", "session"));
        jdbc.update("UPDATE users SET password_hash='after',auth_version=4 WHERE id=?", user.getId());
        assertThat(user.getAuthVersion()).isZero();
        var current = sessions.lockById(user.getId()).orElseThrow();
        assertThat(current.version()).isEqualTo(4);
        assertThat(current.passwordHash()).isEqualTo("after");
        assertThat(current.source()).isEqualTo("LOCAL");
        assertThat(sessions.findByEmail(user.getEmail()).orElseThrow()).isEqualTo(current);
        assertThat(sessions.lockByEmail(user.getEmail()).orElseThrow()).isEqualTo(current);
    }

    @Test void inactiveAndMissingUsersNeverProduceAnAuthenticationSnapshot() {
        var user = users.saveAndFlush(User.create(UUID.randomUUID() + "@example.test", "hash", "session"));
        jdbc.update("UPDATE users SET account_status='DELETION_PENDING' WHERE id=?", user.getId());
        assertThat(sessions.findById(user.getId())).isEmpty();
        assertThat(sessions.findByEmail(user.getEmail())).isEmpty();
        assertThat(sessions.lockById(user.getId())).isEmpty();
        assertThat(sessions.lockByEmail(user.getEmail())).isEmpty();
        assertThat(sessions.findById(-1L)).isEmpty();
    }

    @Test void refreshCurrentReadRequiresMatchingOwnerAndSurvivingToken() {
        var user = users.saveAndFlush(User.create(UUID.randomUUID() + "@example.test", "hash", "session"));
        String token = UUID.randomUUID().toString();
        jdbc.update("INSERT INTO refresh_tokens(user_id,token,expires_at,created_at) VALUES (?,?,DATE_ADD(UTC_TIMESTAMP(6),INTERVAL 1 DAY),UTC_TIMESTAMP(6))", user.getId(), token);
        assertThat(refresh.findOwner(token)).contains(user.getId());
        assertThat(refresh.lockExists(token, user.getId())).isTrue();
        assertThat(refresh.lockExists(token, -1L)).isFalse();
        jdbc.update("DELETE FROM refresh_tokens WHERE token=?", token);
        assertThat(refresh.lockExists(token, user.getId())).isFalse();
        assertThat(refresh.findOwner(token)).isEmpty();
    }
}
