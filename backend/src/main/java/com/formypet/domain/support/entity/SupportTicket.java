package com.formypet.domain.support.entity;

import com.formypet.global.time.UtcTime;
import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

@Entity
@Table(name = "support_tickets")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportTicket {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "requester_user_id")
    private Long requesterUserId;
    @Column(nullable = false, length = 20)
    private String kind;
    @Column(name = "request_id", nullable = false, length = 64)
    private String requestId;
    @Column(name = "payload_hash", nullable = false, length = 64, columnDefinition = "char(64)")
    private String payloadHash;
    @Column(nullable = false, length = 30)
    private String category;
    @Column(nullable = false, length = 100)
    private String title;
    @Column(nullable = false, columnDefinition = "text")
    private String content;
    @Column(name = "reply_email", length = 254)
    private String replyEmail;
    @Column(name = "target_post_id")
    private Long targetPostId;
    @Column(name = "target_snapshot", columnDefinition = "mediumtext")
    private String targetSnapshot;
    @Column(name = "target_author_id")
    private Long targetAuthorId;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static SupportTicket received(long requester, String kind, String requestId, String hash,
            String category, String title, String content, String replyEmail, Long postId,
            String snapshot, Long authorId, Instant at) {
        var ticket = new SupportTicket();
        ticket.requesterUserId = requester;
        ticket.kind = kind;
        ticket.requestId = requestId;
        ticket.payloadHash = hash;
        ticket.category = category;
        ticket.title = title;
        ticket.content = content;
        ticket.replyEmail = replyEmail;
        ticket.targetPostId = postId;
        ticket.targetSnapshot = snapshot;
        ticket.targetAuthorId = authorId;
        ticket.createdAt = UtcTime.toDatabase(at.truncatedTo(ChronoUnit.MICROS));
        return ticket;
    }

    public boolean matchesPayload(String hash) { return payloadHash.equals(hash); }
    public Instant receivedAt() { return UtcTime.fromDatabase(createdAt); }
}
