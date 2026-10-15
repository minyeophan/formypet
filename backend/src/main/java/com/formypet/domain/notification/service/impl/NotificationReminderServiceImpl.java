package com.formypet.domain.notification.service.impl;

import com.formypet.common.time.UtcTime;
import com.formypet.domain.notification.config.NotificationProperties;
import com.formypet.domain.notification.entity.NotificationType;
import com.formypet.domain.notification.repository.NotificationRepository;
import com.formypet.domain.notification.repository.jdbc.NotificationCommands;
import com.formypet.domain.notification.service.NotificationReminderService;
import com.formypet.domain.notification.service.ReminderPushDispatcher;
import java.time.Instant;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Service
@RequiredArgsConstructor
@Slf4j
public class NotificationReminderServiceImpl implements NotificationReminderService {
    private final NotificationRepository notifications;
    private final NotificationCommands commands;
    private final ReminderPushDispatcher pushDispatcher;
    private final NotificationProperties properties;

    @Transactional
    public void createReminder(Long recipient, NotificationType type, String sourceType, Long sourceId,
                               LocalDateTime scheduledFor, String title, String body) {
        if (recipient == null || !commands.lockReminderPreference(recipient)) return;
        int inserted = commands.insertReminder(recipient, type.name(), sourceType, sourceId, scheduledFor,
                title, body, UtcTime.toDatabase(Instant.now()));
        if (inserted != 1) return;
        Runnable send = () -> {
            try { pushDispatcher.dispatch(recipient, type, sourceId, scheduledFor, title, body); }
            catch (Exception error) { log.warn("Reminder push failed: {}", error.getClass().getSimpleName()); }
        };
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCommit() { send.run(); }
            });
        } else send.run();
    }

    @Transactional
    public int deletePendingReminders(String sourceType, Long sourceId) {
        return notifications.deletePending(sourceType, sourceId, LocalDateTime.now(properties.timezone()));
    }
}
