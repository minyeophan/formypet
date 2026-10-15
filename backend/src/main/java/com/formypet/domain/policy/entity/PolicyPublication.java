package com.formypet.domain.policy.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.Immutable;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

@Entity
@Table(name = "policy_publications")
@Immutable
@Getter
@AllArgsConstructor
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PolicyPublication {
    @EmbeddedId private PolicyPublicationId id;
    @Column(nullable = false, length = 255, updatable = false)
    private String title;
    @Column(nullable = false, columnDefinition = "MEDIUMTEXT", updatable = false)
    private String body;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "published_at", nullable = false, updatable = false)
    private LocalDateTime publishedAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "effective_at", nullable = false, updatable = false)
    private LocalDateTime effectiveAt;
    @Column(name = "acceptance_revision", length = 64, updatable = false)
    private String acceptanceRevision;
    @Column(name = "content_hash", nullable = false, columnDefinition = "CHAR(64)", updatable = false)
    private String contentHash;

    public void requireSameContent(String hash) {
        if (!contentHash.equals(hash)) {
            throw new IllegalStateException("A published policy version cannot be overwritten");
        }
    }
}
