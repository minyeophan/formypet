package com.formypet.domain.routine.entity;

import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Set;

/** Completion writes use the repository's atomic unique-key operations. */
@Entity
@Table(name = "routine_completions")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RoutineCompletion {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY) private Long id;
    @Column(name = "routine_id", nullable = false) private Long routineId;
    @Column(name = "pet_id", nullable = false) private Long petId;
    @Column(name = "activity_record_id") private Long activityRecordId;
    @Column(name = "scheduled_date", nullable = false) private LocalDate scheduledDate;
    @Column(nullable = false, columnDefinition = "enum('PENDING','COMPLETED','SKIPPED')") private String status;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "completed_at") private LocalDateTime completedAt;

    public static String normalizeStatus(String value) {
        String status = value.toUpperCase(Locale.ROOT);
        if (!Set.of("PENDING", "COMPLETED", "SKIPPED").contains(status))
            throw new IllegalArgumentException("Unsupported routine completion status.");
        return status;
    }
}
