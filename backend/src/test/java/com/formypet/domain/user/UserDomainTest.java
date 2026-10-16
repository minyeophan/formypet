package com.formypet.domain.user;

import com.formypet.domain.user.entity.UserBlock;
import com.formypet.domain.user.entity.UserBlockId;
import com.formypet.domain.user.entity.AccountCleanupRetry;
import java.time.Instant;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class UserDomainTest {
    @Test void blockIdentityPreservesDirectionAndUtcMicroseconds() {
        var at = Instant.parse("2026-10-16T01:02:03.123456789Z");
        var block = UserBlock.create(7L, 9L, at);
        assertThat(block.getId()).isEqualTo(new UserBlockId(7L, 9L));
        assertThat(block.getId()).isNotEqualTo(new UserBlockId(9L, 7L));
        assertThat(block.getId().hashCode()).isEqualTo(new UserBlockId(7L, 9L).hashCode());
        assertThat(block.getCreatedAt()).isEqualTo(LocalDateTime.parse("2026-10-16T01:02:03.123456"));
    }

    @Test void cleanupBackoffKeepsExistingAttemptsAndOneDayCap() {
        assertThat(AccountCleanupRetry.delaySeconds(0)).isEqualTo(30);
        assertThat(AccountCleanupRetry.delaySeconds(1)).isEqualTo(60);
        assertThat(AccountCleanupRetry.delaySeconds(10)).isEqualTo(30720);
        assertThat(AccountCleanupRetry.delaySeconds(11)).isEqualTo(61440);
        // Existing shift exponent is capped at 11 before the one-day cap.
        assertThat(AccountCleanupRetry.delaySeconds(30)).isEqualTo(61440);
        assertThat(AccountCleanupRetry.nextWebhookAttempt(0)).isEqualTo(1);
        assertThat(AccountCleanupRetry.nextWebhookAttempt(29)).isEqualTo(30);
        assertThat(AccountCleanupRetry.nextWebhookAttempt(30)).isEqualTo(30);
    }
}
