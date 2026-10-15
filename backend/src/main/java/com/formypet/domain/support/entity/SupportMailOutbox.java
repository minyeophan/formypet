package com.formypet.domain.support.entity;

import com.formypet.common.time.UtcTime;
import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

/** Initial persistence uses JPA; leased worker transitions use fenced repository commands. */
@Entity
@Table(name = "support_mail_outbox")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SupportMailOutbox {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "ticket_id", nullable = false, unique = true)
    private Long ticketId;
    @Column(nullable = false, length = 20)
    private String status;
    @Column(nullable = false)
    private int attempts;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "next_attempt_at", nullable = false)
    private LocalDateTime nextAttemptAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "lease_until")
    private LocalDateTime leaseUntil;
    @Column(name = "claim_token", length = 36, columnDefinition = "char(36)")
    private String claimToken;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "sent_at")
    private LocalDateTime sentAt;
    @Column(name = "last_error", length = 100)
    private String lastError;

    public static SupportMailOutbox pending(long ticketId, Instant at) {
        var outbox = new SupportMailOutbox();
        outbox.ticketId = ticketId;
        outbox.status = "PENDING";
        outbox.nextAttemptAt = UtcTime.toDatabase(at);
        return outbox;
    }
}
