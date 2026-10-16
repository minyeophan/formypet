package com.formypet.domain.policy.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

/** An append-only action. Its timestamp is assigned by the database. */
@Entity
@Table(name = "policy_consents")
@Immutable
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PolicyConsent {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "user_id", nullable = false, updatable = false)
    private long userId;
    @Column(name = "document_type", nullable = false, length = 32, updatable = false)
    private String documentType;
    @Column(name = "document_version", nullable = false, length = 64, updatable = false)
    private String documentVersion;
    @Column(name = "acceptance_revision", length = 64, updatable = false)
    private String acceptanceRevision;
    @Column(nullable = false, length = 32, updatable = false)
    private String action;
    @Column(name = "document_hash", nullable = false, columnDefinition = "CHAR(64)", updatable = false)
    private String documentHash;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "recorded_at", nullable = false, insertable = false, updatable = false)
    private LocalDateTime recordedAt;
}
