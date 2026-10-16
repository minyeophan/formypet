package com.formypet.domain.support;

import com.formypet.domain.support.entity.MailRetryPolicy;
import com.formypet.domain.support.entity.SupportMailOutbox;
import com.formypet.domain.support.entity.SupportTicket;
import java.time.Instant;
import java.time.LocalDateTime;
import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class SupportTicketTest {
    @Test void receiptKeepsItsPayloadIdentityAndUtcMicroseconds() {
        var at = Instant.parse("2026-10-16T01:02:03.123456789Z");
        var ticket = SupportTicket.received(1L, "POST_REPORT", "Case-sensitive", "hash", "SPAM",
                "게시글 신고", "내용", null, 2L, "{\"user_id\":3}", 3L, at);
        assertThat(ticket.getCreatedAt()).isEqualTo(LocalDateTime.parse("2026-10-16T01:02:03.123456"));
        assertThat(ticket.receivedAt()).isEqualTo(Instant.parse("2026-10-16T01:02:03.123456Z"));
        assertThat(ticket.matchesPayload("hash")).isTrue();
        assertThat(ticket.matchesPayload("other")).isFalse();
        assertThat(ticket.getRequestId()).isEqualTo("Case-sensitive");
        assertThat(ticket.getTargetSnapshot()).isEqualTo("{\"user_id\":3}");
        assertThat(ticket.getTargetAuthorId()).isEqualTo(3L);
        assertThat(ticket.getReplyEmail()).isNull();
    }

    @Test void newOutboxIsPendingAtTheSameReceiptTimeWithoutALease() {
        var at = Instant.parse("2026-10-16T01:02:03.123456Z");
        var outbox = SupportMailOutbox.pending(7L, at);
        assertThat(outbox.getTicketId()).isEqualTo(7L);
        assertThat(outbox.getStatus()).isEqualTo("PENDING");
        assertThat(outbox.getAttempts()).isZero();
        assertThat(outbox.getNextAttemptAt()).isEqualTo(LocalDateTime.parse("2026-10-16T01:02:03.123456"));
        assertThat(outbox.getLeaseUntil()).isNull();
        assertThat(outbox.getClaimToken()).isNull();
        assertThat(outbox.getSentAt()).isNull();
        assertThat(outbox.getLastError()).isNull();
    }

    @Test void retryRulesKeepFiveAttemptsAndTheExistingBackoff() {
        var now = Instant.parse("2026-10-16T01:02:03Z");
        int[] seconds = {60, 300, 1800, 7200, 0};
        for (int attempt = 1; attempt <= 5; attempt++) {
            assertThat(MailRetryPolicy.nextAttempt(now, attempt)).isEqualTo(now.plusSeconds(seconds[attempt - 1]));
            assertThat(MailRetryPolicy.exhausted(attempt)).isEqualTo(attempt == 5);
        }
        assertThat(MailRetryPolicy.MAX_ATTEMPTS).isEqualTo(5);
        assertThat(MailRetryPolicy.LEASE_SECONDS).isEqualTo(300);
    }
}
