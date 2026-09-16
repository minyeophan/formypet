package com.formypet.support;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.sql.Timestamp;
import java.util.Map;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class SupportMailWorker {
    private static final int MAX_ATTEMPTS = 5;
    private static final int[] RETRY_MINUTES = {1, 5, 30, 120};
    private final JdbcTemplate jdbc;
    private final TransactionTemplate transactions;
    private final SupportMailTransport transport;

    record Claim(long id, long ticketId, String token, int attempt) {}

    public boolean processOne() {
        Claim claim = transactions.execute(status -> claim());
        if (claim == null) return false;
        try {
            var ticket = jdbc.queryForMap("SELECT * FROM support_tickets WHERE id=?", claim.ticketId());
            boolean inquiry = "INQUIRY".equals(ticket.get("kind"));
            String kind = inquiry ? "문의" : "신고";
            String subject = "[포마펫][" + kind + " #" + claim.ticketId() + "] " + ticket.get("title");
            String body = "접수번호: " + claim.ticketId() + "\n접수시각(한국시간): " + displayTime(ticket.get("created_at"))
                    + "\n유형/사유: " + displayCategory((String) ticket.get("category"), inquiry)
                    + "\n제목: " + ticket.get("title")
                    + "\n내용:\n" + ticket.get("content")
                    + (inquiry ? "\n답변 이메일: " + ticket.get("reply_email")
                    : "\n대상 게시글: " + ticket.get("target_post_id") + "\n접수 당시 내용:\n" + ticket.get("target_snapshot"));
            transport.send(subject, body, inquiry ? (String) ticket.get("reply_email") : null);
            jdbc.update("""
                    UPDATE support_mail_outbox SET status='SENT',sent_at=?,lease_until=NULL,claim_token=NULL,last_error=NULL
                    WHERE id=? AND status='PROCESSING' AND claim_token=?
                    """, now(), claim.id(), claim.token());
        } catch (Exception failure) {
            boolean exhausted = claim.attempt() >= MAX_ATTEMPTS;
            LocalDateTime next = now().plusMinutes(exhausted ? 0 : RETRY_MINUTES[claim.attempt() - 1]);
            jdbc.update("""
                    UPDATE support_mail_outbox SET status=?,next_attempt_at=?,lease_until=NULL,claim_token=NULL,last_error=?
                    WHERE id=? AND status='PROCESSING' AND claim_token=?
                    """, exhausted ? "FAILED" : "PENDING", next, failure.getClass().getSimpleName(), claim.id(), claim.token());
            // SMTP exception messages can contain addresses and authentication diagnostics.
            log.warn("Support mail ticket={} attempt={} status={}", claim.ticketId(), claim.attempt(), exhausted ? "FAILED" : "PENDING");
        }
        return true;
    }

    private Claim claim() {
        LocalDateTime now = now();
        jdbc.update("""
                UPDATE support_mail_outbox SET status='FAILED',lease_until=NULL,claim_token=NULL,last_error='LeaseExpired'
                WHERE status='PROCESSING' AND lease_until<=? AND attempts>=?
                """, now, MAX_ATTEMPTS);
        var due = jdbc.queryForList("""
                SELECT id,ticket_id,attempts FROM support_mail_outbox
                WHERE attempts<? AND ((status='PENDING' AND next_attempt_at<=?) OR (status='PROCESSING' AND lease_until<=?))
                ORDER BY id LIMIT 1 FOR UPDATE SKIP LOCKED
                """, MAX_ATTEMPTS, now, now);
        if (due.isEmpty()) return null;
        var row = due.getFirst();
        long id = ((Number) row.get("id")).longValue();
        String token = UUID.randomUUID().toString();
        int attempt = ((Number) row.get("attempts")).intValue() + 1;
        jdbc.update("UPDATE support_mail_outbox SET status='PROCESSING',attempts=?,lease_until=?,claim_token=? WHERE id=?",
                attempt, now.plusMinutes(5), token, id);
        return new Claim(id, ((Number) row.get("ticket_id")).longValue(), token, attempt);
    }

    private static LocalDateTime now() { return LocalDateTime.now(ZoneOffset.UTC); }

    private static String displayCategory(String code, boolean inquiry) {
        Map<String, String> labels = inquiry ? Map.of(
                "ACCOUNT", "계정/로그인", "RECORD_ROUTINE", "기록/루틴", "COMMUNITY", "커뮤니티",
                "BUG", "오류 신고", "OTHER", "기타") : Map.of(
                "SPAM", "스팸/광고", "ABUSE", "욕설/비방", "INAPPROPRIATE", "부적절한 내용",
                "PRIVACY", "개인정보 침해", "OTHER", "기타");
        return labels.getOrDefault(code, code);
    }

    private static String displayTime(Object value) {
        LocalDateTime utc = value instanceof Timestamp timestamp
                ? timestamp.toLocalDateTime()
                : (LocalDateTime) value;
        return utc.atOffset(ZoneOffset.UTC).atZoneSameInstant(ZoneId.of("Asia/Seoul"))
                .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
    }
}
