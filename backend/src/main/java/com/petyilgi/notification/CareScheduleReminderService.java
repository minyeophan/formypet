package com.petyilgi.notification;

import lombok.RequiredArgsConstructor;
import com.petyilgi.config.NotificationProperties;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.sql.Time;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
@RequiredArgsConstructor
public class CareScheduleReminderService {
    private final JdbcTemplate jdbc;
    private final NotificationService notifications;
    private final NotificationProperties properties;
    private static final Logger log = LoggerFactory.getLogger(CareScheduleReminderService.class);

    public void createDueNotifications(LocalDateTime now) {
        LocalDateTime windowStart = now.minusMinutes(properties.lookbackMinutes());
        jdbc.query("""
                SELECT c.id, c.title, c.start_date, c.start_time, c.reminder,
                       p.name, u.id AS user_id
                FROM care_schedules c
                JOIN pets p ON p.id = c.pet_id
                JOIN users u ON u.id = p.user_id
                WHERE p.is_deleted = 0 AND u.notification_enabled = 1
                """, (rs, rowNum) -> {
            String reminder = rs.getString("reminder");
            Long offsetMinutes = reminderOffset(reminder);
            if (offsetMinutes == null && reminder != null && !reminder.trim().equalsIgnoreCase("none")) {
                log.warn("Skipping care schedule {}: unsupported reminder {}", rs.getLong("id"), reminder);
            }
            if (offsetMinutes == null) return null;

            LocalDate date = rs.getObject("start_date", LocalDate.class);
            Time sqlTime = rs.getTime("start_time");
            LocalTime time = sqlTime == null ? LocalTime.of(9, 0) : sqlTime.toLocalTime();
            LocalDateTime scheduledFor = LocalDateTime.of(date, time).minusMinutes(offsetMinutes);

            if (!scheduledFor.isBefore(windowStart) && !scheduledFor.isAfter(now)) {
                notifications.createReminder(
                        rs.getLong("user_id"), NotificationType.CARE_SCHEDULE_REMINDER,
                        "CARE_SCHEDULE", rs.getLong("id"), scheduledFor,
                        "케어 일정 알림",
                        rs.getString("name") + "님의 일정: " + rs.getString("title"));
            }
            return null;
        });
    }

    private Long reminderOffset(String reminder) {
        if (reminder == null) return null;
        return switch (reminder.trim().toLowerCase(Locale.ROOT)) {
            case "하루 전", "1 day before" -> 1_440L;
            case "2시간 전", "2 hours before" -> 120L;
            case "1시간 전", "1 hour before" -> 60L;
            case "30분 전", "30 minutes before" -> 30L;
            default -> null;
        };
    }
}
