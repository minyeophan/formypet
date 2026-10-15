package com.formypet.domain.notification.service;

import com.formypet.domain.notification.entity.NotificationType;
import java.time.LocalDateTime;

public interface NotificationReminderService {
    void createReminder(Long recipient, NotificationType type, String sourceType, Long sourceId, LocalDateTime scheduledFor, String title, String body);
    int deletePendingReminders(String sourceType, Long sourceId);
}
