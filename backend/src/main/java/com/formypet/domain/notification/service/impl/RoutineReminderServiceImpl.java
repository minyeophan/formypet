package com.formypet.domain.notification.service.impl;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.domain.notification.config.NotificationProperties;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.entity.ReminderSchedule;
import com.formypet.domain.notification.repository.query.ReminderCandidateRepository;
import com.formypet.domain.notification.service.NotificationService;
import com.formypet.domain.notification.service.RoutineReminderService;
import java.time.*;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class RoutineReminderServiceImpl implements RoutineReminderService {
    private final ReminderCandidateRepository candidates;
    private final NotificationService notifications;
    private final ObjectMapper mapper;
    private final NotificationProperties properties;

    public void createDueNotifications(LocalDateTime now) {
        LocalDateTime windowStart = now.minusMinutes(properties.lookbackMinutes());
        for (var row : candidates.routines()) {
            LocalDate date = now.toLocalDate();
            LocalDate firstDate = windowStart.toLocalDate();
            LocalDate start = row.startDate();
            LocalDate end = row.endDate();
            if (start == null || row.repeatType() == null) {
                log.warn("Skipping routine {}: invalid recurrence", row.id());
                continue;
            }
            List<Integer> days;
            List<String> times;
            try {
                days = mapper.readValue(row.days() == null ? "[]" : row.days(), new TypeReference<>() {});
                times = mapper.readValue(row.times() == null ? "[]" : row.times(), new TypeReference<>() {});
            } catch (Exception ex) {
                log.warn("Skipping routine {}: invalid JSON", row.id(), ex);
                continue;
            }
            if (days == null || times == null || ("monthly".equals(row.repeatType()) && row.monthlyInterval() < 1)) {
                log.warn("Skipping routine {}: invalid recurrence", row.id());
                continue;
            }
            for (LocalDate candidate = firstDate; !candidate.isAfter(date); candidate = candidate.plusDays(1)) {
                if (candidate.isBefore(start) || (end != null && candidate.isAfter(end))) continue;
                if (!ReminderSchedule.scheduledOn(row.repeatType(), start, candidate, days, row.monthlyInterval())) continue;
                for (String value : times) {
                    final LocalTime parsed;
                    try { parsed = LocalTime.parse(value); }
                    catch (RuntimeException ex) {
                        log.warn("Skipping routine {}: invalid time {}", row.id(), value);
                        continue;
                    }
                    LocalDateTime scheduledFor = LocalDateTime.of(candidate, parsed);
                    if (!scheduledFor.isBefore(windowStart) && !scheduledFor.isAfter(now)) {
                        notifications.createReminder(row.userId(), NotificationType.ROUTINE_REMINDER,
                                "ROUTINE", row.id(), scheduledFor, "루틴 알림",
                                row.petName() + "님의 " + row.label() + " 시간입니다.");
                    }
                }
            }
        }
    }
}
