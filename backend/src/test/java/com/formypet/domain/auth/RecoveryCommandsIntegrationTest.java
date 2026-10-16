package com.formypet.domain.auth;

import com.formypet.domain.auth.entity.PasswordResetChallenge;
import com.formypet.domain.auth.repository.PasswordResetChallengeRepository;
import com.formypet.domain.auth.repository.jdbc.RecoveryCommands;
import com.formypet.domain.user.entity.User;
import com.formypet.domain.user.repository.UserRepository;
import com.formypet.support.IntegrationTestSupport;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import static org.assertj.core.api.Assertions.assertThat;

@Transactional
class RecoveryCommandsIntegrationTest extends IntegrationTestSupport {
    @Autowired RecoveryCommands commands;
    @Autowired PasswordResetChallengeRepository challenges;
    @Autowired UserRepository users;
    @Autowired JdbcTemplate jdbc;

    @Test void resendInvalidatesOnlyPendingAndMailEligibilityUsesStrictExpiry() {
        var now = Instant.parse("2026-10-16T00:00:00Z");
        var pending = challenge("s".repeat(64), null, now);
        var verified = challenge("s".repeat(64), null, now);
        verified.markVerified("request", "r".repeat(64), now);
        challenges.flush();
        assertThat(commands.isPendingCode(pending.getId(), now.plusSeconds(599))).isTrue();
        assertThat(commands.isPendingCode(pending.getId(), now.plusSeconds(600))).isFalse();
        commands.invalidatePending("s".repeat(64));
        assertThat(commands.isPendingCode(pending.getId(), now)).isFalse();
        assertThat(challenges.findCurrentById(verified.getId()).orElseThrow().getState()).isEqualTo("VERIFIED");
        assertThat(challenges.findCurrentById(pending.getId()).orElseThrow().getState()).isEqualTo("INVALIDATED");
    }

    @Test void passwordChangeRevokesRefreshAndInvalidatesActiveChallengesForOnlyThatUser() {
        var now = Instant.parse("2026-10-16T00:00:00Z");
        var user = users.saveAndFlush(User.create(UUID.randomUUID()+"@example.test", "before", "recovery"));
        var pending = challenge("s".repeat(64), user.getId(), now);
        var verified = challenge("t".repeat(64), user.getId(), now);
        verified.markVerified("request", "r".repeat(64), now);
        var unrelated = challenge("u".repeat(64), null, now);
        challenges.flush();
        jdbc.update("INSERT INTO refresh_tokens(user_id,token,expires_at,created_at) VALUES (?,?,'2030-01-01 00:00:00',UTC_TIMESTAMP(6))", user.getId(), UUID.randomUUID().toString());
        commands.changePasswordAndRevokeSessions(user.getId(), "after", now);
        assertThat(jdbc.queryForObject("SELECT password_hash FROM users WHERE id=?", String.class, user.getId())).isEqualTo("after");
        assertThat(jdbc.queryForObject("SELECT auth_version FROM users WHERE id=?", Long.class, user.getId())).isEqualTo(1L);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM refresh_tokens WHERE user_id=?", Integer.class, user.getId())).isZero();
        assertThat(challenges.findCurrentById(pending.getId()).orElseThrow().getState()).isEqualTo("INVALIDATED");
        assertThat(challenges.findCurrentById(verified.getId()).orElseThrow().getState()).isEqualTo("INVALIDATED");
        assertThat(challenges.findCurrentById(unrelated.getId()).orElseThrow().getState()).isEqualTo("PENDING");
    }

    @Test void cleanupKeepsExactCompletionRetryBoundaryAndLiveResetCapability() {
        var now = Instant.parse("2026-10-16T00:00:00Z");
        var completed = challenge("s".repeat(64), null, now.minusSeconds(3600));
        completed.markCompleted("done", "f".repeat(64), now.minusSeconds(600));
        var verified = challenge("t".repeat(64), null, now.minusSeconds(3600));
        verified.markVerified("request", "r".repeat(64), now);
        challenges.flush();
        commands.cleanup(now);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE id=?", Integer.class, completed.getId())).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE id=?", Integer.class, verified.getId())).isEqualTo(1);
        commands.cleanup(now.plusSeconds(1));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE id=?", Integer.class, completed.getId())).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM password_reset_challenges WHERE id=?", Integer.class, verified.getId())).isEqualTo(1);
    }

    private PasswordResetChallenge challenge(String subject, Long user, Instant now) {
        return challenges.saveAndFlush(PasswordResetChallenge.pending(
                UUID.randomUUID().toString().replace("-", "")+"abcdefghijk", subject, user, "c".repeat(64), now));
    }
}
