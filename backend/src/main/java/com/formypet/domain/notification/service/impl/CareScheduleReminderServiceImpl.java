package com.formypet.domain.notification.service.impl;

import com.formypet.domain.notification.config.NotificationProperties;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.entity.ReminderSchedule;
import com.formypet.domain.notification.repository.query.ReminderCandidateRepository;
import com.formypet.domain.notification.service.CareScheduleReminderService;
import com.formypet.domain.notification.service.NotificationService;
import java.time.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class CareScheduleReminderServiceImpl implements CareScheduleReminderService {
    private final ReminderCandidateRepository candidates;
    private final NotificationService notifications;
    private final NotificationProperties properties;

    public void createDueNotifications(LocalDateTime now) {
        LocalDateTime windowStart = now.minusMinutes(properties.lookbackMinutes());
        for (var row : candidates.careSchedules()) {
            String reminder = row.reminder();
            Long offsetMinutes = ReminderSchedule.reminderOffset(reminder);
            if (offsetMinutes == null && reminder != null && !reminder.trim().equalsIgnoreCase("none") && !reminder.trim().equals("알림 없음")) {
                log.warn("Skipping care schedule {}: unsupported reminder {}", row.id(), reminder);
            }
            if (offsetMinutes == null) continue;
            LocalDate date = row.startDate();
            if (date == null) {
                log.warn("Skipping care schedule {}: missing date", row.id());
                continue;
            }
            LocalTime time = row.startTime() == null ? LocalTime.of(9, 0) : row.startTime();
            LocalDateTime scheduledFor = LocalDateTime.of(date, time).minusMinutes(offsetMinutes);
            if (!scheduledFor.isBefore(windowStart) && !scheduledFor.isAfter(now)) {
                notifications.createReminder(row.userId(), NotificationType.CARE_SCHEDULE_REMINDER,
                        "CARE_SCHEDULE", row.id(), scheduledFor, "케어 일정 알림",
                        row.petName() + "님의 일정: " + row.title());
            }
        }
    }
}
