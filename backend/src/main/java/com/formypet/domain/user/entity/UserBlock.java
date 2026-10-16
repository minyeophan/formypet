package com.formypet.domain.user.entity;

import com.formypet.global.time.UtcTime;
import jakarta.persistence.Column;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;

@Entity
@Table(name = "user_blocks")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserBlock {
    @EmbeddedId
    private UserBlockId id;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    public static UserBlock create(Long blocker, Long blocked, Instant at) {
        var block = new UserBlock();
        block.id = new UserBlockId(blocker, blocked);
        block.createdAt = UtcTime.toDatabase(at.truncatedTo(ChronoUnit.MICROS));
        return block;
    }
}
