package com.formypet.domain.auth;

import com.formypet.domain.auth.entity.PasswordResetChallenge;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class PasswordResetChallengeTest {
    @Test void attemptAndCapabilityWindowsHaveStrictExpiryBoundaries() {
        var at = Instant.parse("2026-10-16T00:00:00Z");
        var challenge = PasswordResetChallenge.pending("i".repeat(43), "s".repeat(64), 12L, "c".repeat(64), at);
        assertThat(challenge.acceptsVerificationAttempt(at.plusSeconds(599))).isTrue();
        assertThat(challenge.acceptsVerificationAttempt(at.plusSeconds(600))).isFalse();
        for (int i = 0; i < 5; i++) challenge.recordFailedAttempt();
        assertThat(challenge.acceptsVerificationAttempt(at)).isFalse();
        var verified = PasswordResetChallenge.pending("j".repeat(43), "s".repeat(64), 12L, "c".repeat(64), at);
        verified.markVerified("verify-request", "r".repeat(64), at);
        assertThat(verified.allowsVerificationRetry("verify-request", at.plusSeconds(299))).isTrue();
        assertThat(verified.allowsVerificationRetry("other-request", at)).isFalse();
        assertThat(verified.allowsVerificationRetry("verify-request", at.plusSeconds(300))).isFalse();
        assertThat(verified.canConfirm(at.plusSeconds(299))).isTrue();
        assertThat(verified.canConfirm(at.plusSeconds(300))).isFalse();
        verified.markCompleted("confirm-request", "f".repeat(64), at);
        assertThat(verified.allowsCompletionRetry("confirm-request", at.plusSeconds(599))).isTrue();
        assertThat(verified.allowsCompletionRetry("other-request", at)).isFalse();
        assertThat(verified.allowsCompletionRetry("confirm-request", at.plusSeconds(600))).isFalse();
        assertThat(verified.canConfirm(at)).isFalse();
    }
}
