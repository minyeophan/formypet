package com.formypet.routine;

import com.formypet.common.exception.ForbiddenException;
import com.formypet.common.exception.InvalidInputException;
import com.formypet.common.exception.NotFoundException;
import com.formypet.routine.dto.CareScheduleRequest;
import com.formypet.routine.dto.CareScheduleResponse;
import com.formypet.notification.NotificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Time;
import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Objects;

@Service
@RequiredArgsConstructor
public class CareScheduleService {

    private static final DateTimeFormatter TIME_FORMATTER = DateTimeFormatter.ofPattern("HH:mm");

    private final JdbcTemplate jdbcTemplate;
    private final NotificationService notificationService;

    @Transactional
    public CareScheduleResponse create(String email, Long petId, CareScheduleRequest request) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        ValidatedRequest validated = validate(request);
        KeyHolder keyHolder = new GeneratedKeyHolder();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO care_schedules
                        (pet_id, category_id, title, start_date, start_time, end_date, end_time,
                         all_day, place, memo, reminder)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            bindRequest(ps, pet.id(), validated);
            return ps;
        }, keyHolder);
        Long scheduleId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        return findResponse(pet.id(), scheduleId);
    }

    @Transactional(readOnly = true)
    public List<CareScheduleResponse> list(String email, Long petId) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        return jdbcTemplate.query("""
                SELECT id, pet_id, category_id, title, start_date, start_time, end_date, end_time,
                       all_day, place, memo, reminder, created_at
                FROM care_schedules
                WHERE pet_id = ?
                ORDER BY start_date ASC, start_time IS NULL ASC, start_time ASC, id ASC
                """, (rs, rowNum) -> CareScheduleResponse.of(
                rs.getLong("id"),
                rs.getLong("pet_id"),
                rs.getString("category_id"),
                rs.getString("title"),
                rs.getObject("start_date", java.time.LocalDate.class),
                formatTime(rs.getObject("start_time")),
                rs.getObject("end_date", java.time.LocalDate.class),
                formatTime(rs.getObject("end_time")),
                rs.getBoolean("all_day"),
                rs.getString("place"),
                rs.getString("memo"),
                rs.getString("reminder"),
                normalizeDateTime(rs.getObject("created_at"))
        ), pet.id());
    }

    @Transactional(readOnly = true)
    public CareScheduleResponse get(String email, Long petId, Long scheduleId) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        return findResponse(pet.id(), scheduleId);
    }

    @Transactional
    public CareScheduleResponse update(String email, Long petId, Long scheduleId, CareScheduleRequest request) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        notificationService.deletePendingReminders("CARE_SCHEDULE", scheduleId);
        findResponse(pet.id(), scheduleId);
        ValidatedRequest validated = validate(request);
        jdbcTemplate.update("""
                UPDATE care_schedules
                SET category_id = ?, title = ?, start_date = ?, start_time = ?, end_date = ?, end_time = ?,
                    all_day = ?, place = ?, memo = ?, reminder = ?, updated_at = ?
                WHERE id = ? AND pet_id = ?
                """,
                validated.categoryId(),
                validated.title(),
                validated.request().startDate(),
                validated.startTime(),
                validated.request().endDate(),
                validated.endTime(),
                validated.request().allDay(),
                normalizeNullableText(validated.request().place()),
                normalizeNullableText(validated.request().memo()),
                validated.reminder(),
                LocalDateTime.now(),
                scheduleId,
                pet.id());
        return findResponse(pet.id(), scheduleId);
    }

    @Transactional
    public void delete(String email, Long petId, Long scheduleId) {
        PetRow pet = findVisibleOwnedPet(email, petId);
        notificationService.deletePendingReminders("CARE_SCHEDULE", scheduleId);
        findResponse(pet.id(), scheduleId);
        jdbcTemplate.update("DELETE FROM care_schedules WHERE id = ? AND pet_id = ?", scheduleId, pet.id());
    }

    private void bindRequest(PreparedStatement ps, Long petId, ValidatedRequest validated) throws java.sql.SQLException {
        CareScheduleRequest request = validated.request();
        ps.setLong(1, petId);
        ps.setString(2, validated.categoryId());
        ps.setString(3, validated.title());
        ps.setObject(4, request.startDate());
        ps.setObject(5, validated.startTime());
        ps.setObject(6, request.endDate());
        ps.setObject(7, validated.endTime());
        ps.setBoolean(8, request.allDay());
        ps.setString(9, normalizeNullableText(request.place()));
        ps.setString(10, normalizeNullableText(request.memo()));
        ps.setString(11, validated.reminder());
    }

    private CareScheduleResponse findResponse(Long petId, Long scheduleId) {
        List<CareScheduleResponse> rows = jdbcTemplate.query("""
                SELECT id, pet_id, category_id, title, start_date, start_time, end_date, end_time,
                       all_day, place, memo, reminder, created_at
                FROM care_schedules
                WHERE id = ? AND pet_id = ?
                """, (rs, rowNum) -> CareScheduleResponse.of(
                rs.getLong("id"),
                rs.getLong("pet_id"),
                rs.getString("category_id"),
                rs.getString("title"),
                rs.getObject("start_date", java.time.LocalDate.class),
                formatTime(rs.getObject("start_time")),
                rs.getObject("end_date", java.time.LocalDate.class),
                formatTime(rs.getObject("end_time")),
                rs.getBoolean("all_day"),
                rs.getString("place"),
                rs.getString("memo"),
                rs.getString("reminder"),
                normalizeDateTime(rs.getObject("created_at"))
        ), scheduleId, petId);
        if (rows.isEmpty()) {
            throw new NotFoundException("Care schedule not found.", "CARE_SCHEDULE_NOT_FOUND");
        }
        return rows.getFirst();
    }

    private PetRow findVisibleOwnedPet(String email, Long petId) {
        Long userId = findUserId(email);
        List<PetRow> rows = jdbcTemplate.query("""
                SELECT id, user_id, is_deleted
                FROM pets
                WHERE id = ?
                """, (rs, rowNum) -> new PetRow(
                rs.getLong("id"),
                rs.getLong("user_id"),
                rs.getBoolean("is_deleted")
        ), petId);
        if (rows.isEmpty()) {
            throw new NotFoundException("Pet not found.", "PET_NOT_FOUND");
        }
        PetRow pet = rows.getFirst();
        if (!pet.userId().equals(userId)) {
            throw new ForbiddenException("Forbidden pet.", "PET_FORBIDDEN");
        }
        if (pet.deleted()) {
            throw new NotFoundException("Pet not found or deleted.", "PET_NOT_FOUND_OR_DELETED");
        }
        return pet;
    }

    private Long findUserId(String email) {
        List<Long> ids = jdbcTemplate.queryForList("SELECT id FROM users WHERE email = ?", Long.class, email);
        if (ids.isEmpty()) {
            throw InvalidInputException.invalidInput();
        }
        return ids.getFirst();
    }

    private ValidatedRequest validate(CareScheduleRequest request) {
        String title = normalizeRequiredText(request.title());
        if (title.length() > 100) {
            throw InvalidInputException.invalidInput();
        }
        if (request.endDate().isBefore(request.startDate())) {
            throw new InvalidInputException("Invalid date range.", "INVALID_DATE_RANGE");
        }
        String categoryId = normalizeRequiredText(request.categoryId());
        String reminder = normalizeRequiredText(request.reminder());
        LocalTime startTime = Boolean.TRUE.equals(request.allDay()) ? null : request.startTime();
        LocalTime endTime = Boolean.TRUE.equals(request.allDay()) ? null : request.endTime();
        return new ValidatedRequest(request, categoryId, title, reminder, startTime, endTime);
    }

    private String normalizeRequiredText(String value) {
        if (value == null) {
            throw InvalidInputException.invalidInput();
        }
        String trimmed = value.trim();
        if (trimmed.isEmpty()) {
            throw InvalidInputException.invalidInput();
        }
        return trimmed;
    }

    private String normalizeNullableText(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private static String formatTime(Object value) {
        if (value == null) {
            return null;
        }
        LocalTime time;
        if (value instanceof LocalTime localTime) {
            time = localTime;
        } else if (value instanceof Time sqlTime) {
            time = sqlTime.toLocalTime();
        } else {
            time = LocalTime.parse(value.toString());
        }
        return time.format(TIME_FORMATTER);
    }

    private static LocalDateTime normalizeDateTime(Object value) {
        if (value instanceof LocalDateTime localDateTime) {
            return localDateTime;
        }
        if (value instanceof Timestamp timestamp) {
            return timestamp.toLocalDateTime();
        }
        return LocalDateTime.parse(value.toString());
    }

    private record PetRow(Long id, Long userId, boolean deleted) {
    }

    private record ValidatedRequest(CareScheduleRequest request, String categoryId, String title, String reminder,
                                    LocalTime startTime, LocalTime endTime) {
    }
}
