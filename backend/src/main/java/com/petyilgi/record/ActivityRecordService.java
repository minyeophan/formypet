package com.petyilgi.record;

import com.petyilgi.auth.domain.User;
import com.petyilgi.auth.repository.UserRepository;
import com.petyilgi.media.storage.MediaStorage;
import com.petyilgi.pet.domain.Pet;
import com.petyilgi.pet.repository.PetRepository;
import com.petyilgi.record.dto.ActivityRecordCreateRequest;
import com.petyilgi.record.dto.ActivityRecordResponse;
import com.petyilgi.record.dto.ActivityRecordUpdateRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.jdbc.support.KeyHolder;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.io.IOException;
import java.math.BigDecimal;
import java.sql.PreparedStatement;
import java.sql.Date;
import java.sql.Statement;
import java.sql.Time;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

@Service
@RequiredArgsConstructor
public class ActivityRecordService {

    private static final Set<String> SUPPORTED_TYPES = Set.of(
            "meal", "water", "medicine", "poop", "walk", "sleep", "play", "weight", "vet", "checkup"
    );

    private final JdbcTemplate jdbcTemplate;
    private final PetRepository petRepository;
    private final UserRepository userRepository;
    private final MediaStorage mediaStorage;

    @Transactional
    public ActivityRecordResponse create(String email, Long petId, ActivityRecordCreateRequest request) {
        Pet pet = findOwnedPet(email, petId);
        validateType(request.typeId());
        validateRoutineBelongsToPet(pet.getId(), request.routineId());

        KeyHolder keyHolder = new GeneratedKeyHolder();
        LocalDateTime now = LocalDateTime.now();
        jdbcTemplate.update(connection -> {
            PreparedStatement ps = connection.prepareStatement("""
                    INSERT INTO activity_records (pet_id, type_id, date, time, routine_id, note, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, Statement.RETURN_GENERATED_KEYS);
            ps.setLong(1, pet.getId());
            ps.setString(2, request.typeId());
            ps.setObject(3, request.date());
            ps.setObject(4, request.time());
            ps.setObject(5, request.routineId());
            ps.setString(6, request.note());
            ps.setObject(7, now);
            ps.setObject(8, now);
            return ps;
        }, keyHolder);

        Long recordId = Objects.requireNonNull(keyHolder.getKey()).longValue();
        insertDetail(recordId, request.typeId(), safeDetail(request.detail()));
        return findResponse(pet.getId(), recordId);
    }

    @Transactional(readOnly = true)
    public List<ActivityRecordResponse> list(String email, Long petId, LocalDate date, String typeId, Integer limit) {
        Pet pet = findOwnedPet(email, petId);
        List<Object> params = new ArrayList<>();
        params.add(pet.getId());

        StringBuilder sql = new StringBuilder("""
                SELECT id, pet_id, type_id, date, time, routine_id, note
                FROM activity_records
                WHERE pet_id = ?
                """);
        if (date != null) {
            sql.append(" AND date = ?");
            params.add(date);
        }
        if (typeId != null && !typeId.isBlank()) {
            sql.append(" AND type_id = ?");
            params.add(typeId);
        }
        sql.append(" ORDER BY date DESC, id DESC");
        if (limit != null) {
            sql.append(" LIMIT ?");
            params.add(limit);
        }

        return jdbcTemplate.query(sql.toString(), (rs, rowNum) -> {
            Map<String, Object> row = new HashMap<>();
            row.put("id", rs.getLong("id"));
            row.put("pet_id", rs.getLong("pet_id"));
            row.put("type_id", rs.getString("type_id"));
            row.put("date", rs.getObject("date", LocalDate.class));
            row.put("time", rs.getTime("time"));
            row.put("routine_id", rs.getObject("routine_id"));
            row.put("note", rs.getString("note"));
            return fromBaseRow(row);
        }, params.toArray());
    }

    @Transactional(readOnly = true)
    public ActivityRecordResponse get(String email, Long petId, Long recordId) {
        Pet pet = findOwnedPet(email, petId);
        return findResponse(pet.getId(), recordId);
    }

    @Transactional
    public ActivityRecordResponse update(String email, Long petId, Long recordId, ActivityRecordUpdateRequest request) {
        Pet pet = findOwnedPet(email, petId);
        Map<String, Object> current = findBaseRecord(pet.getId(), recordId);
        String typeId = (String) current.get("type_id");
        validateRoutineBelongsToPet(pet.getId(), request.routineId());

        jdbcTemplate.update("""
                UPDATE activity_records
                SET date = ?, time = ?, routine_id = ?, note = ?, updated_at = ?
                WHERE id = ? AND pet_id = ?
                """,
                request.date() != null ? request.date() : current.get("date"),
                request.time() != null ? request.time() : current.get("time"),
                request.routineId() != null ? request.routineId() : current.get("routine_id"),
                request.note() != null ? request.note() : current.get("note"),
                LocalDateTime.now(),
                recordId,
                pet.getId());

        if (request.detail() != null) {
            deleteDetail(recordId, typeId);
            insertDetail(recordId, typeId, request.detail());
        }
        return findResponse(pet.getId(), recordId);
    }

    @Transactional
    public void delete(String email, Long petId, Long recordId) {
        Pet pet = findOwnedPet(email, petId);
        findBaseRecord(pet.getId(), recordId);
        List<String> storageKeys = findRecordMediaStorageKeys(recordId);
        jdbcTemplate.update("DELETE FROM activity_records WHERE id = ? AND pet_id = ?", recordId, pet.getId());
        deleteStorageAfterCommit(storageKeys);
    }

    private ActivityRecordResponse findResponse(Long petId, Long recordId) {
        return fromBaseRow(findBaseRecord(petId, recordId));
    }

    private ActivityRecordResponse fromBaseRow(Map<String, Object> row) {
        Long id = ((Number) row.get("id")).longValue();
        Long petId = ((Number) row.get("pet_id")).longValue();
        String typeId = (String) row.get("type_id");
        return ActivityRecordResponse.of(
                id,
                petId,
                typeId,
                normalizeDate(row.get("date")),
                normalizeTime(row.get("time")),
                row.get("routine_id") == null ? null : ((Number) row.get("routine_id")).longValue(),
                (String) row.get("note"),
                findMediaUrls(id),
                findDetail(id, typeId)
        );
    }

    private Map<String, Object> findBaseRecord(Long petId, Long recordId) {
        List<Map<String, Object>> rows = jdbcTemplate.queryForList("""
                SELECT id, pet_id, type_id, date, time, routine_id, note
                FROM activity_records
                WHERE id = ? AND pet_id = ?
                """, recordId, petId);
        if (rows.isEmpty()) {
            throw new IllegalArgumentException("활동 기록을 찾을 수 없습니다.");
        }
        return rows.getFirst();
    }

    private List<String> findMediaUrls(Long recordId) {
        return jdbcTemplate.queryForList("""
                SELECT id
                FROM media_resources
                WHERE record_id = ?
                ORDER BY id
                """, Long.class, recordId).stream()
                .map(id -> "/api/v1/media/" + id)
                .toList();
    }

    private List<String> findRecordMediaStorageKeys(Long recordId) {
        return jdbcTemplate.queryForList("""
                SELECT storage_key
                FROM media_resources
                WHERE record_id = ?
                ORDER BY id
                """, String.class, recordId);
    }

    private void deleteStorageAfterCommit(List<String> storageKeys) {
        if (storageKeys.isEmpty()) {
            return;
        }
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            storageKeys.forEach(this::deleteStorageQuietly);
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override
            public void afterCommit() {
                storageKeys.forEach(ActivityRecordService.this::deleteStorageQuietly);
            }
        });
    }

    private void deleteStorageQuietly(String storageKey) {
        try {
            mediaStorage.delete(storageKey);
        } catch (IOException ignored) {
            // Best-effort cleanup; the DB row has already been removed.
        }
    }

    private Map<String, Object> findDetail(Long recordId, String typeId) {
        String sql = switch (typeId) {
            case "meal" -> """
                    SELECT food_type AS foodType, feeding_method AS feedingMethod, served_amount AS servedAmount,
                           consumed_amount AS consumedAmount, consumed_percent AS consumedPercent, brand, product, ingredients
                    FROM record_meal WHERE record_id = ?
                    """;
            case "water" -> "SELECT amount FROM record_water WHERE record_id = ?";
            case "medicine" -> """
                    SELECT medicine_name AS medicineName, ingredients, dosage
                    FROM record_medicine WHERE record_id = ?
                    """;
            case "poop" -> """
                    SELECT poop_shape AS poopShape, poop_color AS poopColor, poop_amount AS poopAmount, poop_smell AS poopSmell
                    FROM record_poop WHERE record_id = ?
                    """;
            case "walk" -> """
                    SELECT distance, duration, ST_X(start_location) AS startLng, ST_Y(start_location) AS startLat,
                           ST_X(end_location) AS endLng, ST_Y(end_location) AS endLat
                    FROM record_walk WHERE record_id = ?
                    """;
            case "sleep", "play" -> "SELECT duration FROM record_walk WHERE record_id = ?";
            case "weight" -> "SELECT weight FROM record_weight WHERE record_id = ?";
            case "vet", "checkup" -> """
                    SELECT vet_clinic_name AS vetClinicName, ST_X(clinic_location) AS clinicLng, ST_Y(clinic_location) AS clinicLat,
                           vet_visit_reason AS vetVisitReason, vet_diagnosis AS vetDiagnosis, vet_treatment AS vetTreatment,
                           vet_cost AS vetCost, vet_next_visit_date AS vetNextVisitDate
                    FROM record_vet WHERE record_id = ?
                    """;
            default -> throw new IllegalArgumentException("지원하지 않는 기록 타입입니다.");
        };
        List<Map<String, Object>> rows = jdbcTemplate.queryForList(sql, recordId);
        return rows.isEmpty() ? Map.of() : rows.getFirst();
    }

    private void insertDetail(Long recordId, String typeId, Map<String, Object> detail) {
        switch (typeId) {
            case "meal" -> jdbcTemplate.update("""
                    INSERT INTO record_meal (record_id, food_type, feeding_method, served_amount, consumed_amount, consumed_percent, brand, product, ingredients)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, recordId, str(detail, "foodType"), str(detail, "feedingMethod"), decimal(detail, "servedAmount"),
                    decimal(detail, "consumedAmount"), decimal(detail, "consumedPercent"), str(detail, "brand"),
                    str(detail, "product"), str(detail, "ingredients"));
            case "water" -> jdbcTemplate.update("INSERT INTO record_water (record_id, amount) VALUES (?, ?)",
                    recordId, decimal(detail, "amount"));
            case "medicine" -> jdbcTemplate.update("""
                    INSERT INTO record_medicine (record_id, medicine_name, ingredients, dosage)
                    VALUES (?, ?, ?, ?)
                    """, recordId, str(detail, "medicineName"), str(detail, "ingredients"), str(detail, "dosage"));
            case "poop" -> jdbcTemplate.update("""
                    INSERT INTO record_poop (record_id, poop_shape, poop_color, poop_amount, poop_smell)
                    VALUES (?, ?, ?, ?, ?)
                    """, recordId, str(detail, "poopShape"), str(detail, "poopColor"),
                    str(detail, "poopAmount"), str(detail, "poopSmell"));
            case "walk" -> jdbcTemplate.update("""
                    INSERT INTO record_walk (record_id, distance, duration, start_location, end_location)
                    VALUES (?, ?, ?, ST_GeomFromText(?, 4326), ST_GeomFromText(?, 4326))
                    """, recordId, decimal(detail, "distance"), integer(detail, "duration"),
                    point(detail, "startLng", "startLat"), point(detail, "endLng", "endLat"));
            case "sleep", "play" -> jdbcTemplate.update("""
                    INSERT INTO record_walk (record_id, distance, duration, start_location, end_location)
                    VALUES (?, NULL, ?, NULL, NULL)
                    """, recordId, integer(detail, "duration"));
            case "weight" -> jdbcTemplate.update("INSERT INTO record_weight (record_id, weight) VALUES (?, ?)",
                    recordId, decimal(detail, "weight"));
            case "vet", "checkup" -> jdbcTemplate.update("""
                    INSERT INTO record_vet (record_id, vet_clinic_name, clinic_location, vet_visit_reason, vet_diagnosis, vet_treatment, vet_cost, vet_next_visit_date)
                    VALUES (?, ?, ST_GeomFromText(?, 4326), ?, ?, ?, ?, ?)
                    """, recordId, str(detail, "vetClinicName"), point(detail, "clinicLng", "clinicLat"),
                    str(detail, "vetVisitReason"), str(detail, "vetDiagnosis"), str(detail, "vetTreatment"),
                    integer(detail, "vetCost"), localDate(detail, "vetNextVisitDate"));
            default -> throw new IllegalArgumentException("지원하지 않는 기록 타입입니다.");
        }
    }

    private void deleteDetail(Long recordId, String typeId) {
        String table = switch (typeId) {
            case "meal" -> "record_meal";
            case "water" -> "record_water";
            case "medicine" -> "record_medicine";
            case "poop" -> "record_poop";
            case "walk", "sleep", "play" -> "record_walk";
            case "weight" -> "record_weight";
            case "vet", "checkup" -> "record_vet";
            default -> throw new IllegalArgumentException("지원하지 않는 기록 타입입니다.");
        };
        jdbcTemplate.update("DELETE FROM " + table + " WHERE record_id = ?", recordId);
    }

    private Pet findOwnedPet(String email, Long petId) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("사용자를 찾을 수 없습니다."));
        return petRepository.findById(petId)
                .filter(pet -> pet.isOwnedBy(user.getId()))
                .orElseThrow(() -> new AccessDeniedException("해당 펫에 접근할 권한이 없습니다."));
    }

    private void validateType(String typeId) {
        if (!SUPPORTED_TYPES.contains(typeId)) {
            throw new IllegalArgumentException("지원하지 않는 기록 타입입니다.");
        }
    }

    private void validateRoutineBelongsToPet(Long petId, Long routineId) {
        if (routineId == null) {
            return;
        }
        List<Long> petIds = jdbcTemplate.queryForList("SELECT pet_id FROM routines WHERE id = ?", Long.class, routineId);
        if (petIds.isEmpty()) {
            throw new IllegalArgumentException("Routine not found.");
        }
        if (!petIds.getFirst().equals(petId)) {
            throw new AccessDeniedException("Cannot attach routine from another pet.");
        }
    }

    private Map<String, Object> safeDetail(Map<String, Object> detail) {
        return detail == null ? Map.of() : detail;
    }

    private String str(Map<String, Object> detail, String key) {
        Object value = detail.get(key);
        return value == null ? null : value.toString();
    }

    private BigDecimal decimal(Map<String, Object> detail, String key) {
        Object value = detail.get(key);
        return value == null ? null : new BigDecimal(value.toString());
    }

    private Integer integer(Map<String, Object> detail, String key) {
        Object value = detail.get(key);
        return value == null ? null : ((Number) value).intValue();
    }

    private LocalDate localDate(Map<String, Object> detail, String key) {
        Object value = detail.get(key);
        return value == null ? null : LocalDate.parse(value.toString());
    }

    private String point(Map<String, Object> detail, String lngKey, String latKey) {
        BigDecimal lng = decimal(detail, lngKey);
        BigDecimal lat = decimal(detail, latKey);
        if (lng == null || lat == null) {
            return null;
        }
        return "POINT(" + lat + " " + lng + ")";
    }

    private LocalTime normalizeTime(Object value) {
        if (value == null) {
            return null;
        }
        if (value instanceof LocalTime localTime) {
            return localTime;
        }
        if (value instanceof Time time) {
            return time.toLocalTime();
        }
        return LocalTime.parse(value.toString());
    }

    private LocalDate normalizeDate(Object value) {
        if (value instanceof LocalDate localDate) {
            return localDate;
        }
        if (value instanceof Date date) {
            return date.toLocalDate();
        }
        return LocalDate.parse(value.toString());
    }
}
