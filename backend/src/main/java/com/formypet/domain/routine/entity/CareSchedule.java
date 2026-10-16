package com.formypet.domain.routine.entity;

import com.formypet.global.exception.InvalidInputException;
import com.formypet.global.time.UtcTime;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.type.descriptor.jdbc.LocalTimeJdbcType;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.time.*;

@Entity
@Table(name = "care_schedules")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CareSchedule {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "pet_id", nullable = false)
    private Long petId;
    @Column(name = "category_id", nullable = false, length = 40)
    private String categoryId;
    @Column(nullable = false, length = 100)
    private String title;
    @Column(name = "start_date", nullable = false)
    private LocalDate startDate;
    @JdbcType(LocalTimeJdbcType.class)
    @Column(name = "start_time")
    private LocalTime startTime;
    @Column(name = "end_date", nullable = false)
    private LocalDate endDate;
    @JdbcType(LocalTimeJdbcType.class)
    @Column(name = "end_time")
    private LocalTime endTime;
    @Column(name = "all_day", nullable = false)
    private boolean allDay;
    @Column(length = 200)
    private String place;
    @Column(length = 500)
    private String memo;
    @Column(nullable = false, length = 100)
    private String reminder;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", insertable = false, updatable = false)
    private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at", insertable = false)
    private LocalDateTime updatedAt;

    public static CareSchedule create(Long petId, String categoryId, String title, LocalDate startDate,
                                      LocalTime startTime, LocalDate endDate, LocalTime endTime, boolean allDay,
                                      String place, String memo, String reminder) {
        var schedule = new CareSchedule();
        schedule.petId = petId;
        schedule.update(categoryId, title, startDate, startTime, endDate, endTime, allDay, place, memo, reminder);
        return schedule;
    }

    public void update(String categoryId, String title, LocalDate startDate, LocalTime startTime,
                       LocalDate endDate, LocalTime endTime, boolean allDay, String place, String memo,
                       String reminder) {
        String normalizedTitle = requiredText(title);
        if (normalizedTitle.length() > 100) throw InvalidInputException.invalidInput();
        if (endDate.isBefore(startDate))
            throw new InvalidInputException("Invalid date range.", "INVALID_DATE_RANGE");
        this.categoryId = requiredText(categoryId);
        this.title = normalizedTitle;
        this.reminder = requiredText(reminder);
        this.startDate = startDate;
        this.endDate = endDate;
        this.allDay = allDay;
        this.startTime = allDay ? null : startTime;
        this.endTime = allDay ? null : endTime;
        this.place = optionalText(place);
        this.memo = optionalText(memo);
        this.updatedAt = UtcTime.toDatabase(Instant.now());
    }

    private static String requiredText(String value) {
        if (value == null || value.trim().isEmpty()) throw InvalidInputException.invalidInput();
        return value.trim();
    }

    private static String optionalText(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
