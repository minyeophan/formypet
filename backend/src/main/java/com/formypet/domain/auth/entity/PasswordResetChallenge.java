package com.formypet.domain.auth.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.DynamicUpdate;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

@Entity
@Table(name = "password_reset_challenges")
@DynamicUpdate
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PasswordResetChallenge {
    @Id @Column(columnDefinition = "char(43)")
    private String id;
    @Column(name = "subject_key", nullable = false, columnDefinition = "char(64)")
    private String subjectKey;
    @Column(name = "user_id")
    private Long userId;
    @Column(name = "code_hash", nullable = false, columnDefinition = "char(64)")
    private String codeHash;
    @Column(nullable = false, length = 20)
    private String state;
    @Column(nullable = false)
    private int attempts;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;
    @Column(name = "verify_request_id", length = 64)
    private String verifyRequestId;
    @Column(name = "reset_hash", columnDefinition = "char(64)")
    private String resetHash;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "reset_expires_at")
    private LocalDateTime resetExpiresAt;
    @Column(name = "confirm_request_id", length = 64)
    private String confirmRequestId;
    @Column(name = "confirm_hash", columnDefinition = "char(64)")
    private String confirmHash;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    public static PasswordResetChallenge pending(String id, String subjectKey, Long userId,
                                                  String codeHash, Instant now) {
        var challenge = new PasswordResetChallenge();
        challenge.id = id;
        challenge.subjectKey = subjectKey;
        challenge.userId = userId;
        challenge.codeHash = codeHash;
        challenge.state = "PENDING";
        challenge.createdAt = time(now);
        challenge.expiresAt = time(now.plusSeconds(600));
        return challenge;
    }

    public boolean acceptsVerificationAttempt(Instant now) {
        return "PENDING".equals(state) && attempts < 5 && now.isBefore(expiresAt());
    }

    public void recordFailedAttempt() { attempts++; }

    public void markVerified(String requestId, String hash, Instant now) {
        state = "VERIFIED";
        verifyRequestId = requestId;
        resetHash = hash;
        resetExpiresAt = time(now.plusSeconds(300));
    }

    public boolean allowsVerificationRetry(String requestId, Instant now) {
        return "VERIFIED".equals(state) && requestId.equals(verifyRequestId)
                && now.isBefore(resetExpiresAt());
    }

    public boolean canConfirm(Instant now) {
        return "VERIFIED".equals(state) && userId != null && now.isBefore(resetExpiresAt());
    }

    public void markCompleted(String requestId, String hash, Instant now) {
        state = "COMPLETED";
        confirmRequestId = requestId;
        confirmHash = hash;
        completedAt = time(now);
    }

    public boolean allowsCompletionRetry(String requestId, Instant now) {
        return "COMPLETED".equals(state) && requestId.equals(confirmRequestId)
                && now.isBefore(completedAt().plusSeconds(600));
    }

    public Instant expiresAt() { return instant(expiresAt); }
    public Instant resetExpiresAt() { return instant(resetExpiresAt); }
    public Instant completedAt() { return instant(completedAt); }
    private static Instant instant(LocalDateTime value) {
        return value == null ? null : value.toInstant(ZoneOffset.UTC);
    }
    private static LocalDateTime time(Instant value) {
        return LocalDateTime.ofInstant(value.truncatedTo(ChronoUnit.MICROS), ZoneOffset.UTC);
    }
}
