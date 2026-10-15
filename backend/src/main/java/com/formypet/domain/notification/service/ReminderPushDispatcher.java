package com.formypet.domain.notification.service;

import com.formypet.domain.notification.entity.NotificationType;
import java.time.LocalDateTime;

public interface ReminderPushDispatcher {
    void dispatch(Long recipient, NotificationType type, Long sourceId, LocalDateTime scheduledFor, String title, String body);
}
