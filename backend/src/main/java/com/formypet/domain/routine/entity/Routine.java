package com.formypet.domain.routine.entity;

import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.time.UtcTime;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcType;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;
import org.hibernate.type.descriptor.jdbc.LocalDateTimeJdbcType;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.regex.Pattern;

@Entity
@Table(name = "routines")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Routine {
    private static final Set<String> REPEATS = Set.of("daily", "weekly", "biweekly", "monthly");
    private static final Set<String> LOCATION_KEYS = Set.of("startLng", "startLat", "endLng", "endLat", "clinicLng", "clinicLat");
    private static final Pattern TIME = Pattern.compile("([01]\\d|2[0-3]):[0-5]\\d");
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @Column(name = "pet_id", nullable = false) private Long petId;
    @Column(nullable = false, length = 100) private String label;
    @Column(name = "type_id", nullable = false, length = 30) private String typeId;
    @Column(name = "repeat_type", nullable = false, columnDefinition = "enum('daily','weekly','biweekly','monthly')")
    private String repeatType;
    @JdbcTypeCode(SqlTypes.JSON) private List<Integer> days;
    @Column(name = "monthly_interval", nullable = false) private int monthlyInterval;
    @Column(name = "start_date", nullable = false) private LocalDate startDate;
    @Column(name = "end_date") private LocalDate endDate;
    @JdbcTypeCode(SqlTypes.JSON) private List<String> times;
    @Column(columnDefinition = "text") private String note;
    @JdbcTypeCode(SqlTypes.JSON) private Map<String, Object> detail;
    @Column(name = "is_active", nullable = false) private boolean active;
    @Column(name = "notification_enabled", nullable = false) private boolean notificationEnabled;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "created_at", nullable = false, updatable = false) private LocalDateTime createdAt;
    @JdbcType(LocalDateTimeJdbcType.class)
    @Column(name = "updated_at", nullable = false) private LocalDateTime updatedAt;

    public static Routine create(Long petId, String label, String typeId, String repeatType, List<Integer> days,
                                 Integer monthlyInterval, LocalDate startDate, LocalDate endDate, List<String> times,
                                 String note, Map<String, Object> detail, Boolean notificationEnabled) {
        validate(label, repeatType, days, monthlyInterval, startDate, endDate, times);
        var routine = new Routine();
        routine.petId = petId;
        routine.label = label;
        routine.typeId = typeId;
        routine.repeatType = repeatType;
        routine.days = copyList(days);
        routine.monthlyInterval = monthlyInterval == null || monthlyInterval < 1 ? 1 : monthlyInterval;
        routine.startDate = startDate;
        routine.endDate = endDate;
        routine.times = copyList(times);
        routine.note = note;
        routine.detail = detail == null ? Map.of() : sanitizeDetail(detail);
        routine.active = true;
        routine.notificationEnabled = Boolean.TRUE.equals(notificationEnabled);
        routine.createdAt = UtcTime.toDatabase(Instant.now());
        routine.updatedAt = routine.createdAt;
        return routine;
    }

    public void update(String label, String typeId, String repeatType, List<Integer> days,
                       Integer monthlyInterval, LocalDate startDate, LocalDate endDate, List<String> times,
                       String note, Map<String, Object> detail, Boolean active, Boolean notificationEnabled,
                       Boolean clearEndDate) {
        String nextLabel = label != null ? label : this.label;
        String nextRepeat = repeatType != null ? repeatType : this.repeatType;
        List<Integer> nextDays = days != null ? days : getDays();
        int nextInterval = monthlyInterval != null ? monthlyInterval : this.monthlyInterval;
        LocalDate nextStart = startDate != null ? startDate : this.startDate;
        LocalDate nextEnd = Boolean.TRUE.equals(clearEndDate) ? null : endDate != null ? endDate : this.endDate;
        List<String> nextTimes = times != null ? times : getTimes();
        validate(nextLabel, nextRepeat, nextDays, nextInterval, nextStart, nextEnd, nextTimes);
        this.label = nextLabel;
        if (typeId != null) this.typeId = typeId;
        this.repeatType = nextRepeat;
        this.days = copyList(nextDays);
        this.monthlyInterval = nextInterval;
        this.startDate = nextStart;
        this.endDate = nextEnd;
        this.times = copyList(nextTimes);
        if (note != null) this.note = note;
        if (detail != null) this.detail = sanitizeDetail(detail);
        if (active != null) this.active = active;
        if (notificationEnabled != null) this.notificationEnabled = notificationEnabled;
        this.updatedAt = UtcTime.toDatabase(Instant.now());
    }

    public boolean isScheduledOn(LocalDate date) {
        if (!active || date.isBefore(startDate) || endDate != null && date.isAfter(endDate)) return false;
        int day = date.getDayOfWeek() == DayOfWeek.SUNDAY ? 0 : date.getDayOfWeek().getValue();
        return switch (repeatType) {
            case "daily" -> true;
            case "weekly" -> getDays().contains(day);
            case "biweekly" -> getDays().contains(day) && ChronoUnit.WEEKS.between(startDate, date) % 2 == 0;
            case "monthly" -> startDate.getDayOfMonth() == date.getDayOfMonth()
                    && ChronoUnit.MONTHS.between(startDate.withDayOfMonth(1), date.withDayOfMonth(1)) % monthlyInterval == 0;
            default -> false;
        };
    }

    public List<Integer> getDays() { return copyList(days); }
    public List<String> getTimes() { return copyList(times); }
    public Map<String, Object> getDetail() { return detail == null ? Map.of() : sanitizeDetail(detail); }

    public static void validateLabel(String label) {
        if (label == null || label.isBlank() || label.codePointCount(0, label.length()) > 30)
            throw InvalidInputException.invalidInput();
    }

    private static void validate(String label, String repeat, List<Integer> days, Integer interval,
                                 LocalDate start, LocalDate end, List<String> times) {
        validateLabel(label);
        if (!REPEATS.contains(repeat)) throw new IllegalArgumentException("Unsupported routine repeat type.");
        if (start == null || end != null && end.isBefore(start)) throw InvalidInputException.invalidInput();
        if ("weekly".equals(repeat) || "biweekly".equals(repeat)) {
            if (days == null || days.isEmpty()) throw InvalidInputException.invalidInput();
            for (Integer day : days) if (day == null || day < 0 || day > 6) throw InvalidInputException.invalidInput();
        }
        if ("monthly".equals(repeat) && interval != null && interval < 1) throw InvalidInputException.invalidInput();
        if (times != null) for (String time : times)
            if (time == null || !TIME.matcher(time).matches()) throw InvalidInputException.invalidInput();
    }

    private static <T> List<T> copyList(List<T> values) { return values == null ? List.of() : new ArrayList<>(values); }
    private static Map<String, Object> sanitizeDetail(Map<String, Object> values) {
        var result = new LinkedHashMap<>(values);
        LOCATION_KEYS.forEach(result::remove);
        return result;
    }
}
