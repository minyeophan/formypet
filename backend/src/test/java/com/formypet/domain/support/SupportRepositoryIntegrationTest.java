package com.formypet.domain.support;

import com.formypet.domain.support.entity.SupportMailOutbox;
import com.formypet.domain.support.entity.SupportTicket;
import com.formypet.domain.support.repository.SupportMailOutboxRepository;
import com.formypet.domain.support.repository.SupportTicketRepository;
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
class SupportRepositoryIntegrationTest extends IntegrationTestSupport {
    @Autowired SupportTicketRepository tickets;
    @Autowired SupportMailOutboxRepository outbox;
    @Autowired JdbcTemplate jdbc;
    @Autowired EntityManager entities;

    @Test void jpaReceiptAndOutboxKeepUtcFieldsAndCaseSensitiveRequestIdentity() {
        String email = UUID.randomUUID() + "@test.invalid";
        jdbc.update("INSERT INTO users(email,password_hash,nickname) VALUES (?,'test','test')", email);
        long uid = jdbc.queryForObject("SELECT id FROM users WHERE email=?", Long.class, email);
        var at = Instant.parse("2026-10-16T01:02:03.123456Z");
        var ticket = tickets.saveAndFlush(SupportTicket.received(uid, "INQUIRY", "Case", "a".repeat(64),
                "BUG", "제목", "본문", "reply@example.test", null, null, null, at));
        var pending = outbox.saveAndFlush(SupportMailOutbox.pending(ticket.getId(), ticket.receivedAt()));
        assertThat(jdbc.<LocalDateTime>queryForObject("SELECT created_at FROM support_tickets WHERE id=?",
                (rs, row) -> rs.getObject(1, LocalDateTime.class), ticket.getId()))
                .isEqualTo(LocalDateTime.parse("2026-10-16T01:02:03.123456"));
        entities.clear();
        assertThat(tickets.findByRequesterUserIdAndKindAndRequestId(uid, "INQUIRY", "case")).isEmpty();
        var persisted = tickets.findByRequesterUserIdAndKindAndRequestId(uid, "INQUIRY", "Case").orElseThrow();
        assertThat(persisted.receivedAt()).isEqualTo(at);
        assertThat(persisted.getTargetPostId()).isNull();
        assertThat(persisted.getTargetAuthorId()).isNull();
        assertThat(outbox.findById(pending.getId()).orElseThrow().getNextAttemptAt())
                .isEqualTo(persisted.getCreatedAt());
    }

    @Test void legacyAnonymousReportAndLeasedOutboxLoadWithoutTimeConversionOrRelations() {
        String request = UUID.randomUUID().toString();
        String snapshot = "{\"user_id\":42,\"title\":\"원본\",\"content\":null,\"nickname\":\"작성자\"}";
        jdbc.update("""
                INSERT INTO support_tickets(requester_user_id,kind,request_id,payload_hash,category,title,content,
                  reply_email,target_post_id,target_snapshot,target_author_id,created_at)
                VALUES (NULL,'POST_REPORT',?,?,'SPAM','게시글 신고','',NULL,999,?,NULL,'2026-10-16 01:02:03.123456')
                """, request, "b".repeat(64), snapshot);
        long id = jdbc.queryForObject("SELECT id FROM support_tickets WHERE request_id=?", Long.class, request);
        jdbc.update("""
                INSERT INTO support_mail_outbox(ticket_id,status,attempts,next_attempt_at,lease_until,claim_token,last_error)
                VALUES (?,'PROCESSING',3,'2026-10-16 01:03:04.234567','2026-10-16 01:08:04.345678',?,'TestFailure')
                """, id, UUID.randomUUID().toString());
        long oid = jdbc.queryForObject("SELECT id FROM support_mail_outbox WHERE ticket_id=?", Long.class, id);
        var statistics = entities.getEntityManagerFactory().unwrap(org.hibernate.SessionFactory.class).getStatistics();
        boolean enabled = statistics.isStatisticsEnabled();
        statistics.setStatisticsEnabled(true);
        statistics.clear();
        try {
        var ticket = tickets.findById(id).orElseThrow();
        assertThat(ticket.getRequesterUserId()).isNull();
        assertThat(ticket.getTargetAuthorId()).isNull();
        assertThat(ticket.getTargetSnapshot()).isEqualTo(snapshot);
        assertThat(ticket.receivedAt()).isEqualTo(Instant.parse("2026-10-16T01:02:03.123456Z"));
        var pending = outbox.findById(oid).orElseThrow();
        assertThat(pending.getStatus()).isEqualTo("PROCESSING");
        assertThat(pending.getAttempts()).isEqualTo(3);
        assertThat(pending.getNextAttemptAt()).isEqualTo(LocalDateTime.parse("2026-10-16T01:03:04.234567"));
        assertThat(pending.getLeaseUntil()).isEqualTo(LocalDateTime.parse("2026-10-16T01:08:04.345678"));
        assertThat(pending.getSentAt()).isNull();
        assertThat(pending.getLastError()).isEqualTo("TestFailure");
        assertThat(statistics.getPrepareStatementCount()).isEqualTo(2);
        assertThat(statistics.getEntityLoadCount()).isEqualTo(2);
        assertThat(statistics.getEntityFetchCount()).isZero();
        } finally {
            statistics.setStatisticsEnabled(enabled);
        }
    }
}
