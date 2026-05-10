package com.petyilgi.routine;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.pet.domain.Pet;
import com.petyilgi.pet.repository.PetRepository;
import com.petyilgi.routine.dto.*;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;

@Service
@RequiredArgsConstructor
public class RoutineService {

    private static final Set<String> SUPPORTED_REPEAT_TYPES = Set.of("daily", "weekly", "biweekly", "monthly");
    private static final Set<String> SUPPORTED_COMPLETION_STATUS = Set.of("PENDING", "COMPLETED", "SKIPPED");

    private final JdbcTemplate jdbcTemplate;
    private final PetRepository petRepository;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;

    @Transactional
    public RoutineResponse create(String email, Long petId, RoutineCreateRequest request) {
        Pet pet = findOwnedPet(email, petId);
        validateRepeatType(request.repeatType());

        KeyHolder keyHolder = new GeneratedKeyHolder();
        LocalDateTime now = LocalDateTime.now();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO routines (pet_id, label, type_id, repeat_type, days, monthly_interval,
                                          start_date, end_date, times, is_active, notification_enabled,
                                          note, detail, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, true, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, pet.getId());
            ps.setString(2, request.label());
            ps.setString(3, request.typeId());
            ps.setString(4, request.repeatType());
            ps.setString(5, toJson(request.days()));
            ps.setInt(6, monthlyInterval(request.monthlyInterval()));
            ps.setObject(7, request.startDate());
            ps.setObject(8, request.endDate());
            ps.setString(9, toJson(request.times()));
            ps.setBoolean(10, Boolean.TRUE.equals(request.notificationEnabled()));
            ps.setString(11, request.note());
            ps.setString(12, toJsonObject(request.detail()));
            ps.setObject(13, now);
            ps.setObject(14, now);
            return ps;
        }, keyHolder);

        Long routineId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        return findResponse(pet.getId(), routineId);
    }

    @Transactional(readOnly = true)
    public List<RoutineResponse> list(String email, Long petId) {
        Pet pet = findOwnedPet(email, petId);
        return jdbcTemplate.queryForList("""
                        SELECT id, pet_id, label, type_id, repeat_type, days, monthly_interval,
                               start_date, end_date, times, note, detail, is_active, notification_enabled
                        FROM routines
                        WHERE pet_id = ?
                        ORDER BY id DESC
                        """, pet.getId())
                .stream()
                .map(this::toRoutineResponse)
                .toList();
    }

    @Transactional
    public RoutineResponse update(String email, Long petId, Long routineId, RoutineUpdateRequest request) {
        Pet pet = findOwnedPet(email, petId);
        Map<String, Object> current = findRoutineRow(pet.getId(), routineId);
        String repeatType = request.repeatType() != null ? request.repeatType() : (String) current.get("repeat_type");
        validateRepeatType(repeatType);

        jdbcTemplate.update("""
                UPDATE routines
                SET label = ?, type_id = ?, repeat_type = ?, days = ?, monthly_interval = ?,
                    start_date = ?, end_date = ?, times = ?, is_active = ?,
                    notification_enabled = ?, note = ?, detail = ?, updated_at = ?
                WHERE id = ? AND pet_id = ?
                """,
                request.label() != null ? request.label() : current.get("label"),
                request.typeId() != null ? request.typeId() : current.get("type_id"),
                repeatType,
                toJson(request.days() != null ? request.days() : parseIntegerList(current.get("days"))),
                request.monthlyInterval() != null ? request.monthlyInterval() : ((Number) current.get("monthly_interval")).intValue(),
                request.startDate() != null ? request.startDate() : normalizeDate(current.get("start_date")),
                request.endDate() != null ? request.endDate() : normalizeDate(current.get("end_date")),
                toJson(request.times() != null ? request.times() : parseStringList(current.get("times"))),
                request.active() != null ? request.active() : toBoolean(current.get("is_active")),
                request.notificationEnabled() != null ? request.notificationEnabled() : toBoolean(current.get("notification_enabled")),
                request.note() != null ? request.note() : current.get("note"),
                request.detail() != null ? toJsonObject(request.detail()) : current.get("detail"),
                LocalDateTime.now(),
                routineId,
                pet.getId());

        return findResponse(pet.getId(), routineId);
    }

    @Transactional
    public RoutineCompletionResponse markCompletion(String email, Long petId, Long routineId, LocalDate date,
                                                    RoutineCompletionRequest request) {
        Pet pet = findOwnedPet(email, petId);
        findRoutineRow(pet.getId(), routineId);
        String status = request.status().toUpperCase(Locale.ROOT);
        if (!SUPPORTED_COMPLETION_STATUS.contains(status)) {
            throw new IllegalArgumentException("Unsupported routine completion status.");
        }

        LocalDateTime completedAt = "COMPLETED".equals(status) ? LocalDateTime.now() : null;
        jdbcTemplate.update("""
                INSERT INTO routine_completions (routine_id, pet_id, scheduled_date, status, completed_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON DUPLICATE KEY UPDATE status = VALUES(status), completed_at = VALUES(completed_at), updated_at = VALUES(updated_at)
                """,
                routineId, pet.getId(), date, status, completedAt, LocalDateTime.now(), LocalDateTime.now());

        return findCompletionResponse(routineId, date);
    }

    @Transactional
    public TodayRoutineResponse today(String email, Long petId, LocalDate date) {
        Pet pet = findOwnedPet(email, petId);
        LocalDate targetDate = date != null ? date : LocalDate.now();
        List<RoutineResponse> routines = list(email, pet.getId()).stream()
                .filter(routine -> isScheduledOn(routine, targetDate))
                .toList();

        List<TodayRoutineResponse.TodayRoutineItem> items = new ArrayList<>();
        int done = 0;
        for (RoutineResponse routine : routines) {
            ensurePendingCompletion(routine.id(), pet.getId(), targetDate);
            RoutineCompletionResponse completion = findCompletionResponse(routine.id(), targetDate);
            if ("COMPLETED".equals(completion.status())) {
                done++;
            }
            items.add(TodayRoutineResponse.TodayRoutineItem.of(routine, completion));
        }

        return TodayRoutineResponse.of(items, TodayRoutineResponse.Summary.of(items.size(), done));
    }

    @Transactional
    public void delete(String email, Long petId, Long routineId) {
        Pet pet = findOwnedPet(email, petId);
        findRoutineRow(pet.getId(), routineId);
        jdbcTemplate.update("DELETE FROM routines WHERE id = ? AND pet_id = ?", routineId, pet.getId());
    }

    private void ensurePendingCompletion(Long routineId, Long petId, LocalDate date) {
        jdbcTemplate.update("""
                INSERT IGNORE INTO routine_completions (routine_id, pet_id, scheduled_date, status, created_at, updated_at)
                VALUES (?, ?, ?, 'PENDING', ?, ?)
                """, routineId, petId, date, LocalDateTime.now(), LocalDateTime.now());
    }

    private RoutineResponse findResponse(Long petId, Long routineId) {
        return toRoutineResponse(findRoutineRow(petId, routineId));
    }

    private Map<String, Object> findRoutineRow(Long petId, Long routineId) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList("""
                SELECT id, pet_id, label, type_id, repeat_type, days, monthly_interval,
                       start_date, end_date, times, note, detail, is_active, notification_enabled
                FROM routines
                WHERE id = ? AND pet_id = ?
                """, routineId, petId);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("Routine not found.");
        }
        return rows.getFirst();
    }

    private RoutineCompletionResponse findCompletionResponse(Long routineId, LocalDate date) {
        Map<String, Object> row = jdbcTemplate.queryForMap("""
                SELECT id, routine_id, pet_id, scheduled_date, status, completed_at
                FROM routine_completions
                WHERE routine_id = ? AND scheduled_date = ?
                """, routineId, date);
        return RoutineCompletionResponse.of(
                ((Number) row.get("id")).longValue(),
                ((Number) row.get("routine_id")).longValue(),
                ((Number) row.get("pet_id")).longValue(),
                normalizeDate(row.get("scheduled_date")),
                (String) row.get("status"),
                normalizeDateTime(row.get("completed_at"))
        );
    }

    private RoutineResponse toRoutineResponse(Map<String, Object> row) {
        return RoutineResponse.of(
                ((Number) row.get("id")).longValue(),
                ((Number) row.get("pet_id")).longValue(),
                (String) row.get("label"),
                (String) row.get("type_id"),
                (String) row.get("repeat_type"),
                parseIntegerList(row.get("days")),
                ((Number) row.get("monthly_interval")).intValue(),
                normalizeDate(row.get("start_date")),
                normalizeDate(row.get("end_date")),
                parseStringList(row.get("times")),
                (String) row.get("note"),
                parseMap(row.get("detail")),
                toBoolean(row.get("is_active")),
                toBoolean(row.get("notification_enabled"))
        );
    }

    private boolean isScheduledOn(RoutineResponse routine, LocalDate date) {
        if (!Boolean.TRUE.equals(routine.active()) || date.isBefore(routine.startDate())) {
            return false;
        }
        if (routine.endDate() != null && date.isAfter(routine.endDate())) {
            return false;
        }
        return switch (routine.repeatType()) {
            case "daily" -> true;
            case "weekly" -> routine.days().contains(dayNumber(date.getDayOfWeek()));
            case "biweekly" -> routine.days().contains(dayNumber(date.getDayOfWeek()))
                    && ChronoUnit.WEEKS.between(routine.startDate(), date) % 2 == 0;
            case "monthly" -> routine.startDate().getDayOfMonth() == date.getDayOfMonth()
                    && ChronoUnit.MONTHS.between(routine.startDate().withDayOfMonth(1), date.withDayOfMonth(1))
                    % routine.monthlyInterval() == 0;
            default -> false;
        };
    }

    private int dayNumber(DayOfWeek dayOfWeek) {
        return dayOfWeek == DayOfWeek.SUNDAY ? 0 : dayOfWeek.getValue();
    }

    private Pet findOwnedPet(String email, Long petId) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("User not found."));
        return petRepository.findById(petId)
                .filter(pet -> pet.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("No access to this pet."));
    }

    private void validateRepeatType(String repeatType) {
        if (!SUPPORTED_REPEAT_TYPES.contains(repeatType)) {
            throw new IllegalArgumentException("Unsupported routine repeat type.");
        }
    }

    private int monthlyInterval(Integer value) {
        return value == null || value < 1 ? 1 : value;
    }

    private String toJson(Object value) {
        try {
            return objectMapper.writeValueAsString(value == null ? List.of() : value);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid routine JSON value.");
        }
    }

    private String toJsonObject(Map<String, Object> value) {
        try {
            return objectMapper.writeValueAsString(value == null ? Map.of() : value);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid routine JSON value.");
        }
    }

    private List<Integer> parseIntegerList(Object value) {
        return parseList(value, new TypeReference<>() {});
    }

    private List<String> parseStringList(Object value) {
        return parseList(value, new TypeReference<>() {});
    }

    private Map<String, Object> parseMap(Object value) {
        if (value == null) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(value.toString(), new TypeReference<>() {});
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid routine JSON value.");
        }
    }

    private <T> List<T> parseList(Object value, TypeReference<List<T>> typeReference) {
        if (value == null) {
            return List.of();
        }
        try {
            return objectMapper.readValue(value.toString(), typeReference);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid routine JSON value.");
        }
    }

    private LocalDate normalizeDate(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof LocalDate localDate) {
            return localDate;
        }
        if (value instanceof Date date) {
            return date.toLocalDate();
        }
        return LocalDate.parse(value.toString());
    }

    private LocalDateTime normalizeDateTime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof LocalDateTime localDateTime) {
            return localDateTime;
        }
        if (value instanceof Timestamp timestamp) {
            return timestamp.toLocalDateTime();
        }
        return LocalDateTime.parse(value.toString());
    }

    private boolean toBoolean(Object value) {
        if (value instanceof Boolean bool) {
            return bool;
        }
        return ((Number) value).intValue() == 1;
    }
}
