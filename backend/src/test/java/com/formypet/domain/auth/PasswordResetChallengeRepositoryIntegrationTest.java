package com.formypet.domain.auth;

import com.formypet.domain.auth.entity.PasswordResetChallenge;
import com.formypet.domain.auth.repository.PasswordResetChallengeRepository;
import com.formypet.support.IntegrationTestSupport;
import jakarta.persistence.EntityManager;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class PasswordResetChallengeRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired PasswordResetChallengeRepository challenges;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    @Test void jpaWritesUtcMicrosecondsAndTransitionsPersistWithoutChangingCreation() {
        String id = id();
        Instant at = Instant.parse("2026-10-16T02:03:04.123456789Z");
        var challenge = challenges.saveAndFlush(PasswordResetChallenge.pending(id, "s".repeat(64), null, "c".repeat(64), at));
        assertThat(jdbc.<LocalDateTime>queryForObject("SELECT created_at FROM password_reset_challenges WHERE id=?",
                (rs, row) -> rs.getObject(1, LocalDateTime.class), id))
                .isEqualTo(LocalDateTime.parse("2026-10-16T02:03:04.123456"));
        assertThat(challenge.expiresAt()).isEqualTo(Instant.parse("2026-10-16T02:13:04.123456Z"));
        challenge.recordFailedAttempt();
        challenge.markVerified("verify-operation", "r".repeat(64), at.plusSeconds(10));
        challenges.flush();
        entities.clear();
        var loaded = challenges.findById(id).orElseThrow();
        assertThat(loaded.getAttempts()).isEqualTo(1);
        assertThat(loaded.getState()).isEqualTo("VERIFIED");
        assertThat(loaded.resetExpiresAt()).isEqualTo(Instant.parse("2026-10-16T02:08:14.123456Z"));
        loaded.markCompleted("confirm-operation", "f".repeat(64), at.plusSeconds(20));
        challenges.flush();
        entities.clear();
        loaded = challenges.findById(id).orElseThrow();
        assertThat(loaded.getState()).isEqualTo("COMPLETED");
        assertThat(loaded.getConfirmRequestId()).isEqualTo("confirm-operation");
        assertThat(loaded.completedAt()).isEqualTo(Instant.parse("2026-10-16T02:03:24.123456Z"));
    }

    @Test void currentReadsRefreshCachedStateAndDistinguishMissingFromUnknownAccount() {
        String id = id();
        var cached = challenges.saveAndFlush(PasswordResetChallenge.pending(id, "s".repeat(64), null, "c".repeat(64), Instant.now()));
        assertThat(challenges.findOwnerById(id).orElseThrow().userId()).isNull();
        assertThat(challenges.findOwnerById(id())).isEmpty();
        jdbc.update("UPDATE password_reset_challenges SET attempts=4,state='VERIFIED',reset_hash=?,reset_expires_at='2030-01-01 00:00:00' WHERE id=?", "r".repeat(64), id);
        assertThat(cached.getState()).isEqualTo("PENDING");
        var current = challenges.findCurrentById(id).orElseThrow();
        assertThat(current.getState()).isEqualTo("VERIFIED");
        assertThat(current.getAttempts()).isEqualTo(4);
        assertThat(challenges.findOwnerByResetHash("r".repeat(64)).orElseThrow().userId()).isNull();
        assertThat(challenges.findCurrentByResetHash("r".repeat(64)).orElseThrow().getId()).isEqualTo(id);
        jdbc.update("UPDATE password_reset_challenges SET state='INVALIDATED' WHERE id=?", id);
        challenges.refreshCurrent(current);
        assertThat(current.getState()).isEqualTo("INVALIDATED");
        current.markCompleted("confirm-operation", "f".repeat(64), Instant.now());
        challenges.flush();
        assertThat(jdbc.queryForObject("SELECT state FROM password_reset_challenges WHERE id=?", String.class, id)).isEqualTo("COMPLETED");
        assertThat(challenges.findCurrentByResetHash("x".repeat(64))).isEmpty();
    }

    private String id() { return UUID.randomUUID().toString().replace("-", "") + "abcdefghijk"; }
}
