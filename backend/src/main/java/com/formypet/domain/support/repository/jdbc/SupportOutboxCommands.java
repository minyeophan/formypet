package com.formypet.domain.support.repository.jdbc;

import com.formypet.common.time.UtcTime;
import com.formypet.domain.support.entity.MailRetryPolicy;
import java.time.Instant;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Current reads and fenced updates deliberately avoid persistence-context snapshots. */
@Repository
@RequiredArgsConstructor
public class SupportOutboxCommands {
    private final JdbcTemplate jdbc;
    public record Claim(long id, long ticketId, String token, int attempt) {}
    private record Due(long id, long ticketId, int attempts) {}

    // Caller holds one short transaction across expiration, SKIP LOCKED selection and lease assignment.
    public Claim claim(Instant now) {
        jdbc.update("""
                UPDATE support_mail_outbox SET status='FAILED',lease_until=NULL,claim_token=NULL,last_error='LeaseExpired'
                WHERE status='PROCESSING' AND lease_until<=? AND attempts>=?
                """, UtcTime.toDatabase(now), MailRetryPolicy.MAX_ATTEMPTS);
        var due = jdbc.query("""
                SELECT id,ticket_id,attempts FROM support_mail_outbox
                WHERE attempts<? AND ((status='PENDING' AND next_attempt_at<=?) OR (status='PROCESSING' AND lease_until<=?))
                ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
                """, (rs, row) -> new Due(rs.getLong("id"), rs.getLong("ticket_id"), rs.getInt("attempts")),
                MailRetryPolicy.MAX_ATTEMPTS, UtcTime.toDatabase(now), UtcTime.toDatabase(now));
        if (due.isEmpty()) return null;
        var row = due.getFirst();
        String token = UUID.randomUUID().toString();
        int attempt = row.attempts() + 1;
        jdbc.update("UPDATE support_mail_outbox SET status='PROCESSING',attempts=?,lease_until=?,claim_token=? WHERE id=?",
                attempt, UtcTime.toDatabase(now.plusSeconds(MailRetryPolicy.LEASE_SECONDS)), token, row.id());
        return new Claim(row.id(), row.ticketId(), token, attempt);
    }

    public int sent(Claim claim, Instant now) {
        return jdbc.update("""
                UPDATE support_mail_outbox SET status='SENT',sent_at=?,lease_until=NULL,claim_token=NULL,last_error=NULL
                WHERE id=? AND status='PROCESSING' AND claim_token=?
                """, UtcTime.toDatabase(now), claim.id(), claim.token());
    }

    public int failed(Claim claim, String status, Instant nextAttempt, String errorClass) {
        return jdbc.update("""
                UPDATE support_mail_outbox SET status=?,next_attempt_at=?,lease_until=NULL,claim_token=NULL,last_error=?
                WHERE id=? AND status='PROCESSING' AND claim_token=?
                """, status, UtcTime.toDatabase(nextAttempt), errorClass, claim.id(), claim.token());
    }
}
