package com.formypet.notification;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReminderPushDispatcher {
    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;
    private final PushSender sender;

    // An AFTER_COMMIT callback still has the old transaction's resources bound.
    // A new transaction is required for invalid-token updates to be committed.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void dispatch(Long recipient, NotificationType type, Long sourceId,
                         LocalDateTime scheduledFor, String title, String body) {
        if (!eligible(recipient, type, sourceId, scheduledFor)) {
            log.info("Reminder push skipped: target or settings changed");
            return;
        }
        var snapshots = jdbc.queryForList("SELECT token, updated_at FROM device_tokens WHERE user_id=? AND enabled=TRUE", recipient);
        if (snapshots.isEmpty()) {
            log.info("Reminder push skipped: no active device");
            return;
        }
        var tokens = snapshots.stream().map(row -> (String) row.get("token")).toList();
        var result = sender.send(type.name(), sourceId, title, body, tokens);
        for (var row : snapshots) {
            if (result.invalidTokens().contains(row.get("token"))) {
                jdbc.update("""
                    UPDATE device_tokens SET enabled=FALSE, updated_at=CURRENT_TIMESTAMP(6)
                    WHERE user_id=? AND token=? AND updated_at=? AND enabled=TRUE
                    """, recipient, row.get("token"), row.get("updated_at"));
            }
        }
    }

    private boolean eligible(Long recipient, NotificationType type, Long sourceId, LocalDateTime scheduled) {
        if (type == NotificationType.CARE_SCHEDULE_REMINDER) {
            return jdbc.query("""
                SELECT c.start_date,c.start_time,c.reminder FROM care_schedules c
                JOIN pets p ON p.id=c.pet_id JOIN users u ON u.id=p.user_id
                WHERE c.id=? AND u.id=? AND p.is_deleted=0 AND u.notification_enabled=1
                """, (rs, n) -> {
                    var date = rs.getObject("start_date", LocalDate.class);
                    var time = rs.getTime("start_time");
                    var offset = CareScheduleReminderService.reminderOffset(rs.getString("reminder"));
                    return date != null && offset != null && scheduled.equals(LocalDateTime.of(date,
                        time == null ? LocalTime.of(9, 0) : time.toLocalTime()).minusMinutes(offset));
                }, sourceId, recipient).stream().anyMatch(Boolean.TRUE::equals);
        }
        if (type != NotificationType.ROUTINE_REMINDER) return false;
        return jdbc.query("""
            SELECT r.start_date,r.end_date,r.repeat_type,r.days,r.times,r.monthly_interval FROM routines r
            JOIN pets p ON p.id=r.pet_id JOIN users u ON u.id=p.user_id
            WHERE r.id=? AND u.id=? AND p.is_deleted=0 AND u.notification_enabled=1
              AND r.is_active=1 AND r.notification_enabled=1
            """, (rs, n) -> {
                try {
                    var start = rs.getObject("start_date", LocalDate.class);
                    var end = rs.getObject("end_date", LocalDate.class);
                    var date = scheduled.toLocalDate();
                    List<Integer> days = mapper.readValue(rs.getString("days"), new TypeReference<>() {});
                    List<String> times = mapper.readValue(rs.getString("times"), new TypeReference<>() {});
                    return start != null && !date.isBefore(start) && (end == null || !date.isAfter(end))
                        && RoutineReminderService.scheduledOn(rs.getString("repeat_type"), start, date, days, rs.getInt("monthly_interval"))
                        && times.stream().anyMatch(value -> {
                            try { return LocalTime.parse(value).equals(scheduled.toLocalTime()); }
                            catch (RuntimeException invalid) { return false; }
                        });
                } catch (Exception invalid) { return false; }
            }, sourceId, recipient).stream().anyMatch(Boolean.TRUE::equals);
    }
}
