package com.formypet.domain.record.entity;

import com.formypet.global.exception.InvalidInputException;
import com.formypet.global.time.UtcTime;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import org.hibernate.type.descriptor.jdbc.LocalTimeJdbcType;
import java.time.*;
import java.util.Set;

@Entity
@Table(name = "activity_records")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ActivityRecord {
    private static final Set<String> SUPPORTED_TYPES = Set.of(
            "meal", "water", "medicine", "poop", "walk", "weight", "vet", "diary", "etc");

    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "pet_id", nullable = false)
    private Long petId;
    @Column(name = "type_id", nullable = false, length = 30)
    private String typeId;
    @Column(nullable = false)
    private LocalDate date;
    @JdbcType(LocalTimeJdbcType.class)
    private LocalTime time;
    @Column(name = "routine_id")
    private Long routineId;
    @Column(columnDefinition = "TEXT")
    private String note;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    public static ActivityRecord create(Long petId, String typeId, LocalDate date, LocalTime time,
                                        Long routineId, String note) {
        validateType(typeId);
        var record = new ActivityRecord();
        record.petId = petId;
        record.typeId = typeId;
        record.date = date;
        record.time = time;
        record.routineId = routineId;
        record.note = note;
        record.createdAt = UtcTime.toDatabase(Instant.now());
        record.updatedAt = record.createdAt;
        return record;
    }

    public void update(LocalDate date, LocalTime time, Long routineId, String note) {
        if (date != null) this.date = date;
        if (time != null) this.time = time;
        if (routineId != null) this.routineId = routineId;
        if (note != null) this.note = note;
        this.updatedAt = UtcTime.toDatabase(Instant.now());
    }

    public static void validateType(String typeId) {
        if (!SUPPORTED_TYPES.contains(typeId)) {
            throw new InvalidInputException("Unsupported activity record type.", "INVALID_INPUT");
        }
    }
}
