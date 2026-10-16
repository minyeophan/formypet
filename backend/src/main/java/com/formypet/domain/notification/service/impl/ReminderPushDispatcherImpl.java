package com.formypet.domain.notification.service.impl;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.formypet.domain.notification.client.PushSender;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.entity.ReminderSchedule;
import com.formypet.domain.notification.repository.DeviceTokenRepository;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.repository.query.DeviceTokenSnapshot;
import com.formypet.domain.notification.repository.query.ReminderCandidateRepository;
import com.formypet.domain.notification.service.ReminderPushDispatcher;
import java.time.*;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReminderPushDispatcherImpl implements ReminderPushDispatcher {
    private final NotificationCommands commands;
    private final DeviceTokenRepository devices;
    private final ReminderCandidateRepository candidates;
    private final ObjectMapper mapper;
    private final PushSender sender;

    // AFTER_COMMIT still has the original resources bound; invalidation needs its own commit.
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void dispatch(Long recipient, NotificationType type, Long sourceId,
                         LocalDateTime scheduledFor, String title, String body) {
        if (!commands.lockDispatchRecipient(recipient)) {
            log.info("Reminder push skipped: recipient is unavailable");
            return;
        }
        if (!eligible(recipient, type, sourceId, scheduledFor)) {
            log.info("Reminder push skipped: target or settings changed");
            return;
        }
        var snapshots = devices.activeSnapshots(recipient);
        if (snapshots.isEmpty()) {
            log.info("Reminder push skipped: no active device");
            return;
        }
        var tokens = snapshots.stream().map(DeviceTokenSnapshot::token).toList();
        var result = sender.send(type.name(), sourceId, title, body, tokens);
        for (var snapshot : snapshots) {
            if (result.invalidTokens().contains(snapshot.token())) {
                commands.disableInvalidToken(recipient, snapshot.token(), snapshot.updatedAt());
            }
        }
    }

    private boolean eligible(Long recipient, NotificationType type, Long sourceId, LocalDateTime scheduled) {
        if (type == NotificationType.CARE_SCHEDULE_REMINDER) {
            return candidates.careSchedule(recipient, sourceId).map(row -> {
                var offset = ReminderSchedule.reminderOffset(row.reminder());
                return row.startDate() != null && offset != null && scheduled.equals(LocalDateTime.of(row.startDate(),
                        row.startTime() == null ? LocalTime.of(9, 0) : row.startTime()).minusMinutes(offset));
            }).orElse(false);
        }
        if (type != NotificationType.ROUTINE_REMINDER) return false;
        return candidates.routine(recipient, sourceId).map(row -> {
            try {
                var start = row.startDate();
                var end = row.endDate();
                var date = scheduled.toLocalDate();
                List<Integer> days = mapper.readValue(row.days(), new TypeReference<>() {});
                List<String> times = mapper.readValue(row.times(), new TypeReference<>() {});
                return start != null && !date.isBefore(start) && (end == null || !date.isAfter(end))
                        && ReminderSchedule.scheduledOn(row.repeatType(), start, date, days, row.monthlyInterval())
                        && times.stream().anyMatch(value -> {
                            try { return LocalTime.parse(value).equals(scheduled.toLocalTime()); }
                            catch (RuntimeException invalid) { return false; }
                        });
            } catch (Exception invalid) { return false; }
        }).orElse(false);
    }
}
