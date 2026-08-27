package com.petyilgi.notification;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import com.petyilgi.config.NotificationProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
@RequiredArgsConstructor
public class RoutineReminderService {
    private final JdbcTemplate jdbc;
    private final NotificationService notifications;
    private final ObjectMapper mapper;
    private final NotificationProperties properties;
    private static final Logger log = LoggerFactory.getLogger(RoutineReminderService.class);

    public void createDueNotifications(LocalDateTime now) {
        LocalDateTime windowStart = now.minusMinutes(properties.lookbackMinutes());
        jdbc.query("""
                SELECT r.id, r.label, r.repeat_type, r.days, r.monthly_interval,
                       r.start_date, r.end_date, r.times, p.name, u.id AS user_id
                FROM routines r
                JOIN pets p ON p.id = r.pet_id
                JOIN users u ON u.id = p.user_id
                WHERE r.is_active = 1 AND r.notification_enabled = 1 AND u.notification_enabled = 1 AND p.is_deleted = 0
                """, (rs, rowNum) -> {
            LocalDate date = now.toLocalDate();
            LocalDate start = rs.getObject("start_date", LocalDate.class);
            LocalDate end = rs.getObject("end_date", LocalDate.class);
            if (date.isBefore(start) || (end != null && date.isAfter(end))) return null;

            List<Integer> days;
            List<String> times;
            try { days = mapper.readValue(rs.getString("days") == null ? "[]" : rs.getString("days"), new TypeReference<>() {}); times = mapper.readValue(rs.getString("times") == null ? "[]" : rs.getString("times"), new TypeReference<>() {}); }
            catch (Exception ex) { log.warn("Skipping routine {}: invalid JSON", rs.getLong("id"), ex); return null; }
            if (!scheduledOn(rs.getString("repeat_type"), start, date, days, rs.getInt("monthly_interval"))) {
                return null;
            }

            for (String value : times) {
                LocalDateTime scheduledFor = LocalDateTime.of(date, LocalTime.parse(value));
                if (!scheduledFor.isBefore(windowStart) && !scheduledFor.isAfter(now)) {
                    notifications.createReminder(
                            rs.getLong("user_id"), NotificationType.ROUTINE_REMINDER,
                            "ROUTINE", rs.getLong("id"), scheduledFor, "루틴 알림",
                            rs.getString("name") + "님의 " + rs.getString("label") + " 시간입니다.");
                }
            }
            return null;
        });
    }

    private boolean scheduledOn(String repeat, LocalDate start, LocalDate date,
                                 List<Integer> days, int monthlyInterval) {
        return switch (repeat) {
            case "daily" -> true;
            case "weekly" -> days.contains(day(date.getDayOfWeek()));
            case "biweekly" -> days.contains(day(date.getDayOfWeek()))
                    && ChronoUnit.WEEKS.between(start, date) % 2 == 0;
            case "monthly" -> start.getDayOfMonth() == date.getDayOfMonth()
                    && ChronoUnit.MONTHS.between(start.withDayOfMonth(1), date.withDayOfMonth(1))
                    % monthlyInterval == 0;
            default -> false;
        };
    }

    private int day(DayOfWeek day) {
        return day == DayOfWeek.SUNDAY ? 0 : day.getValue();
    }

    private <T> T parse(String value, TypeReference<T> type) {
        try {
            return mapper.readValue(value == null ? "[]" : value, type);
        } catch (Exception ignored) {
            return (T) List.of();
        }
    }
}
