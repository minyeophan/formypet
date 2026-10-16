package com.formypet.domain.petlog.entity;

import com.formypet.global.time.UtcTime;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.time.Instant;
import java.time.LocalDateTime;

@Entity
@Table(name = "pet_logs")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PetLog {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "pet_id", nullable = false, updatable = false)
    private Long petId;
    @Column(name = "user_id", nullable = false, updatable = false)
    private Long userId;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "entry_at", nullable = false)
    private LocalDateTime entryAt;
    @Column(length = 2000)
    private String note;
    // The account and current-row locks serialize revisions, including unchanged content.
    @Column(nullable = false)
    private long version;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at", insertable = false)
    private LocalDateTime updatedAt;

    public static PetLog create(Long userId, Long petId, LocalDateTime entryAt, String note) {
        var log = new PetLog();
        log.userId = java.util.Objects.requireNonNull(userId);
        log.petId = java.util.Objects.requireNonNull(petId);
        log.changeContent(entryAt, note);
        return log;
    }

    public void revise(LocalDateTime entryAt, String note, Instant now) {
        changeContent(entryAt, note);
        version++;
        updatedAt = UtcTime.toDatabase(now);
    }

    private void changeContent(LocalDateTime entryAt, String note) {
        if (entryAt == null) throw new IllegalArgumentException("기록 날짜와 시간을 입력해 주세요.");
        if (note != null && note.length() > 2000) throw new IllegalArgumentException("글은 2,000자 이내로 입력해 주세요.");
        this.entryAt = entryAt;
        this.note = note;
    }

    public boolean hasVersion(long expected) { return version == expected; }
}
