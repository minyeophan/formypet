package com.formypet.domain.notification.service;

import com.formypet.domain.notification.dto.request.NotificationSettingsRequest;
import com.formypet.domain.notification.dto.response.NotificationFeedResponse;
import com.formypet.domain.notification.dto.response.NotificationSettingsResponse;
import com.formypet.domain.notification.entity.NotificationType;
import java.time.LocalDateTime;

public interface NotificationService {
    void create(Long recipient, Long actor, String nickname, NotificationType type, Long post, Long comment);
    void createReminder(Long recipient, NotificationType type, String sourceType, Long sourceId, LocalDateTime scheduledFor, String title, String body);
    int deletePendingReminders(String sourceType, Long sourceId);
    NotificationSettingsResponse getSettings(Long actorId);
    NotificationSettingsResponse updateSettings(Long actorId, NotificationSettingsRequest request);
    NotificationFeedResponse list(Long actorId, String cursor, int limit);
    void read(Long actorId, Long id);
    void readAll(Long actorId);
    int cleanup();
}
